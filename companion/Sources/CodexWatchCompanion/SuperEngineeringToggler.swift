import AppKit
import Foundation

struct ApplicationIdentity: Equatable, Hashable {
    let processIdentifier: pid_t
    let bundleIdentifier: String
    let launchDate: Date?

    init(processIdentifier: pid_t, bundleIdentifier: String, launchDate: Date? = nil) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.launchDate = launchDate
    }
}

@MainActor
protocol WorkspaceApplications: AnyObject {
    var frontmost: ApplicationIdentity? { get }
    func runningApplication(bundleIdentifier: String) -> ApplicationIdentity?
    @discardableResult func activate(_ identity: ApplicationIdentity) -> Bool
    func launchAndActivate(bundleIdentifier: String, completion: @MainActor @escaping (Bool) -> Void)
}

@MainActor
final class NSWorkspaceApplications: WorkspaceApplications {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    var frontmost: ApplicationIdentity? {
        identity(for: workspace.frontmostApplication)
    }

    func runningApplication(bundleIdentifier: String) -> ApplicationIdentity? {
        workspace.runningApplications
            .first(where: { $0.bundleIdentifier == bundleIdentifier })
            .flatMap { identity(for: $0) }
    }

    func activate(_ identity: ApplicationIdentity) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: identity.processIdentifier),
              application.bundleIdentifier == identity.bundleIdentifier,
              !application.isTerminated else { return false }
        return application.activate(options: [])
    }

    func launchAndActivate(bundleIdentifier: String, completion: @MainActor @escaping (Bool) -> Void) {
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            completion(false)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        workspace.openApplication(at: url, configuration: configuration) { application, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    completion(application?.bundleIdentifier == bundleIdentifier)
                }
            }
        }
    }

    private func identity(for application: NSRunningApplication?) -> ApplicationIdentity? {
        guard let application, let bundleIdentifier = application.bundleIdentifier else { return nil }
        return ApplicationIdentity(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: bundleIdentifier,
            launchDate: application.launchDate
        )
    }
}
