import Foundation

/// Synthetic process protocol for coupled production Broker/Controller tests.
@main struct TaskNotificationCoupledProbe {
    static func main() throws {
        let store = try TaskNotificationStore(directory: CommandLine.arguments[2])
        if ["--consume", "--backpressured"].contains(CommandLine.arguments[1]) {
            var accepted = Set<String>(), rejected = 0
            for _ in 0..<2 {
                var result: [String: Any] = [:]
                do { try store.consumeEvents({ event in
                    try event.validate()
                    if CommandLine.arguments[1] == "--backpressured" { throw TaskNotificationError.full }
                    accepted.insert(event.eventId)
                }, rejected: { rejected += 1 }) }
                catch { result["error"] = String(describing: error) }
                result["consumed"] = accepted.count; result["rejected"] = rejected
                let data = try JSONSerialization.data(withJSONObject: result)
                print(String(decoding: data, as: UTF8.self))
            }
            return
        }
        let broker = try TaskNotificationBroker(store: store)
        while let line = readLine() {
            let command = try JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any]
            let now = (command["now"] as? NSNumber)?.int64Value ?? 1000
            switch command["op"] as? String {
            case "ingest":
                let request = command["request"] as! String
                let revision = (command["revision"] as? NSNumber)?.uint32Value ?? 1
                let kind = command["kind"] as? String ?? "approval"
                let event = TaskNotificationEvent(eventId: "event-\(request)-\(revision)", source: "codex", sessionId: "synthetic-session", runId: "synthetic-run", requestId: request, revision: revision, createdAt: now, leaseDeadline: now + 15000, kind: kind, title: request, model: "synthetic", detail: "Scope r\(revision)", canDecide: kind == "approval", state: "pending")
                try broker.ingest(event, now: now)
            case "action":
                let data = try JSONSerialization.data(withJSONObject: command["action"]!)
                try broker.handle(JSONDecoder().decode(TaskNotificationAction.self, from: data), now: now)
            case "published": broker.published()
            case "tick": broker.tick(now: now)
            case "decisions":
                print("{\"decisions\":\(try store.decisionNames().count)}")
                fflush(stdout); continue
            default: fatalError("Unknown synthetic probe operation")
            }
            print(String(decoding: try JSONEncoder().encode(broker.card(now: now)), as: UTF8.self))
            fflush(stdout)
        }
    }
}
