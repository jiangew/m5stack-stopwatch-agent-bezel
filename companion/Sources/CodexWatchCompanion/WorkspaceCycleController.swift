import Foundation

@MainActor
protocol WorkspaceCycling: AnyObject {
    func cycle()
    func openHermes()
    func showHome()
    var allowsNavigation: Bool { get }
    var selectedProfile: WorkspaceAppProfile? { get }
}

extension WorkspaceCycling {
    func openHermes() {}
    func showHome() {}
    var allowsNavigation: Bool { true }
    var selectedProfile: WorkspaceAppProfile? { .codex }
}

@MainActor
final class WorkspaceCycleController: WorkspaceCycling {
    private(set) var displayMode = StopwatchWorkspaceMode.home
    var modeDidChange: ((StopwatchWorkspaceMode) -> Void)?
    var allowsNavigation: Bool { displayMode != .home && !displayMode.awaitingHermes }
    var selectedProfile: WorkspaceAppProfile? {
        switch displayMode {
        case .home: return nil
        case .codex: return .codex
        case .super: return .super
        case .hermes, .hermesIdle, .hermesOpening, .hermesError: return .hermes
        }
    }
    private let workspace: WorkspaceApplications
    private let observer: ForegroundApplicationObserving
    private let scheduler: WorkspaceModeScheduling
    private let log: (String) -> Void
    private var started = false
    private var generation: UInt64 = 0
    private var lifecycleGeneration: UInt64 = 0
    private var pending: (generation: UInt64, origin: String?, target: String)?
    private var timeout: WorkspaceModeScheduledTask?

    init(workspace: WorkspaceApplications,
         observer: ForegroundApplicationObserving,
         scheduler: WorkspaceModeScheduling,
         log: @escaping (String) -> Void) {
        self.workspace = workspace
        self.observer = observer
        self.scheduler = scheduler
        self.log = log
    }

    func start() {
        guard !started else { return }
        started = true
        lifecycleGeneration &+= 1
        let lifecycle = lifecycleGeneration
        showHome()
        observer.start { [weak self] bundle in
            guard let self, self.started, self.lifecycleGeneration == lifecycle else { return }
            self.foregroundChanged(bundle)
        }
    }

    func stop() {
        started = false
        lifecycleGeneration &+= 1
        generation &+= 1
        clearPending()
        setMode(.home)
        observer.stop()
    }

    func cycle() {
        guard started else { return }
        if displayMode == .hermes || displayMode.awaitingHermes {
            showHome()
            return
        }
        guard pending == nil else { return }
        let target = (displayMode == .home ? WorkspaceAppProfile.codex :
                      displayMode == .codex ? .super : .hermes).bundleIdentifier
        if target == WorkspaceAppProfile.hermes.bundleIdentifier {
            setMode(.hermesIdle)
            return
        }
        requestActivation(target)
    }

    func openHermes() {
        guard started, displayMode == .hermesIdle || displayMode == .hermesError else { return }
        setMode(.hermesOpening)
        requestActivation(WorkspaceAppProfile.hermes.bundleIdentifier, reopen: true)
    }

    func resetToForeground() {
        generation &+= 1
        clearPending()
        setMode(.foreground(workspace.frontmost?.bundleIdentifier))
    }

    func showHome() {
        generation &+= 1
        clearPending()
        let unchanged = displayMode == .home
        setMode(.home)
        // An already-pinned Home still acknowledges a device's resync request.
        if unchanged { modeDidChange?(.home) }
    }

    private func requestActivation(_ target: String, reopen: Bool = false) {
        let origin = workspace.frontmost?.bundleIdentifier
        generation &+= 1
        let request = generation
        pending = (request, origin, target)
        timeout = scheduler.scheduleRepeating(every: 3) { [weak self] in
            guard let self, self.started, self.pending?.generation == request else { return }
            self.clearPending()
            if self.displayMode == .hermesOpening { self.setMode(.hermesError) }
            self.log("桌面切换等待超时；保持真实前台")
        }
        // A Hermes central tap must request reopening, not merely activate a
        // running process whose last window may have been closed.
        if !reopen, let identity = workspace.runningApplication(bundleIdentifier: target) {
            completeRequest(request, accepted: workspace.activate(identity))
        } else {
            workspace.launchAndActivate(bundleIdentifier: target) { [weak self] accepted in
                self?.completeRequest(request, accepted: accepted)
            }
        }
    }

    private func completeRequest(_ request: UInt64, accepted: Bool) {
        guard started, pending?.generation == request else { return }
        if !accepted {
            clearPending()
            if displayMode == .hermesOpening { setMode(.hermesError) }
            log("找不到或无法激活目标桌面应用")
        } else {
            // Successful submission alone is not proof of a foreground change.
            if workspace.frontmost?.bundleIdentifier == pending?.target {
                foregroundChanged(workspace.frontmost?.bundleIdentifier)
            }
        }
    }

    private func foregroundChanged(_ bundle: String?) {
        if pending?.target == "com.nousresearch.hermes",
           bundle == pending?.target, displayMode == .hermesOpening {
            guard let target = workspace.frontmost,
                  target.bundleIdentifier == bundle,
                  workspace.focusWindow(target) else { return }
        }
        if displayMode == .home && (pending == nil || pending?.target != bundle) {
            generation &+= 1
            clearPending()
            return
        }
        // A real activation supersedes selection, even if it reactivates the
        // origin app. Submission callbacks never synthesize this notification.
        generation &+= 1
        clearPending()
        setMode(.foreground(bundle))
    }

    private func setMode(_ mode: StopwatchWorkspaceMode) {
        guard displayMode != mode else { return }
        displayMode = mode
        modeDidChange?(mode)
    }

    private func clearPending() {
        timeout?.cancel()
        timeout = nil
        pending = nil
    }
}
