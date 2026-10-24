import Foundation
import Darwin

private func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw NSError(domain: message, code: 1) }
}
private func event(_ request: String = "request-a", revision: UInt32 = 1, at: Int64 = 1_000,
                   decide: Bool = true, state: String = "pending", session: String = "session-a") -> TaskNotificationEvent {
    TaskNotificationEvent(eventId: "event-\(request)-\(revision)-\(at)-\(state)", source: "codex", sessionId: session,
        runId: "run-a", requestId: request, revision: revision, createdAt: at, leaseDeadline: at + 15_000,
        kind: "approval", title: "Synthetic task", model: "synthetic", detail: "Read synthetic fixture", canDecide: decide, state: state)
}
private func action(_ card: TaskNotificationCard, _ action: String) -> TaskNotificationAction {
    TaskNotificationAction(v: 1, g: card.g, id: card.id, r: card.r, action: action)
}
private func testRetiredHermesMigration() throws {
    let root=URL(fileURLWithPath:"/private/tmp").appendingPathComponent("retired-source-\(UUID())")
    defer {try? FileManager.default.removeItem(at:root)}
    let store=try TaskNotificationStore(directory:root.path)
    var retired=event("retired",decide:false,state:"resolved");retired.source="hermes"
    let supported=["codex","deepseek","super"]
    var records=[TaskNotificationRecord(id:1,event:retired,state:"resolved",firstSeen:1000)]
    for (index,source) in supported.enumerated() {
        var active=event("active-\(source)",decide:false);active.source=source
        records.append(TaskNotificationRecord(id:UInt32(index+2),event:active,state:"pending",firstSeen:1000))
    }
    let snapshot=TaskNotificationSnapshot(nextID:5,records:records)
    try store.save(snapshot)
    let broker=try TaskNotificationBroker(store:store)
    try check(broker.count==3,"retired Hermes must leave the visible queue")
    let saved=try store.load()
    try check(saved.records.map(\.event.source)==supported && saved.records.map(\.id)==[2,3,4] && saved.nextID==5,
              "migration must preserve other sources and stable IDs")
    do {try broker.ingest(retired,now:1001);throw NSError(domain:"retired ingress accepted",code:1)}
    catch TaskNotificationError.invalid {}
}
@main struct TaskNotificationRegression {
    static func main() throws {
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--bridge" {
            let store = try TaskNotificationStore(directory: CommandLine.arguments[2])
            let broker = try TaskNotificationBroker(store: store)
            try store.consumeEvents({ try broker.ingest($0, now: 1_001) }, rejected: { fatalError("bridge event rejected") })
            let card = try broker.card(now: 1_001)
            try broker.handle(action(card, "allow_once"), now: 1_001)
            print(String(decoding: try JSONEncoder().encode(try broker.card(now: 1_001)), as: UTF8.self))
            return
        }
        try testRetiredHermesMigration()
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent("notification-tests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try TaskNotificationStore(directory: root.path)
        do { _ = try TaskNotificationStore(directory: root.path); throw NSError(domain: "concurrent broker allowed", code: 1) }
        catch TaskNotificationError.io { }
        let broker = try TaskNotificationBroker(store: store)
        try broker.ingest(event(), now: 1_000)
        try broker.ingest(event(), now: 1_000)
        try check(broker.count == 1, "duplicate must not enqueue")
        let first = try broker.card(now: 1_000)
        try check(first.decide && first.id != 0, "live complete approval enabled")
        broker.published()
        try broker.ingest(event(at: 1_001), now: 1_001)
        try check(try broker.card(now: 1_001).alert == 0, "heartbeat cannot rearm alert")
        var changed = event(at: 1_002); changed.detail = "Changed scope"
        do { try broker.ingest(changed, now: 1_002); throw NSError(domain: "same revision scope accepted", code: 1) }
        catch TaskNotificationError.invalid { }
        try broker.handle(action(first, "read"), now: 1_000)
        try broker.ingest(event("request-b"), now: 1_000)
        try broker.ingest(event(session: "session-b"), now: 1_000)
        try check(broker.count == 3, "native request and session identity must differ")
        try broker.handle(action(first, "read"), now: 1_000)
        try broker.ingest(event("request-c"), now: 1_000)
        try check(try broker.card(now: 1_000).id == first.id, "new events cannot replace open detail")
        try broker.handle(action(first, "allow_once"), now: 1_001)
        try broker.handle(action(first, "allow_once"), now: 1_001)
        try check(try store.decisionNames().count == 1, "decision must publish once")
        let decision = try store.readDecision(try store.decisionNames()[0])
        try check(decision.requestId == "request-a" && decision.sessionId == "session-a" && decision.revision == 1,
                  "decision must bind exact native request revision")
        try check(try broker.card(now: 1_000).state == "submitting", "ATT or decision publication is not resolution")
        broker.tick(now: 16_001)
        try check(try broker.card(now: 16_001).state == "unknown", "lost resolution receipt becomes unknown")
        try broker.ingest(event(at: 16_001, state: "resolved"), now: 16_001)
        try check(try broker.card(now: 16_001).state == "resolved", "only native resolved confirms")
        try broker.ingest(event(at: 16_002), now: 16_002)
        try check(try broker.card(now: 16_002).state == "resolved", "same-revision pending cannot resurrect resolved request")
        try broker.ingest(event(revision: 2, at: 16_003), now: 16_003)
        let newer = try broker.card(now: 16_003)
        try broker.handle(action(first, "decline"), now: 16_003)
        try check(try store.decisionNames().count == 1, "stale revision cannot dispatch")
        let restarted = try TaskNotificationBroker(store: store)
        try check(!(try restarted.card(now: 16_003).decide), "restart disables approval before native refresh")
        try restarted.handle(action(try restarted.card(now: 16_003), "previous"), now: 16_003)
        try restarted.ingest(event(revision: 2, at: 16_004), now: 16_004)
        try check(try restarted.card(now: 16_004).decide, "fresh native lease reenables only untouched request")
        let current = try restarted.card(now: 16_004)
        restarted.reconnect()
        try restarted.handle(action(current, "allow_once"), now: 16_004)
        try check(try store.decisionNames().count == 1, "old connection generation cannot dispatch")
        try check(try restarted.card(now: 16_004).alert == 0, "reconnect suppresses alert")
        try restarted.handle(action(try restarted.card(now: 16_004), "next"), now: 16_004)
        try check(try restarted.card(now: 16_004).id != newer.id, "queue browsing selects next")
        let browsing = try restarted.card(now: 16_004)
        try restarted.ingest(event("arrived", at: 16_004), now: 16_004)
        try check(try restarted.card(now: 16_004).id == browsing.id, "arrivals cannot replace browsing")
        try restarted.handle(TaskNotificationAction(v: 1, g: browsing.g, id: browsing.id, r: browsing.r, action: "read", seq: 8), now: 16_004)
        try check(try restarted.card(now: 16_004).ack == 8, "transport sequence acknowledged without native resolution")
        let absentRoot = root.appendingPathComponent("absent")
        let absentStore = try TaskNotificationStore(directory: absentRoot.path)
        let absent = try TaskNotificationBroker(store: absentStore)
        try absent.ingest(event(decide: false), now: 1_000)
        try absent.handle(action(try absent.card(now: 1_000), "allow_once"), now: 1_000)
        try check(try absentStore.decisionNames().isEmpty, "absent capability fails closed")
        try absent.ingest(event(at: 1_001), now: 1_001)
        try absent.handle(action(try absent.card(now: 16_002), "decline"), now: 16_002)
        try check(try absentStore.decisionNames().isEmpty, "expired capability fails closed")
        var full = event("full"); full.detail = String(repeating: "x", count: 600)
        try absent.ingest(full, now: 1_000)
        try absent.handle(action(try absent.card(now: 1_000), "previous"), now: 1_000)
        let before = absent.count
        var invalid = event("bad"); invalid.detail = String(repeating: "x", count: 9000)
        do { try absent.ingest(invalid, now: 1_000); throw NSError(domain: "invalid accepted", code: 1) }
        catch TaskNotificationError.invalid { }
        try check(absent.count == before, "invalid event leaves state unchanged")
        for i in 0..<62 { try absent.ingest(event("bounded-\(i)", decide: false), now: 1_000) }
        do { try absent.ingest(event("overflow", decide: false), now: 1_000); throw NSError(domain: "queue overflow accepted", code: 1) }
        catch TaskNotificationError.full { }
        try check(absent.count == 64, "queue bounded without evicting pending approvals")
        let overflowPath = absentRoot.appendingPathComponent("inbox/overflow.json")
        try JSONEncoder().encode(event("overflow-inbox", decide: false)).write(to: overflowPath)
        chmod(overflowPath.path, 0o600)
        try absentStore.consumeEvents({ try absent.ingest($0, now: 1_000) }, rejected: {})
        try check(FileManager.default.fileExists(atPath: absentRoot.appendingPathComponent("processing/overflow.json").path), "queue overflow must stay durable for retry")
        let blob = try JSONEncoder().encode(try broker.card(now: 16_004))
        try check(blob.count <= 512, "wire bounded")
        try check(!String(decoding: blob, as: UTF8.self).contains("session-a"), "native identifiers never go on wire")
        let inputRoot = root.appendingPathComponent("input")
        let inputStore = try TaskNotificationStore(directory: inputRoot.path)
        let input = try TaskNotificationBroker(store: inputStore)
        var choice = event("input"); choice.kind = "input"; choice.options = ["Option A", "Option B"]; choice.optionIds = ["native-a", "native-b"]
        try input.ingest(choice, now: 1_000)
        try input.handle(action(try input.card(now: 1_000), "choose1"), now: 1_000)
        let chosen = try inputStore.readDecision(try inputStore.decisionNames()[0])
        try check(chosen.optionId == "native-b" && chosen.action == "choose", "choice resolves exact native option")
        let resolvedRoot = root.appendingPathComponent("resolved")
        let resolvedStore = try TaskNotificationStore(directory: resolvedRoot.path)
        let resolved = try TaskNotificationBroker(store: resolvedStore)
        try resolved.ingest(event(), now: 1_000)
        let pending = try resolved.card(now: 1_000)
        try resolved.ingest(event(state: "resolved"), now: 1_001)
        try resolved.handle(action(pending, "allow_once"), now: 1_001)
        try check(try resolvedStore.decisionNames().isEmpty, "resolution before click prevents native dispatch")
        try resolved.ingest(event(revision: 2, at: 1_001), now: 1_001)
        resolved.published()
        try resolved.ingest(event(revision: 2, at: 119_001), now: 119_001)
        resolved.tick(now: 121_002)
        try check(try resolved.card(now: 121_002).alert == 2, "one reminder uses firstSeen despite heartbeat")
        resolved.published(); resolved.tick(now: 122_002)
        try check(try resolved.card(now: 122_002).alert == 0, "reminder fires at most once")
        let completionRoot = root.appendingPathComponent("completions")
        let completions = try TaskNotificationBroker(store: TaskNotificationStore(directory: completionRoot.path))
        var done = event("done", decide: false, state: "resolved"); done.kind = "done"
        try completions.ingest(done, now: 1_000)
        try check(try completions.card(now: 1_000).alert == 1, "completed task gets completion alert")
        completions.published(); completions.tick(now: 121_001)
        try check(try completions.card(now: 121_001).alert == 0, "completion never gets approval reminder")
        var failure = event("failed", decide: false, state: "resolved"); failure.kind = "failed"
        try completions.ingest(failure, now: 1_000)
        try check(try completions.card(now: 1_000).alert == 3, "failure has failure alert and priority")
        let outcomeRoot = root.appendingPathComponent("outcomes")
        let outcomeBroker = try TaskNotificationBroker(store: TaskNotificationStore(directory: outcomeRoot.path))
        var cleared = event(state: "resolved")
        try outcomeBroker.ingest(cleared, now: 1_000)
        try check(try outcomeBroker.card(now: 1_000).outcome == nil, "resolved alone is cleared, never accepted")
        cleared.outcome = "cancelled"
        try outcomeBroker.ingest(cleared, now: 1_001)
        try check(try outcomeBroker.card(now: 1_001).outcome == "cancelled", "authoritative outcome may enrich cleared request")
        var emptyScope = event("empty-scope"); emptyScope.title = ""; emptyScope.detail = ""
        try outcomeBroker.ingest(emptyScope, now: 1_001)
        try check(!(try outcomeBroker.card(now: 1_001).decide), "empty scope cannot authorize decision")
        let link = root.appendingPathComponent("linked")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: absentRoot.path)
        do { _ = try TaskNotificationStore(directory: link.path); throw NSError(domain: "symlink accepted", code: 1) }
        catch TaskNotificationError.unsafe { }
        print("PASS TaskNotificationRegression: identity, duplicate, stale/expired capability, idempotency, authoritative resolution, restart, reconnect, browsing, bounds, symlink")
    }
}
