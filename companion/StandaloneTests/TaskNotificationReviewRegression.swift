import Foundation

private func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw NSError(domain: message, code: 1) }
}
private func event(_ id: String, at: Int64 = 1000, state: String = "pending") -> TaskNotificationEvent {
    TaskNotificationEvent(eventId: "event-\(id)-\(at)-\(state)", source: "codex", sessionId: "synthetic-session", runId: "synthetic-run", requestId: id, revision: 1, createdAt: at, leaseDeadline: at + 15000, kind: "approval", title: "Synthetic task", model: "test", detail: "Synthetic scope, once only", canDecide: true, state: state)
}
private func action(_ card: TaskNotificationCard, _ name: String) -> TaskNotificationAction {
    TaskNotificationAction(v: 1, g: card.g, id: card.id, r: card.r, action: name)
}
@main struct TaskNotificationReviewRegression {
    static func main() throws {
        var delivery = TaskNotificationWriteSchedule()
        let payload = Data("synthetic".utf8)
        try require(delivery.shouldWrite(payload, now: 1000), "First card must be sent")
        delivery.sent(payload, now: 1000)
        try require(!delivery.shouldWrite(payload, now: 5999), "Unchanged card need not flood BLE")
        try require(delivery.shouldWrite(payload, now: 6000), "Unchanged card must refresh channel lease every 5s")
        delivery.reset()
        try require(delivery.shouldWrite(payload, now: 6001), "Reconnect sends unchanged card in new transport epoch")
        let root = URL(fileURLWithPath: "/private/tmp/notification-review-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try TaskNotificationStore(directory: root.appendingPathComponent("reconnect").path)
        let broker = try TaskNotificationBroker(store: store)
        try broker.ingest(event("A"), now: 1000)
        try broker.handle(action(try broker.card(now: 1000), "read"), now: 1000)
        broker.reconnect()
        try broker.ingest(event("A", at: 1001, state: "resolved"), now: 1001)
        try broker.ingest(event("B", at: 1002), now: 1002)
        let card = try broker.card(now: 1002)
        try require(card.state == "pending" && card.alert == 2, "Reconnect must release old pin for fresh arrivals")
        try broker.handle(action(card, "allow_once"), now: 1003)
        broker.tick(now: 16004)
        try require(try broker.card(now: 16004).state == "unknown", "Lost native result is unknown")
        try broker.handle(action(try broker.card(now: 16004), "open"), now: 16004)
        let routes = try store.decisionNames().map { try store.readDecision($0).action }
        try require(routes.contains("open"), "UNKNOWN must permit nondeciding open for reconciliation")

        let offlineStore = try TaskNotificationStore(directory: root.appendingPathComponent("offline").path)
        for _ in 0..<128 {
            try offlineStore.publish(TaskNotificationDecision(decisionId: UUID().uuidString, source: "codex", sessionId: "old", runId: "old", requestId: "old", revision: 1, action: "allow_once", createdAt: 1000, leaseDeadline: 16000))
        }
        let recovered = try TaskNotificationBroker(store: offlineStore)
        try recovered.ingest(event("fresh", at: 100000), now: 100000)
        try recovered.handle(action(try recovered.card(now: 100000), "decline"), now: 100001)
        try require(try offlineStore.decisionNames().count == 1, "Expired orphan decisions cannot exhaust mailbox forever")
        try require(try recovered.card(now: 100001).state == "submitting", "Fresh native decision publishes after offline cleanup")
        let fifoStore = try TaskNotificationStore(directory: root.appendingPathComponent("fifo").path)
        let fifo = try TaskNotificationBroker(store: fifoStore)
        var doneA = event("doneA", state: "resolved"); doneA.kind = "done"; doneA.canDecide = false
        try fifo.ingest(doneA, now: 1000); let firstDone = try fifo.card(now: 1000); fifo.published()
        var doneB = event("doneB", at: 1001, state: "resolved"); doneB.kind = "done"; doneB.canDecide = false
        try fifo.ingest(doneB, now: 1001)
        fifo.tick(now: 5999)
        try require(try fifo.card(now: 5999).id == firstDone.id, "Do not replace the five-second announcement early")
        fifo.tick(now: 6000)
        let secondDone = try fifo.card(now: 6000)
        try require(secondDone.id != firstDone.id && secondDone.alert == 1, "Second completion must be announced after first toast")
        fifo.published(); fifo.tick(now: 12000)
        try require(try fifo.card(now: 12000).alert == 0, "Announcement is delivered once")
        print("PASS reconnect pin release, UNKNOWN open routing and expired mailbox recovery")
    }
}
