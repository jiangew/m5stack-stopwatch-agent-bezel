import AppKit
import ApplicationServices
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
    func focusWindow(_ identity: ApplicationIdentity) -> Bool
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

    func focusWindow(_ target: ApplicationIdentity) -> Bool {
        guard target.bundleIdentifier == "com.nousresearch.hermes",
              frontmost == target,
              identity(for: NSRunningApplication(processIdentifier: target.processIdentifier)) == target else { return false }
        // Preserve central app opening without Accessibility; navigation still
        // refuses keys through the existing trust checks.
        guard AXIsProcessTrusted() else { return true }
        let application = AXUIElementCreateApplication(target.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.05)
        var value: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &value)
        if result != .success || value == nil {
            result = AXUIElementCopyAttributeValue(application, kAXMainWindowAttribute as CFString, &value)
        }
        guard result == .success, let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return false }
        let window = unsafeBitCast(value, to: AXUIElement.self)
        var windowPID: pid_t = 0
        guard AXUIElementGetPid(window, &windowPID) == .success,
              windowPID == target.processIdentifier, frontmost == target else { return false }
        AXUIElementSetMessagingTimeout(window, 0.05)
        // Touch window-level attributes only; never enumerate contents or click.
        _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        guard frontmost == target else { return false }
        guard AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success else { return false }
        var settable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(window, kAXFocusedAttribute as CFString, &settable) == .success,
           settable.boolValue, frontmost == target {
            _ = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }
        guard frontmost == target else { return false }
        var focused: CFTypeRef?
        return AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &focused) == .success
            && focused.map { CFEqual($0, window) } == true
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
