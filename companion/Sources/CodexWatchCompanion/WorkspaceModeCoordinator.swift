import AppKit
import Foundation

@MainActor
protocol ForegroundApplicationObserving: AnyObject {
    var frontmostBundleIdentifier: String? { get }
    func start(_ handler: @MainActor @escaping (String?) -> Void)
    func stop()
}

@MainActor
final class SystemForegroundApplicationObserver: ForegroundApplicationObserving {
    private let workspace: NSWorkspace
    private var observation: NSObjectProtocol?

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    var frontmostBundleIdentifier: String? {
        workspace.frontmostApplication?.bundleIdentifier
    }

    func start(_ handler: @MainActor @escaping (String?) -> Void) {
        stop()
        observation = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            MainActor.assumeIsolated {
                handler(application?.bundleIdentifier)
            }
        }
    }

    func stop() {
        guard let observation else { return }
        workspace.notificationCenter.removeObserver(observation)
        self.observation = nil
    }

    deinit {
        if let observation {
            workspace.notificationCenter.removeObserver(observation)
        }
    }
}

@MainActor
protocol WorkspaceModeScheduledTask: AnyObject {
    func cancel()
}

@MainActor
protocol WorkspaceModeScheduling: AnyObject {
    func scheduleRepeating(
        every interval: TimeInterval,
        _ handler: @MainActor @escaping () -> Void
    ) -> WorkspaceModeScheduledTask
}

@MainActor
private final class SystemWorkspaceModeScheduledTask: WorkspaceModeScheduledTask {
    private var timer: Timer?

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}

@MainActor
final class SystemWorkspaceModeScheduler: WorkspaceModeScheduling {
    func scheduleRepeating(
        every interval: TimeInterval,
        _ handler: @MainActor @escaping () -> Void
    ) -> WorkspaceModeScheduledTask {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated {
                handler()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        return SystemWorkspaceModeScheduledTask(timer: timer)
    }
}

@MainActor
final class WorkspaceModeCoordinator {
    static let targetBundleIdentifier = "com.zarifpour.superconductor"
    static let heartbeatInterval: TimeInterval = 5
    static let failureLogInterval: TimeInterval = 60

    private let foregroundObserver: ForegroundApplicationObserving
    private let interaction: WorkspaceCycleController?
    private let scheduler: WorkspaceModeScheduling
    private let uptime: () -> TimeInterval
    private let log: (String) -> Void
    private var sendersByDevice: [UInt: WorkspaceModeSending] = [:]
    private var heartbeat: WorkspaceModeScheduledTask?
    private var codexRetry: WorkspaceModeScheduledTask?
    private var remainingRetries: [UInt: Int] = [:]
    private var desiredMode = StopwatchWorkspaceMode.codex
    private var lastFailureLogAt: TimeInterval?
    private var started = false
    private var lifecycle: UInt64 = 0
    private var heartbeatGeneration: UInt64 = 0
    private var retryGeneration: UInt64 = 0

    init(foregroundObserver: ForegroundApplicationObserving,
         scheduler: WorkspaceModeScheduling,
         uptime: @escaping () -> TimeInterval, log: @escaping (String) -> Void,
         interaction: WorkspaceCycleController? = nil) {
        self.foregroundObserver = foregroundObserver
        self.scheduler = scheduler
        self.uptime = uptime
        self.log = log
        self.interaction = interaction
    }

    convenience init(interaction: WorkspaceCycleController? = nil, log: @escaping (String) -> Void) {
        self.init(foregroundObserver: SystemForegroundApplicationObserver(),
                  scheduler: SystemWorkspaceModeScheduler(),
                  uptime: { ProcessInfo.processInfo.systemUptime }, log: log, interaction: interaction)
    }

    var activeDeviceKeys: Set<UInt> { Set(sendersByDevice.keys) }

    func start() {
        guard !started else { return }
        started = true
        lifecycle &+= 1
        let epoch = lifecycle
        if let interaction {
            interaction.modeDidChange = { [weak self] mode in
                guard let self, self.started, self.lifecycle == epoch else { return }
                self.transition(to: mode)
            }
            transition(to: interaction.displayMode)
            return
        }
        foregroundObserver.start { [weak self] bundleIdentifier in
            guard let self, self.started, self.lifecycle == epoch else { return }
            self.transition(to: self.mode(for: bundleIdentifier))
        }
        transition(to: mode(for: foregroundObserver.frontmostBundleIdentifier))
    }

    func attach(_ sender: WorkspaceModeSending) {
        guard started else { return }
        interaction?.showHome()
        transition(to: interaction?.displayMode ?? mode(for: foregroundObserver.frontmostBundleIdentifier))
        sendersByDevice[sender.deviceKey] = sender
        remainingRetries.removeValue(forKey: sender.deviceKey)
        synchronize(sender)
    }

    func detach(deviceKey: UInt) {
        sendersByDevice.removeValue(forKey: deviceKey)
        remainingRetries.removeValue(forKey: deviceKey)
        if remainingRetries.isEmpty { cancelCodexRetry() }
        interaction?.showHome()
    }

    func stop() {
        guard started else { return }
        for key in sendersByDevice.keys.sorted() {
            if let sender = sendersByDevice[key] { _ = send(interaction == nil ? .codex : .home, to: sender) }
        }
        started = false
        lifecycle &+= 1
        cancelHeartbeat()
        cancelCodexRetry()
        foregroundObserver.stop()
        interaction?.modeDidChange = nil
        sendersByDevice.removeAll()
        desiredMode = .codex
    }

    private func mode(for bundleIdentifier: String?) -> StopwatchWorkspaceMode {
        switch WorkspaceAppProfile(bundleIdentifier: bundleIdentifier) {
        case .super: return .super
        case .hermes: return .hermes
        default: return .codex
        }
    }

    private func transition(to mode: StopwatchWorkspaceMode) {
        guard mode != desiredMode else {
            if mode == .home {
                for key in sendersByDevice.keys.sorted() {
                    if let sender=sendersByDevice[key] { synchronize(sender) }
                }
            }
            if interaction != nil || mode != .codex { startHeartbeatIfNeeded() }
            return
        }
        cancelCodexRetry()
        desiredMode = mode
        for key in sendersByDevice.keys.sorted() {
            if let sender = sendersByDevice[key] { synchronize(sender) }
        }
        if interaction != nil || mode != .codex { startHeartbeatIfNeeded() } else { cancelHeartbeat() }
    }

    private func synchronize(_ sender: WorkspaceModeSending) {
        let success = send(desiredMode, to: sender)
        if desiredMode == .codex {
            if success { remainingRetries.removeValue(forKey: sender.deviceKey) }
            else { remainingRetries[sender.deviceKey] = 2 }
            if remainingRetries.isEmpty { cancelCodexRetry() }
            else { startCodexRetryIfNeeded() }
        }
    }

    private func startHeartbeatIfNeeded() {
        guard heartbeat == nil else { return }
        let epoch = lifecycle, timer = heartbeatGeneration
        heartbeat = scheduler.scheduleRepeating(every: Self.heartbeatInterval) { [weak self] in
            guard let self, self.started, self.lifecycle == epoch,
                  self.heartbeatGeneration == timer,
                  self.interaction != nil || self.desiredMode != .codex else { return }
            for key in self.sendersByDevice.keys.sorted() {
                if let sender = self.sendersByDevice[key] { _ = self.send(self.desiredMode, to: sender) }
            }
        }
    }

    private func cancelHeartbeat() {
        heartbeat?.cancel()
        heartbeat = nil
        heartbeatGeneration &+= 1
    }

    private func startCodexRetryIfNeeded() {
        guard codexRetry == nil else { return }
        let epoch = lifecycle, timer = retryGeneration
        codexRetry = scheduler.scheduleRepeating(every: Self.heartbeatInterval) { [weak self] in
            guard let self, self.started, self.lifecycle == epoch,
                  self.retryGeneration == timer, self.desiredMode == .codex else { return }
            for key in self.remainingRetries.keys.sorted() {
                guard let sender = self.sendersByDevice[key],
                      let remaining = self.remainingRetries[key] else {
                    self.remainingRetries.removeValue(forKey: key)
                    continue
                }
                if self.send(.codex, to: sender) || remaining <= 1 {
                    self.remainingRetries.removeValue(forKey: key)
                } else { self.remainingRetries[key] = remaining - 1 }
            }
            if self.remainingRetries.isEmpty { self.cancelCodexRetry() }
        }
    }

    private func cancelCodexRetry() {
        codexRetry?.cancel()
        codexRetry = nil
        remainingRetries.removeAll()
        retryGeneration &+= 1
    }

    @discardableResult
    private func send(_ mode: StopwatchWorkspaceMode, to sender: WorkspaceModeSending) -> Bool {
        guard !sender.send(mode) else { return true }
        let now = uptime()
        if lastFailureLogAt.map({ now - $0 < Self.failureLogInterval }) != true {
            lastFailureLogAt = now
            log("StopWatch 屏幕模式同步失败；后续重试或由固件租约回退")
        }
        return false
    }
}
