import Foundation

/// Serialized by the owning main-runloop runtime; native adapters never call this concurrently.
final class TaskNotificationBroker {
    private let store: TaskNotificationStore
    private let muteLegacyCodex: Bool
    private let richContent: Bool
    private var snapshot: TaskNotificationSnapshot
    private var fresh: Set<UInt32> = []
    private var selected: UInt32?
    private var pinned = false
    private var alerts: [UInt32: Int] = [:]
    private var presentationUntil: Int64 = 0
    private var clock: Int64 = 0
    private(set) var lastActionSequence: UInt32 = 0
    private var generation = UInt32.random(in: 1...UInt32.max)
    private func advanceClock(_ now: Int64) {
        if now < clock { presentationUntil = 0 }
        clock = now
    }
    var count: Int { snapshot.records.filter { !$0.dismissed }.count }
    init(store: TaskNotificationStore, muteLegacyCodex: Bool = false, richContent: Bool = false) throws {
        self.richContent = richContent
        self.muteLegacyCodex = muteLegacyCodex
        self.store = store; snapshot = try store.load()
        // Persisted dispatch is never retried, even if publication crashed. Native resolution must reconcile it.
        for i in snapshot.records.indices where snapshot.records[i].state == "submitting" { snapshot.records[i].state = "unknown" }
        try store.save(snapshot)
        selected = preferredID()
    }
    private func orderedVisibleRecords(announcementsOnly: Bool = false) -> [TaskNotificationRecord] {
        func priority(_ record: TaskNotificationRecord) -> Int {
            if record.state == "pending" && ["approval", "input"].contains(record.event.kind) { return 0 }
            return record.event.kind == "failed" ? 1 : 2
        }
        return snapshot.records.filter { !$0.dismissed && (!announcementsOnly || (alerts[$0.id] ?? 0) > 0) }.sorted {
            let a = priority($0), b = priority($1)
            if a != b { return a < b }
            if $0.firstSeen != $1.firstSeen { return $0.firstSeen < $1.firstSeen }
            return $0.id < $1.id
        }
    }
    private func preferredID(announcementsOnly: Bool = false) -> UInt32? { orderedVisibleRecords(announcementsOnly: announcementsOnly).first?.id }
    func reconnect() {
        generation = generation == UInt32.max ? 1 : generation + 1
        alerts.removeAll(); lastActionSequence = 0
        pinned = false; presentationUntil = 0; selected = preferredID()
    }
    func published() {
        if let selected, (alerts[selected] ?? 0) > 0 {
            presentationUntil = clock + 5_000; alerts[selected] = nil
        }
    }
    func ingest(_ event: TaskNotificationEvent, now: Int64) throws {
        try event.validate()
        guard event.createdAt <= now + 1_000 else { throw TaskNotificationError.invalid }
        advanceClock(now)
        var next = snapshot
        let index: Int
        var newRevision = false
        if let existing = next.records.firstIndex(where: { $0.event.identity == event.identity }) {
            let old = next.records[existing]
            guard event.revision >= old.event.revision else { return }
            if event.revision == old.event.revision {
                guard event.kind == old.event.kind, event.title == old.event.title, event.model == old.event.model,
                      event.detail == old.event.detail, event.project == old.event.project, event.excerpted == old.event.excerpted, event.options == old.event.options, event.optionIds == old.event.optionIds else { throw TaskNotificationError.invalid }
                if old.state == "resolved" {
                    guard event.state == "resolved", old.event.outcome == nil, event.outcome != nil else { return }
                }
                guard event.state == "resolved" || (event.createdAt > old.event.createdAt && event.eventId != old.event.eventId) else { return }
            }
            index = existing
            if event.revision > old.event.revision {
                next.records[index] = TaskNotificationRecord(id: old.id, event: event, state: event.state, firstSeen: now)
                newRevision = true
            } else {
                next.records[index].event = event
                if event.state == "resolved" { next.records[index].state = "resolved" }
            }
        } else {
            if next.records.count == 64 {
                guard let removable = next.records.firstIndex(where: { $0.dismissed && ($0.state == "resolved" || ["done", "failed"].contains($0.event.kind)) }) else { throw TaskNotificationError.full }
                next.records.remove(at: removable)
            }
            guard next.nextID < UInt32.max else { throw TaskNotificationError.invalid }
            index = next.records.count
            next.records.append(TaskNotificationRecord(id: next.nextID, event: event, state: event.state, firstSeen: now)); next.nextID += 1; newRevision = true
        }
        try store.save(next); snapshot = next
        let id = snapshot.records[index].id
        let liveIDs = Set(snapshot.records.map(\.id))
        fresh.formIntersection(liveIDs); alerts = alerts.filter { liveIDs.contains($0.key) }
        fresh.insert(id)
        if newRevision {
            if event.kind == "done" { alerts[id] = 1 }
            else if event.kind == "failed" { alerts[id] = 3 }
            else { alerts[id] = event.state == "pending" ? 2 : 0 }
        }
        if !pinned, now >= presentationUntil { selected = preferredID(announcementsOnly: true) ?? selected ?? preferredID() }
    }
    func tick(now: Int64) {
        advanceClock(now)
        var next = snapshot
        var reminder: UInt32?
        var changed = false
        for i in next.records.indices {
            if next.records[i].state == "submitting", now >= (next.records[i].dispatchedAt ?? now) + 15_000 {
                next.records[i].state = "unknown"; changed = true
            }
            if reminder == nil, next.records[i].state == "pending", !next.records[i].dismissed,
               ["approval", "input"].contains(next.records[i].event.kind),
               !next.records[i].reminded, now >= next.records[i].firstSeen + 120_000 {
                next.records[i].reminded = true; changed = true; reminder = next.records[i].id
            }
        }
        if changed { do {
            try store.save(next); snapshot = next
            if let reminder { alerts[reminder] = 2 }
        } catch { fresh.removeAll() } }
        if !pinned, now >= presentationUntil, let next = preferredID(announcementsOnly: true) { selected = next }
    }
    func card(now: Int64) throws -> TaskNotificationCard {
        guard let record = snapshot.records.first(where: { $0.id == selected && !$0.dismissed }) else {
            return TaskNotificationCard(g: generation, id: 0, r: 0, src: "codex", kind: "done", title: "Inbox empty", model: "", detail: "", state: "resolved", count: count, ttl: 0, alert: 0, decide: false, ack: lastActionSequence, muteLegacyCodex: muteLegacyCodex ? true : nil)
        }
        let event = record.event
        let remaining = max(Int64(0), min(Int64(15_000), event.leaseDeadline - now))
        let displayable = !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !event.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && TaskNotificationEvent.ascii(event.title, max: 48) && TaskNotificationEvent.ascii(event.model, max: 32) && TaskNotificationEvent.ascii(event.detail, max: 192)
        let capable = event.canDecide == true && (event.kind == "approval" || (event.kind == "input" && event.options != nil))
        var card = TaskNotificationCard(g: generation, id: record.id, r: event.revision, src: event.source, kind: event.kind,
            title: event.title, model: event.model, detail: event.detail,
            state: record.state == "pending" && remaining == 0 && capable ? "expired" : record.state,
            count: count, ttl: Int(remaining), alert: alerts[record.id] ?? 0,
            decide: displayable && fresh.contains(record.id) && capable && record.state == "pending" && record.dispatchId == nil && remaining > 0 && event.createdAt <= now && now - event.createdAt <= 15_000 && event.leaseDeadline <= event.createdAt + 15_000,
            options: event.options, ack: lastActionSequence, outcome: record.state == "resolved" ? event.outcome : nil, muteLegacyCodex: muteLegacyCodex ? true : nil)
        if richContent, !capable, ["done", "failed"].contains(event.kind) {
            let position=(orderedVisibleRecords().firstIndex(where: {$0.id==record.id}) ?? 0)+1
            return try TaskNotificationPresentation.card(card,event:event,position:position)
        }
        if try !displayable || JSONEncoder().encode(card).count > 512 {
            card.title = "Open on Mac"; card.model = ""; card.detail = "Full scope available on Mac"; card.decide = false; card.options = nil
        }
        guard try JSONEncoder().encode(card).count <= 512 else { throw TaskNotificationError.invalid }
        return card
    }
    func handle(_ action: TaskNotificationAction, now: Int64) throws {
        advanceClock(now)
        guard action.v == 1, action.g == generation else { return }
        if let seq = action.seq {
            guard seq > lastActionSequence else { return }
            lastActionSequence = seq
        }
        let card = try card(now: now)
        guard action.v == 1, action.g == generation, action.id != 0, action.id == card.id, action.r == card.r,
              let index = snapshot.records.firstIndex(where: { $0.id == action.id }) else { return }
        switch action.action {
        case "next", "previous":
            let visible = orderedVisibleRecords()
            guard let current = visible.firstIndex(where: { $0.id == selected }), !visible.isEmpty else { return }
            selected = visible[(current + (action.action == "next" ? 1 : visible.count - 1)) % visible.count].id; pinned = true
        case "read": pinned = true
        case "close": pinned = false; presentationUntil = 0; selected = preferredID(announcementsOnly: true) ?? preferredID()
        case "dismiss":
            var next = snapshot; next.records[index].dismissed = true
            try store.save(next); snapshot = next
            selected = preferredID(announcementsOnly: true) ?? preferredID(); pinned = false; presentationUntil = 0
        case "open", "allow_once", "decline", "choose0", "choose1", "choose2":
            let event = snapshot.records[index].event
            let open = action.action == "open"
            guard open || card.decide else { return }
            var optionId: String?
            if action.action.hasPrefix("choose") {
                guard event.kind == "input", let choice = Int(action.action.suffix(1)), let ids = event.optionIds, choice < ids.count else { return }
                optionId = ids[choice]
            } else if !open { guard event.kind == "approval" else { return } }
            guard open || snapshot.records[index].dispatchId == nil else { return }
            let decisionID = UUID().uuidString
            let decision = TaskNotificationDecision(decisionId: decisionID, source: event.source, sessionId: event.sessionId, runId: event.runId, requestId: event.requestId, revision: event.revision, action: optionId != nil ? "choose" : action.action, createdAt: now, leaseDeadline: event.leaseDeadline, optionId: optionId)
            if open {
                pinned = true
                // Open is a nondeciding adapter request. No claim that routing succeeded.
                try store.publish(decision)
            } else {
                var next = snapshot; next.records[index].dispatchId = decisionID; next.records[index].dispatchedAt = now; next.records[index].state = "submitting"
                try store.save(next); snapshot = next; pinned = true
                do { try store.publish(decision) }
                catch {
                    snapshot.records[index].state = "unknown"; try? store.save(snapshot); throw error
                }
            }
        default: return
        }
    }
}
