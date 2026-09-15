import Foundation

enum CompanionShortcutEvent: Equatable {
    case left, up, down, right, openHermes, showHome
    case navigation(WorkspaceNavigationOrigin, WorkspaceSwipeDirection)
}

enum WorkspaceNavigationOrigin: String {
    case `super`, hermes, home

    var profile: WorkspaceAppProfile? { self == .home ? nil : self == .super ? .super : .hermes }
}

enum WorkspaceSwipeDirection: String {
    case left, up, down, right

    var nativeEvent: CompanionShortcutEvent {
        switch self {
        case .left: return .left
        case .up: return .up
        case .down: return .down
        case .right: return .right
        }
    }
}

enum StopwatchHIDDescriptor {
    static let vendorID = 0x303A
    static let productID = 0x8360
    static let usagePage = 0xFF00
    static let usage = 1
    static let reportID = 6
    static let reportBodyByteCount = 63
}

struct HIDShortcutDecoder {
    private static let fragmentMarker: UInt8 = 0x02
    private static let maximumMessageBytes = 4_096
    private static let directionTolerance = 0.05
    private static let distanceTolerance = 0.05
    private static let cooldown: TimeInterval = 0.8

    private struct Message: Decodable {
        struct Parameters: Decodable {
            let a: Double
            let d: Double
        }
        let method: String
        let params: Parameters
    }

    private var receiveBuffer: [UInt8] = []
    private var activePress: CompanionShortcutEvent?
    private var armed: Bool { activePress == nil }
    private var lastAcceptedAt: TimeInterval?

    mutating func consume(reportID: Int, bytes: [UInt8], now: TimeInterval) -> [CompanionShortcutEvent] {
        guard reportID == StopwatchHIDDescriptor.reportID else { return [] }
        // On the physical C152, macOS supplies the report ID both as the
        // callback argument and as the first byte of the 64-byte raw report.
        let body = bytes.count == StopwatchHIDDescriptor.reportBodyByteCount + 1
            && bytes.first == UInt8(reportID)
            ? Array(bytes.dropFirst())
            : bytes
        guard body.count >= 2, body[0] == Self.fragmentMarker else {
            receiveBuffer.removeAll(keepingCapacity: true)
            return []
        }
        let length = Int(body[1])
        guard length <= body.count - 2 else {
            receiveBuffer.removeAll(keepingCapacity: true)
            return []
        }
        receiveBuffer.append(contentsOf: body[2 ..< 2 + length])
        guard receiveBuffer.count <= Self.maximumMessageBytes else {
            receiveBuffer.removeAll(keepingCapacity: true)
            return []
        }

        var events: [CompanionShortcutEvent] = []
        while let newline = receiveBuffer.firstIndex(of: 0x0A) {
            let line = Data(receiveBuffer[..<newline])
            receiveBuffer.removeSubrange(...newline)
            if let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
               object["method"] as? String == "host.workspace_navigation" {
                guard Set(object.keys) == Set(["method", "params"]),
                      let params = object["params"] as? [String: Any],
                      Set(params.keys) == Set(["workspace", "direction", "phase"]),
                      let workspace = params["workspace"] as? String,
                      let origin = WorkspaceNavigationOrigin(rawValue: workspace),
                      let name = params["direction"] as? String,
                      let direction = WorkspaceSwipeDirection(rawValue: name),
                      let phase = params["phase"] as? String,
                      phase == "press" || phase == "release" else { continue }
                guard origin != .home || direction == .left else { continue }
                if let event = recognizePress(.navigation(origin, direction), pressed: phase == "press", now: now) {
                    events.append(event)
                }
                continue
            }
            if let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
               object["method"] as? String == "host.workspace_action" {
                guard Set(object.keys) == Set(["method", "params"]),
                      let params = object["params"] as? [String: Any],
                      Set(params.keys) == Set(["action"]) else { continue }
                if params["action"] as? String == "show_home" {
                    activePress = nil
                    events.append(.showHome)
                    continue
                }
                guard params["action"] as? String == "open_hermes", armed, acceptCooldown(now) else { continue }
                events.append(.openHermes)
                continue
            }
            guard let message = try? JSONDecoder().decode(Message.self, from: line),
                  let event = recognize(message, now: now) else { continue }
            events.append(event)
        }
        return events
    }

    mutating func reset() {
        receiveBuffer.removeAll(keepingCapacity: true)
        activePress = nil
        lastAcceptedAt = nil
    }

    private mutating func recognize(_ message: Message, now: TimeInterval) -> CompanionShortcutEvent? {
        guard message.method == "v.oai.rad",
              message.params.a.isFinite,
              message.params.d.isFinite,
              let event = event(for: message.params.a) else { return nil }
        if abs(message.params.d) <= Self.distanceTolerance {
            return recognizePress(event, pressed: false, now: now)
        }
        guard abs(message.params.d - 1.0) <= Self.distanceTolerance else { return nil }
        return recognizePress(event, pressed: true, now: now)
    }

    private mutating func recognizePress(_ event: CompanionShortcutEvent, pressed: Bool, now: TimeInterval) -> CompanionShortcutEvent? {
        if !pressed {
            if activePress == event { activePress = nil }
            return nil
        }
        guard armed else { return nil }
        activePress = event
        guard acceptCooldown(now) else { return nil }
        return event
    }

    private mutating func acceptCooldown(_ now: TimeInterval) -> Bool {
        guard now.isFinite,
              lastAcceptedAt.map({ now - $0 >= Self.cooldown }) ?? true else { return false }
        lastAcceptedAt = now
        return true
    }

    private func event(for angle: Double) -> CompanionShortcutEvent? {
        let candidates: [(Double, CompanionShortcutEvent)] = [
            (0.00, .right),
            (0.25, .down),
            (0.50, .left),
            (0.75, .up),
        ]
        return candidates.first { abs(angle - $0.0) <= Self.directionTolerance }?.1
    }
}
