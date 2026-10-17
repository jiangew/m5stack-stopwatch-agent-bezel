import Foundation

enum TaskNotificationError: Error { case invalid, unsafe, io, full }

struct TaskNotificationEvent: Codable, Equatable {
    var v = 1
    var eventId: String
    var source: String
    var sessionId: String
    var runId: String
    var requestId: String
    var revision: UInt32
    var createdAt: Int64
    var leaseDeadline: Int64
    var kind: String
    var title: String
    var model: String
    var detail: String
    var canDecide: Bool? = false
    var state = "pending"
    var options: [String]?
    var optionIds: [String]?
    var outcome: String?
    var identity: [String] { [source, sessionId, runId, requestId] }

    func validate() throws {
        guard v == 1, ["codex", "deepseek", "super", "hermes"].contains(source),
              ["done", "approval", "input", "failed"].contains(kind), ["pending", "resolved"].contains(state),
              revision > 0, createdAt >= 0, createdAt <= Int64.max - 120_000, leaseDeadline >= 0,
              [eventId, sessionId, runId, requestId].allSatisfy({ !$0.isEmpty && $0.utf8.count <= 256 && !$0.contains("\0") }),
              [title, model, detail].allSatisfy({ $0.utf8.count <= 4096 && !$0.contains("\0") }),
              try JSONEncoder().encode(self).count <= 8192 else { throw TaskNotificationError.invalid }
        if let outcome {
            guard state == "resolved", ["allowed", "declined", "answered", "cancelled"].contains(outcome) else { throw TaskNotificationError.invalid }
        }
        if options != nil || optionIds != nil {
            guard kind == "input", let options, let optionIds, (2...3).contains(options.count), options.count == optionIds.count,
                  options.allSatisfy({ !$0.isEmpty && Self.ascii($0, max: 24) }),
                  optionIds.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 256 && !$0.contains("\0") }),
                  Set(optionIds).count == optionIds.count else { throw TaskNotificationError.invalid }
        }
    }
    static func ascii(_ text: String, max: Int) -> Bool {
        text.utf8.count <= max && text.utf8.allSatisfy { (32...126).contains($0) }
    }
}

struct TaskNotificationCard: Codable, Equatable {
    var v = 1
    var g: UInt32
    var id: UInt32
    var r: UInt32
    var src: String
    var kind: String
    var title: String
    var model: String
    var detail: String
    var state: String
    var count: Int
    var ttl: Int
    var alert: Int
    var decide: Bool
    var options: [String]?
    var ack: UInt32 = 0
    var outcome: String?
}
struct TaskNotificationAction: Codable {
    var v: Int
    var g: UInt32
    var id: UInt32
    var r: UInt32
    var action: String
    var seq: UInt32? = nil
}
struct TaskNotificationDecision: Codable {
    var v = 1
    var decisionId: String
    var source: String
    var sessionId: String
    var runId: String
    var requestId: String
    var revision: UInt32
    var action: String
    var createdAt: Int64
    var leaseDeadline: Int64
    var optionId: String?
}
struct TaskNotificationRecord: Codable {
    var id: UInt32
    var event: TaskNotificationEvent
    var state: String
    var firstSeen: Int64
    var dismissed = false
    var dispatchId: String?
    var dispatchedAt: Int64?
    var reminded = false
}
struct TaskNotificationSnapshot: Codable {
    var v = 1
    var nextID: UInt32 = 1
    var records: [TaskNotificationRecord] = []
}
