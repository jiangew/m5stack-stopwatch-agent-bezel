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

enum ApplicationWindowPresence: Equatable { case available, none, unknown }

@MainActor
protocol WorkspaceApplications: AnyObject {
    var frontmost: ApplicationIdentity? { get }
    func runningApplication(bundleIdentifier: String) -> ApplicationIdentity?
    @discardableResult func activate(_ identity: ApplicationIdentity) -> Bool
    func focusWindow(_ identity: ApplicationIdentity) -> Bool
    func windowPresence(_ identity: ApplicationIdentity) -> ApplicationWindowPresence
    func launchAndActivate(bundleIdentifier: String, completion: @MainActor @escaping (Bool) -> Void)
}

extension WorkspaceApplications {
    func windowPresence(_ identity: ApplicationIdentity) -> ApplicationWindowPresence { .unknown }
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

    func windowPresence(_ target: ApplicationIdentity) -> ApplicationWindowPresence {
        func currentIdentityMatches() -> Bool {
            guard let app = NSRunningApplication(processIdentifier: target.processIdentifier), !app.isTerminated else { return false }
            return identity(for: app) == target
        }
        guard let profile = WorkspaceAppProfile(bundleIdentifier: target.bundleIdentifier),
              profile != .codex,
              target.processIdentifier > 0, currentIdentityMatches() else { return .unknown }
        // SUPER keeps layer-zero CG helper windows after its user window closes.
        // CG presence (even with nonzero dimensions) is NOT evidence of a usable
        // application window. Only the authorized AX application window list is
        // authoritative; permission/query failure remains unknown, never absent.
        guard AXIsProcessTrusted() else { return .unknown }
        let app = AXUIElementCreateApplication(target.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.05)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == CFArrayGetTypeID(),
              let windows = value as? [AXUIElement] else { return .unknown }
        // Bound worst-case synchronous AX work on the main actor.
        var incomplete = windows.count > 4
        for window in windows.prefix(4) {
            var pid: pid_t = 0
            guard AXUIElementGetPid(window, &pid) == .success, pid == target.processIdentifier else { incomplete = true; continue }
            AXUIElementSetMessagingTimeout(window, 0.05)
            var role: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &role) == .success else { incomplete = true; continue }
            if role as? String == kAXWindowRole {
                return currentIdentityMatches() ? .available : .unknown
            }
        }
        guard !incomplete, currentIdentityMatches() else { return .unknown }
        return .none
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
        guard let window = HermesWindowResolver.resolve(application: application, processIdentifier: target.processIdentifier),
              frontmost == target else { return false }
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

// Isolate window lookup from activation and window actions so the AX no-value
// transition can be exercised without changing focus on a developer's desktop.
enum HermesWindowResolver {
    typealias ReadAttribute = (AXUIElement, String) -> (AXError, CFTypeRef?)

    static func resolve(application: AXUIElement, processIdentifier: pid_t,
                        read: ReadAttribute = readAttribute) -> AXUIElement? {
        let focused = read(application, kAXFocusedWindowAttribute)
        if focused.0 == .success, let value = focused.1 {
            return ownedWindow(value, processIdentifier: processIdentifier)
        }
        let main = read(application, kAXMainWindowAttribute)
        if main.0 == .success, let value = main.1 {
            return ownedWindow(value, processIdentifier: processIdentifier)
        }
        // Electron can expose a reopened standard window before publishing its
        // focused/main handles. Resolve that window, then let the caller raise it
        // and verify actual focus. Permission/transport failures stay fail-closed.
        func missingHandle(_ query: (AXError, CFTypeRef?)) -> Bool {
            query.0 == .noValue || (query.0 == .success && query.1 == nil)
        }
        guard missingHandle(focused), missingHandle(main) else { return nil }
        let (result, value) = read(application, kAXWindowsAttribute)
        guard result == .success, let value, CFGetTypeID(value) == CFArrayGetTypeID(),
              let windows = value as? [AXUIElement] else { return nil }
        for candidate in windows.prefix(4) {
            guard let window = ownedWindow(candidate, processIdentifier: processIdentifier) else { continue }
            AXUIElementSetMessagingTimeout(window, 0.05)
            let role = read(window, kAXRoleAttribute), subrole = read(window, kAXSubroleAttribute)
            let minimized = read(window, kAXMinimizedAttribute)
            guard role.0 == .success, role.1 as? String == kAXWindowRole,
                  subrole.0 == .success, subrole.1 as? String == kAXStandardWindowSubrole,
                  minimized.0 == .success, let minimizedValue = minimized.1,
                  CFEqual(minimizedValue, kCFBooleanFalse) else { continue }
            return window
        }
        return nil
    }

    private static func ownedWindow(_ value: CFTypeRef, processIdentifier: pid_t) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let window = unsafeBitCast(value, to: AXUIElement.self)
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success, pid == processIdentifier else { return nil }
        return window
    }

    private static func readAttribute(_ element: AXUIElement, _ attribute: String) -> (AXError, CFTypeRef?) {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return (result, value)
    }
}
