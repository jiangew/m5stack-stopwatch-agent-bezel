import Darwin
import Foundation

/// All access is relative to pinned directory descriptors. No symlink is followed,
/// including intermediate path components; owner/mode/link-count checked before reads.
final class TaskNotificationStore {
    private let root: Int32
    private var lockFD: Int32 = -1
    private var directories: [String: Int32] = [:]
    init(directory: String) throws {
        guard directory.hasPrefix("/"), !directory.split(separator: "/").contains("..") else { throw TaskNotificationError.unsafe }
        let components = directory.split(separator: "/").map(String.init)
        guard !components.isEmpty else { throw TaskNotificationError.unsafe }
        var fd = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw TaskNotificationError.io }
        do {
            for (index, component) in components.enumerated() {
                var next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                if next < 0, errno == ENOENT, index == components.count - 1 {
                    guard mkdirat(fd, component, 0o700) == 0 else { throw TaskNotificationError.io }
                    next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                }
                guard next >= 0 else { throw TaskNotificationError.unsafe }
                close(fd); fd = next
            }
            try Self.check(fd, directory: true)
            root = fd
        } catch { close(fd); throw error }
        do {
            lockFD = openat(root, ".broker.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
            guard lockFD >= 0 else { throw TaskNotificationError.unsafe }
            try Self.check(lockFD, directory: false)
            guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw TaskNotificationError.io }
            for name in ["inbox", "processing", "decisions", "consumed"] {
                if mkdirat(root, name, 0o700) != 0, errno != EEXIST { throw TaskNotificationError.io }
                let sub = openat(root, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard sub >= 0 else { throw TaskNotificationError.unsafe }
                do { try Self.check(sub, directory: true) } catch { close(sub); throw error }
                directories[name] = sub
            }
        } catch {
            for sub in directories.values { close(sub) }; if lockFD >= 0 { close(lockFD) }; close(root); throw error
        }
    }
    deinit { for sub in directories.values { close(sub) }; if lockFD >= 0 { close(lockFD) }; close(root) }
    private static func check(_ fd: Int32, directory: Bool) throws {
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(),
              info.st_mode & 0o777 == (directory ? 0o700 : 0o600),
              info.st_mode & S_IFMT == (directory ? S_IFDIR : S_IFREG),
              directory || info.st_nlink == 1 else { throw TaskNotificationError.unsafe }
    }
    private func names(_ fd: Int32) throws -> [String] {
        let copy = openat(fd, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard copy >= 0, let stream = fdopendir(copy) else { if copy >= 0 { close(copy) }; throw TaskNotificationError.io }
        defer { closedir(stream) }
        var result: [String] = []
        while let entry = readdir(stream) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
            }
            if name.hasSuffix(".json"), !name.contains("/"), name.utf8.count <= 255 { result.append(name) }
            if result.count > 1024 { throw TaskNotificationError.invalid }
        }
        return result.sorted()
    }
    private func read(_ name: String, from fd: Int32, max: Int) throws -> Data? {
        guard !name.contains("/"), name != ".", name != ".." else { throw TaskNotificationError.unsafe }
        let file = openat(fd, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        if file < 0, errno == ENOENT { return nil }
        guard file >= 0 else { throw TaskNotificationError.unsafe }
        defer { close(file) }
        try Self.check(file, directory: false)
        var info = stat(); guard fstat(file, &info) == 0, info.st_size <= max else { throw TaskNotificationError.invalid }
        var data = Data(), bytes = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(file, &bytes, bytes.count)
            if count == 0 { return data }
            guard count > 0, data.count + count <= max else { throw TaskNotificationError.invalid }
            data.append(contentsOf: bytes.prefix(count))
        }
    }
    private func write(_ data: Data, name: String, to fd: Int32, replace: Bool) throws {
        let temporary = ".tmp-\(UUID().uuidString)"
        let file = openat(fd, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard file >= 0 else { throw TaskNotificationError.io }
        defer { close(file); unlinkat(fd, temporary, 0) }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(file, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                guard count > 0 else { throw TaskNotificationError.io }; offset += count
            }
        }
        guard fsync(file) == 0 else { throw TaskNotificationError.io }
        if replace {
            guard renameat(fd, temporary, fd, name) == 0 else { throw TaskNotificationError.io }
        } else {
            guard linkat(fd, temporary, fd, name, 0) == 0 else { throw TaskNotificationError.io }
            guard unlinkat(fd, temporary, 0) == 0 else { throw TaskNotificationError.io }
        }
        guard fsync(fd) == 0 else { throw TaskNotificationError.io }
    }
    func load() throws -> TaskNotificationSnapshot {
        guard let data = try read("queue.json", from: root, max: 600_000) else { return TaskNotificationSnapshot() }
        let snapshot = try JSONDecoder().decode(TaskNotificationSnapshot.self, from: data)
        guard snapshot.v == 1, snapshot.records.count <= 64, snapshot.nextID > 0,
              Set(snapshot.records.map(\.id)).count == snapshot.records.count,
              snapshot.records.allSatisfy({ $0.firstSeen >= 0 && $0.firstSeen <= Int64.max - 120_000 && $0.id > 0 && $0.id < snapshot.nextID && ["pending", "submitting", "unknown", "resolved"].contains($0.state) }) else { throw TaskNotificationError.invalid }
        for record in snapshot.records { try record.event.validate() }
        return snapshot
    }
    func save(_ snapshot: TaskNotificationSnapshot) throws {
        try write(JSONEncoder().encode(snapshot), name: "queue.json", to: root, replace: true)
    }
    func publish(_ decision: TaskNotificationDecision) throws {
        try pruneDecisions(now: decision.createdAt)
        guard try decisionNames().count < 128 else { throw TaskNotificationError.invalid }
        try write(JSONEncoder().encode(decision), name: decision.decisionId + ".json", to: directories["decisions"]!, replace: false)
    }
    func decisionNames() throws -> [String] { try names(directories["decisions"]!) }
    func readDecision(_ name: String) throws -> TaskNotificationDecision {
        guard let data = try read(name, from: directories["decisions"]!, max: 8192) else { throw TaskNotificationError.io }
        return try JSONDecoder().decode(TaskNotificationDecision.self, from: data)
    }
    private func pruneDecisions(now: Int64) throws {
        let directory = directories["decisions"]!
        for name in try decisionNames() {
            guard let decision = try? readDecision(name) else { continue }
            // Same clock as publication and native leases; deleting a delivery
            // file never clears its durable dispatch ID or authorizes a retry.
            let expired: Bool
            if decision.action == "open" {
                expired = decision.createdAt <= Int64.max - 60_000 && now >= decision.createdAt + 60_000
            } else { expired = now >= decision.leaseDeadline }
            if expired, unlinkat(directory, name, 0) != 0, errno != ENOENT { throw TaskNotificationError.io }
        }
        guard fsync(directory) == 0 else { throw TaskNotificationError.io }
    }
    func consumeEvents(_ ingest: (TaskNotificationEvent) throws -> Void, rejected: () -> Void) throws {
        let inbox = directories["inbox"]!, processing = directories["processing"]!
        var occupied = Set(try names(processing))
        for name in try names(inbox) {
            guard occupied.count < 1024 || occupied.contains(name) else { break }
            // Exclusive claim: link then unlink. Crash may leave both names; broker dedup is durable.
            if linkat(inbox, name, processing, name, 0) == 0 { unlinkat(inbox, name, 0); occupied.insert(name) }
            else if errno == EEXIST { unlinkat(inbox, name, 0) }
        }
        for name in try names(processing) {
            do {
                guard let data = try read(name, from: processing, max: 8192) else { continue }
                try ingest(JSONDecoder().decode(TaskNotificationEvent.self, from: data))
                unlinkat(processing, name, 0)
            } catch TaskNotificationError.full { rejected() }
            catch TaskNotificationError.io { throw TaskNotificationError.io }
            catch { rejected(); unlinkat(processing, name, 0) }
        }
    }
}
