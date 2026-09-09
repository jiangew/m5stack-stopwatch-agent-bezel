import Foundation

enum CompanionShortcutEvent: Equatable {
    case left, up, down, right, openHermes
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
    private var armed = true
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
               object["method"] as? String == "host.workspace_action" {
                guard Set(object.keys) == Set(["method", "params"]),
                      let params = object["params"] as? [String: Any],
                      Set(params.keys) == Set(["action"]),
                      params["action"] as? String == "open_hermes",
                      armed, acceptCooldown(now) else { continue }
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
        armed = true
        lastAcceptedAt = nil
    }

    private mutating func recognize(_ message: Message, now: TimeInterval) -> CompanionShortcutEvent? {
        guard message.method == "v.oai.rad",
              message.params.a.isFinite,
              message.params.d.isFinite,
              let event = event(for: message.params.a) else { return nil }
        if abs(message.params.d) <= Self.distanceTolerance {
            armed = true
            return nil
        }
        guard abs(message.params.d - 1.0) <= Self.distanceTolerance, armed else { return nil }
        armed = false
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
