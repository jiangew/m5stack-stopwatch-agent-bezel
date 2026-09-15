import XCTest
@testable import CodexWatchCompanion

@MainActor
final class WorkspaceStub: WorkspaceApplications {
    var frontmost: ApplicationIdentity?
    var runningByBundleID: [String: ApplicationIdentity] = [:]
    var activatable: Set<ApplicationIdentity> = []
    var activations: [ApplicationIdentity] = []
    var launchRequests: [String] = []
    var launchCompletion: ((Bool) -> Void)?
    var focusedWindows: [ApplicationIdentity] = []
    var windowFocusSucceeds = true

    func focusWindow(_ identity: ApplicationIdentity) -> Bool {
        focusedWindows.append(identity)
        return windowFocusSucceeds
    }

    func runningApplication(bundleIdentifier: String) -> ApplicationIdentity? {
        runningByBundleID[bundleIdentifier]
    }

    func activate(_ identity: ApplicationIdentity) -> Bool {
        guard activatable.contains(identity) else { return false }
        activations.append(identity)
        return true
    }

    func launchAndActivate(bundleIdentifier: String, completion: @MainActor @escaping (Bool) -> Void) {
        launchRequests.append(bundleIdentifier)
        launchCompletion = completion
    }
}
