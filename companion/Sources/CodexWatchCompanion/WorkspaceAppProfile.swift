import Foundation

enum WorkspaceAppProfile: CaseIterable {
    case codex, `super`, hermes

    /// The bundle identifier used to launch a missing application.
    /// SUPER moved from its legacy identifier in the 2026-09 release.
    var bundleIdentifier: String {
        switch self {
        case .codex: return "com.openai.codex"
        case .super: return "engineering.super.app"
        case .hermes: return "com.nousresearch.hermes"
        }
    }

    var acceptedBundleIdentifiers: [String] {
        switch self {
        case .codex:
            return ["com.openai.codex"]
        case .super:
            return ["engineering.super.app", "com.zarifpour.superconductor"]
        case .hermes:
            return ["com.nousresearch.hermes"]
        }
    }

    func matches(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return acceptedBundleIdentifiers.contains(bundleIdentifier)
    }

    init?(bundleIdentifier: String?) {
        guard let profile = Self.allCases.first(where: { $0.matches(bundleIdentifier) }) else { return nil }
        self = profile
    }

    var next: Self {
        switch self {
        case .codex: return .super
        case .super: return .hermes
        case .hermes: return .codex
        }
    }

    func command(for event: CompanionShortcutEvent) -> WorkspaceNavigationCommand? {
        switch (self, event) {
        case (.super, .up): return .previousProject
        case (.super, .down): return .nextProject
        case (.super, .right): return .nextTab
        case (.hermes, .up): return .previousHermesTab
        case (.hermes, .down): return .nextHermesTab
        case (.hermes, .right): return .confirmHermesSelection
        default: return nil
        }
    }
}

enum WorkspaceNavigationCommand: Equatable {
    case previousProject, nextProject, nextTab
    case previousHermesTab, nextHermesTab, confirmHermesSelection

    var profile: WorkspaceAppProfile {
        switch self {
        case .previousProject, .nextProject, .nextTab: return .super
        case .previousHermesTab, .nextHermesTab, .confirmHermesSelection: return .hermes
        }
    }
}
