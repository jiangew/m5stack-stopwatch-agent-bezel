import Foundation

enum TaskNotificationError: Error { case invalid, unsafe, io, full }

/// Native request TTL is independent of the BLE channel lease. Even a terminal
/// card with ttl=0 needs a heartbeat so Read/Open/Dismiss continue to work.
struct TaskNotificationWriteSchedule {
    private var payload: Data?
    private var sentAt: Int64?
    func shouldWrite(_ next: Data, now: Int64) -> Bool {
        guard let sentAt else { return true }
        return payload != next || now < sentAt || now - sentAt >= 5_000
    }
    mutating func sent(_ next: Data, now: Int64) { payload = next; sentAt = now }
    mutating func reset() { payload = nil; sentAt = nil }
}

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
    var project: String? = nil
    var excerpted: Bool? = nil
    var terminalReason: String? = nil
    var modelConfigured: Bool? = nil
    var requiresCompleteScope: Bool { canDecide == true && (kind == "approval" || (kind == "input" && options != nil)) }
    var identity: [String] { [source, sessionId, runId, requestId] }

    func validate(allowRetiredSource: Bool = false) throws {
        let supported = ["codex", "deepseek", "super"].contains(source)
        guard v == 1, supported || (allowRetiredSource && source == "hermes"),
              ["done", "approval", "input", "failed"].contains(kind), ["pending", "resolved"].contains(state),
              revision > 0, createdAt >= 0, createdAt <= Int64.max - 120_000, leaseDeadline >= 0,
              [eventId, sessionId, runId, requestId].allSatisfy({ !$0.isEmpty && $0.utf8.count <= 256 && !$0.contains("\0") }),
              [title, model, detail].allSatisfy({ $0.utf8.count <= 4096 && !$0.contains("\0") }),
              try JSONEncoder().encode(self).count <= 8192 else { throw TaskNotificationError.invalid }
        if let project { guard project.utf8.count <= 64, !project.contains("\0") else { throw TaskNotificationError.invalid } }
        if modelConfigured == true {
            guard source == "codex", !model.isEmpty, canDecide != true else {throw TaskNotificationError.invalid}
        }
        if let terminalReason {
            guard ["completed", "error", "aborted", "blocked", "max-tokens"].contains(terminalReason),
                  kind == (terminalReason == "completed" ? "done" : "failed"), state == "resolved", canDecide != true else { throw TaskNotificationError.invalid }
        }
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
    var muteLegacyCodex: Bool? = nil
    var layout: Int? = nil
    var pos: Int? = nil
    var project: String? = nil
    var time: String? = nil
    var excerpted: Bool? = nil
    var terminalReason: String? = nil
    var modelConfigured: Bool? = nil
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
    // Persist presentation ownership through same-revision authority withdrawal.
    var completeScope: Bool? = nil
}
struct TaskNotificationSnapshot: Codable {
    var v = 1
    var nextID: UInt32 = 1
    var records: [TaskNotificationRecord] = []
}

/// Presentation only. Native routing and the durable original remain unchanged.
enum TaskNotificationPresentation {
    static func prefix(_ text: String, bytes: Int) -> String {
        var result="", used=0
        for scalar in text.unicodeScalars {
            let part=String(scalar), size=part.utf8.count
            if used+size>bytes { break }
            result+=part;used+=size
        }
        return result
    }
    static func plain(_ text: String) -> String {
        text.components(separatedBy:.whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator:" ")
            .unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.map(String.init).joined()
    }
    static func card(_ original: TaskNotificationCard, event: TaskNotificationEvent, position: Int) throws -> TaskNotificationCard {
        var card=original
        card.layout=["approval","input"].contains(event.kind) ? 3 : 2;card.pos=position
        card.options=nil;card.terminalReason=event.terminalReason
        card.model=TaskNotificationEvent.ascii(event.model,max:128) ? event.model : ""
        if card.model.utf8.count>32 {card.model=prefix(card.model,bytes:29)+"..."}
        card.modelConfigured=card.model.isEmpty ? nil : event.modelConfigured
        let name=plain(event.title)
        let title = name.isEmpty ? "未命名任务 #\(card.id)" : name
        card.title=prefix(String(title.prefix(32)),bytes:96)
        if card.title != title {card.title=prefix(String(title.prefix(29)),bytes:93)+"..."}
        card.project=prefix(plain(event.project ?? ""),bytes:32)
        if card.project?.isEmpty == true || ["codex","deepseek"].contains(event.source) {card.project=nil}
        let formatter=DateFormatter();formatter.locale=Locale(identifier:"en_US_POSIX");formatter.dateFormat="HH:mm"
        card.time=formatter.string(from:Date(timeIntervalSince1970:Double(event.createdAt)/1000))
        let full=plain(event.detail)
        var budget=128
        while true {
            card.detail=prefix(full,bytes:budget)
            if card.detail.utf8.count<full.utf8.count && budget>=3 {
                card.detail=prefix(full,bytes:budget-3)
                if let end=card.detail.last, end.isASCII && end.isLetter,
                   let space=card.detail.lastIndex(of:" "), card.detail[..<space].utf8.count>budget/2 {
                    card.detail=String(card.detail[..<space])
                }
                card.detail+="..."
            }
            card.excerpted=(event.excerpted == true || card.detail.utf8.count<full.utf8.count) ? true : nil
            var ceiling=card;ceiling.count=64;ceiling.pos=64;ceiling.ack=UInt32.max;ceiling.ttl=15_000
            // The immutable excerpt must fit every renewal and authoritative outcome.
            if card.layout==3 {ceiling.state="submitting";ceiling.outcome="cancelled"}
            if try JSONEncoder().encode(ceiling).count<=512 {return card}
            if budget>0 {budget=max(0,budget-8);continue}
            if card.project != nil {card.project=nil;continue}
            throw TaskNotificationError.invalid
        }
    }
}
