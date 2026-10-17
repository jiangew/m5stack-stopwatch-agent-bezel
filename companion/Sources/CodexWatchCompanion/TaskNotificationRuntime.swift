import Foundation

final class TaskNotificationRuntime {
    private let store: TaskNotificationStore
    private let broker: TaskNotificationBroker
    private var transport: TaskNotificationTransport!
    private var timer: Timer?
    private var delivery = TaskNotificationWriteSchedule()
    private let log: (String) -> Void
    init(directory: String, identifier: UUID, log: @escaping (String) -> Void) throws {
        self.log = log
        store = try TaskNotificationStore(directory: directory)
        broker = try TaskNotificationBroker(store: store)
        transport = TaskNotificationTransport(identifier: identifier, receive: { [weak self] action in
            guard let self else { return }
            do { try self.broker.handle(action, now: Self.now) }
            catch { self.log("通知操作未发送；请在 Mac 核对原请求") }
            self.poll()
        }, connectionChanged: { [weak self] in self?.broker.reconnect(); self?.delivery.reset() }, log: log)
    }
    private static var now: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    func start() {
        guard timer == nil else { return }
        transport.start()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.poll() }
        poll()
    }
    func stop() { timer?.invalidate(); timer = nil; transport.stop() }
    private func poll() {
        let now = Self.now
        transport.pollActions()
        do {
            try store.consumeEvents({ try broker.ingest($0, now: now) }, rejected: { log("通知事件无效或队列已满；请在 Mac 核对") })
            broker.tick(now: now)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            var card = try broker.card(now: now)
            // Round down remaining lease: host must never extend native authority.
            card.ttl = card.ttl / 1000 * 1000
            if card.ttl == 0 { card.decide = false }
            let payload = try encoder.encode(card)
            if delivery.shouldWrite(payload, now: now), transport.send(payload) {
                delivery.sent(payload, now: now); broker.published()
            }
        } catch { log("通知私有存储不可用；请在 Mac 核对") }
    }
}
