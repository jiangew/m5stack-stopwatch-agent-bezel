import Foundation

@MainActor
protocol WorkspaceCycling: AnyObject {
    func cycle()
    func openHermes()
    func openSelectedWorkspace()
    func showHome()
    var allowsNavigation: Bool { get }
    var selectedProfile: WorkspaceAppProfile? { get }
}

extension WorkspaceCycling {
    func openHermes() {}
    func openSelectedWorkspace() {}
    func showHome() {}
    var allowsNavigation: Bool { true }
    var selectedProfile: WorkspaceAppProfile? { .codex }
}

@MainActor
final class WorkspaceCycleController: WorkspaceCycling {
    private(set) var displayMode = StopwatchWorkspaceMode.home
    var modeDidChange: ((StopwatchWorkspaceMode) -> Void)?
    var allowsNavigation: Bool {
        guard displayMode.waitingState == nil, let profile = selectedProfile,
              let target = workspace.frontmost, target.processIdentifier > 0,
              profile.matches(target.bundleIdentifier) else { return false }
        return profile == .codex || workspace.windowPresence(target) == .available
    }
    var selectedProfile: WorkspaceAppProfile? { displayMode.profile }
    private let workspace: WorkspaceApplications
    private let observer: ForegroundApplicationObserving
    private let scheduler: WorkspaceModeScheduling
    private let log: (String) -> Void
    private var started = false
    private var generation: UInt64 = 0
    private var lifecycleGeneration: UInt64 = 0
    private var pending: (generation: UInt64, profile: WorkspaceAppProfile, identity: ApplicationIdentity?)?
    private var timeout: WorkspaceModeScheduledTask?
    private var windowMonitor: WorkspaceModeScheduledTask?
    private var windowMonitorGeneration: UInt64 = 0

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
        showHome()
        observer.stop()
    }

    func cycle() {
        guard started else { return }
        let desktops = WorkspaceAppProfile.selectableDesktops
        let target: WorkspaceAppProfile
        if let selectedProfile {
            guard let index = desktops.firstIndex(of: selectedProfile),
                  index + 1 < desktops.count else { showHome(); return }
            target = desktops[index + 1]
        } else {
            target = desktops[0]
        }
        generation &+= 1
        clearPending()
        // Swiping selects a page; only a central tap may launch or activate.
        setMode(.waiting(target))
        foregroundChanged(workspace.frontmost?.bundleIdentifier)
    }

    func openHermes() {
        guard selectedProfile == .hermes else { return }
        openSelectedWorkspace()
    }

    func openSelectedWorkspace() {
        guard started, let profile = selectedProfile else { return }
        // Recheck foreground before interpreting a tap, including a notification race.
        if displayMode.waitingState == nil {
            foregroundChanged(workspace.frontmost?.bundleIdentifier)
        }
        guard displayMode.waitingState == "idle" || displayMode.waitingState == "error" else { return }
        let identity = runningIdentity(for: profile)
        // Opening an existing app sends its reopen request, restoring a closed
        // last window. Merely activating its process can leave no usable UI.
        requestActivation(profile, identity: identity)
    }

    func resetToForeground() {
        generation &+= 1
        clearPending()
        let mode = StopwatchWorkspaceMode.foreground(workspace.frontmost?.bundleIdentifier)
        setMode(mode.profile.map { WorkspaceAppProfile.selectableDesktops.contains($0) } == true ? mode : .home)
    }

    func showHome() {
        generation &+= 1
        clearPending()
        let unchanged = displayMode == .home
        setMode(.home)
        if unchanged { modeDidChange?(.home) }
    }

    private func runningIdentity(for profile: WorkspaceAppProfile) -> ApplicationIdentity? {
        profile.acceptedBundleIdentifiers.lazy.compactMap {
            self.workspace.runningApplication(bundleIdentifier: $0)
        }.first(where: { profile.matches($0.bundleIdentifier) && $0.processIdentifier > 0 })
    }

    private func requestActivation(_ profile: WorkspaceAppProfile, identity: ApplicationIdentity?) {
        generation &+= 1
        let request = generation
        clearPending()
        pending = (request, profile, identity)
        setMode(.waiting(profile, state: "opening"))
        timeout = scheduler.scheduleRepeating(every: 3) { [weak self] in
            guard let self, self.started, self.pending?.generation == request else { return }
            self.clearPending()
            self.setMode(.waiting(profile, state: "error"))
            self.log("桌面尚未就绪；就绪后自动恢复，也可轻触中心重试")
        }
        // Reuse the exact running bundle (including legacy SUPER), and never
        // request a second instance. A real foreground identity is still required.
        workspace.launchAndActivate(bundleIdentifier: identity?.bundleIdentifier ?? profile.bundleIdentifier) { [weak self] accepted in
            self?.completeRequest(request, accepted: accepted)
        }
    }

    private func completeRequest(_ request: UInt64, accepted: Bool) {
        guard started, let pending, pending.generation == request else { return }
        guard accepted else {
            clearPending()
            setMode(.waiting(pending.profile, state: "error"))
            log("找不到或无法激活目标桌面应用")
            return
        }
        // Successful submission alone is never foreground/PID confirmation.
        foregroundChanged(workspace.frontmost?.bundleIdentifier)
    }

    private func foregroundChanged(_ bundle: String?) {
        if let pending {
            guard pending.profile.matches(bundle),
                  let target = workspace.frontmost, target.bundleIdentifier == bundle,
                  target.processIdentifier > 0,
                  pending.identity.map({ $0 == target }) ?? true else { return }
            if pending.profile != .codex {
                guard workspace.windowPresence(target) == .available else { return }
            }
            if pending.profile == .hermes {
                guard workspace.focusWindow(target), workspace.frontmost == target else { return }
            }
            generation &+= 1
            clearPending()
            setMode(.foreground(target.bundleIdentifier))
            return
        }
        // Selection belongs to the watch. Other foreground apps never replace it.
        // Late callbacks remain invalid. A fresh observation of the selected
        // foreground window can recover readiness after a slow reopen timeout.
        guard let profile = selectedProfile,
              displayMode.waitingState == nil || displayMode.waitingState == "idle"
                || displayMode.waitingState == "error" else { return }
        guard let target = workspace.frontmost, target.bundleIdentifier == bundle,
              profile.matches(bundle), target.processIdentifier > 0,
              profile == .codex || workspace.windowPresence(target) == .available,
              profile != .hermes || displayMode == .hermes || workspace.focusWindow(target),
              workspace.frontmost == target else {
            // Keep a failed request retryable while its actual window is absent.
            if displayMode.waitingState != "error" { setMode(.waiting(profile)) }
            return
        }
        setMode(.foreground(target.bundleIdentifier))
    }

    private func inspectSelectedWorkspace() {
        guard started, selectedProfile != nil else { return }
        // Polling also detects a terminated app or a window appearing after activation.
        foregroundChanged(workspace.frontmost?.bundleIdentifier)
    }

    private func setMode(_ mode: StopwatchWorkspaceMode) {
        guard displayMode != mode else { return }
        if displayMode.profile != mode.profile {
            windowMonitorGeneration &+= 1
            windowMonitor?.cancel()
            windowMonitor = nil
        }
        displayMode = mode
        // One bounded 1Hz observer while an Agent page is selected. No launch here.
        if mode.profile != nil && windowMonitor == nil && started {
            windowMonitorGeneration &+= 1
            let token = windowMonitorGeneration
            windowMonitor = scheduler.scheduleRepeating(every: 1) { [weak self] in
                guard let self, self.started, self.windowMonitorGeneration == token,
                      self.selectedProfile != nil else { return }
                self.inspectSelectedWorkspace()
            }
        } else if mode.profile == nil {
            windowMonitorGeneration &+= 1
            windowMonitor?.cancel()
            windowMonitor = nil
        }
        modeDidChange?(mode)
    }

    private func clearPending() {
        timeout?.cancel()
        timeout = nil
        pending = nil
    }
}
