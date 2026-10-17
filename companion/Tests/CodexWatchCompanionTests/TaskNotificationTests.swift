import Foundation
import XCTest
@testable import CodexWatchCompanion

final class TaskNotificationTests: XCTestCase {
    func testIdentityAndAuthoritativeResolution() throws {
        let directory = URL(fileURLWithPath: "/private/tmp").appendingPathComponent("task-notification-xctest-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try TaskNotificationStore(directory: directory.path)
        let broker = try TaskNotificationBroker(store: store)
        var event = TaskNotificationEvent(eventId: "synthetic", source: "codex", sessionId: "session", runId: "run", requestId: "request", revision: 1, createdAt: 1_000, leaseDeadline: 16_000, kind: "approval", title: "Synthetic", model: "test", detail: "Read fixture", canDecide: true)
        try broker.ingest(event, now: 1_000)
        try broker.ingest(event, now: 1_000)
        XCTAssertEqual(broker.count, 1)
        let card = try broker.card(now: 1_000)
        let action = TaskNotificationAction(v: 1, g: card.g, id: card.id, r: card.r, action: "allow_once")
        try broker.handle(action, now: 1_000)
        try broker.handle(action, now: 1_000)
        XCTAssertEqual(try store.decisionNames().count, 1)
        XCTAssertEqual(try broker.card(now: 1_000).state, "submitting")
        event.state = "resolved"
        try broker.ingest(event, now: 1_001)
        XCTAssertEqual(try broker.card(now: 1_001).state, "resolved")
        try broker.handle(action, now: 1_001)
        XCTAssertEqual(try store.decisionNames().count, 1)
    }

    func testOptionsDefaultAndRestartFailClosed() throws {
        let directory = URL(fileURLWithPath: "/private/tmp").appendingPathComponent("task-notification-restart-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try TaskNotificationStore(directory: directory.path)
        let broker = try TaskNotificationBroker(store: store)
        var event = TaskNotificationEvent(eventId: "synthetic", source: "hermes", sessionId: "session", runId: "run", requestId: "request", revision: 1, createdAt: 1_000, leaseDeadline: 16_000, kind: "input", title: "Synthetic", model: "test", detail: "Choose fixture", canDecide: true, options: ["A", "B"], optionIds: ["native-a", "native-b"])
        try broker.ingest(event, now: 1_000)
        XCTAssertTrue(try broker.card(now: 1_000).decide)
        let restart = try TaskNotificationBroker(store: store)
        XCTAssertFalse(try restart.card(now: 1_000).decide)
        event.createdAt = 1_001; event.eventId = "refresh"; event.leaseDeadline = 16_001
        try restart.ingest(event, now: 1_001)
        XCTAssertTrue(try restart.card(now: 1_001).decide)
        XCTAssertThrowsError(try parseOptions(["companion", "--notifications-dir", "/private/tmp/synthetic"]))
    }
}
