import ApplicationServices
import Foundation

protocol AccessibilityTrustChecking {
    var isTrusted: Bool { get }
}

struct SystemAccessibilityTrustChecker: AccessibilityTrustChecking {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }
}

@MainActor
final class WorkspaceCommandRouter {
    private let workspace: WorkspaceApplications
    private let toggler: WorkspaceCycling
    private let emitter: ProcessTargetedKeyEmitting
    private let accessibility: AccessibilityTrustChecking
    private let log: (String) -> Void
    private let diagnose: (NavigationDiagnosticStage) -> Void
    private var didWarnAboutAccessibility = false

    init(
        workspace: WorkspaceApplications,
        toggler: WorkspaceCycling,
        emitter: ProcessTargetedKeyEmitting,
        accessibility: AccessibilityTrustChecking,
        log: @escaping (String) -> Void,
        diagnose: @escaping (NavigationDiagnosticStage) -> Void = { _ in }
    ) {
        self.workspace = workspace
        self.toggler = toggler
        self.emitter = emitter
        self.accessibility = accessibility
        self.log = log
        self.diagnose = diagnose
    }

    func handle(_ event: CompanionShortcutEvent) {
        switch event {
        case .showHome:
            emitter.cancel()
            toggler.showHome()
        case .left:
            guard toggler.selectedProfile == .codex else { return }
            emitter.cancel()
            toggler.cycle()
        case .openHermes:
            toggler.openHermes()
        case .up, .down, .right:
            // Native reports belong to Codex and must not become dedicated keys.
            return
        case let .navigation(origin, direction):
            guard toggler.selectedProfile == origin.profile else {
                diagnose(.selectionRejected)
                return
            }
            if direction == .left {
                emitter.cancel()
                toggler.cycle()
                return
            }
            guard origin != .home else { return }
            guard toggler.allowsNavigation else {
                emitter.cancel()
                diagnose(.waitingRejected)
                return
            }
            guard let target = workspace.frontmost,
                  let profile = WorkspaceAppProfile(bundleIdentifier: target.bundleIdentifier),
                  profile == origin.profile,
                  let command = profile.command(for: direction.nativeEvent) else {
                diagnose(.foregroundRejected)
                emitter.cancel()
                return
            }
            guard accessibility.isTrusted else {
                emitter.cancel()
                diagnose(.accessibilityRejected)
                if !didWarnAboutAccessibility {
                    didWarnAboutAccessibility = true
                    log("辅助功能权限未开启；super.engineering / Hermes 导航不可用")
                }
                return
            }
            diagnose(.accessibilityAllowed)
            guard emitter.emit(command, to: target) else {
                log("super.engineering 导航按键发送失败")
                return
            }
        }
    }
}
