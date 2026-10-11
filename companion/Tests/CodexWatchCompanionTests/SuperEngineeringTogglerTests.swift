import XCTest
import ApplicationServices
@testable import CodexWatchCompanion

@MainActor
final class WorkspaceStub: WorkspaceApplications {
    var frontmost: ApplicationIdentity?
    var runningByBundleID: [String: ApplicationIdentity] = [:]
    var activatable: Set<ApplicationIdentity> = []
    var activations: [ApplicationIdentity] = []
    var launchRequests: [String] = []
    var launchCompletion: ((Bool) -> Void)?
    var onOpen: ((String) -> Void)?
    var focusedWindows: [ApplicationIdentity] = []
    var windowFocusSucceeds = true
    var presence: ApplicationWindowPresence = .available
    var windowQueries: [ApplicationIdentity] = []
    func windowPresence(_ identity: ApplicationIdentity) -> ApplicationWindowPresence {
        windowQueries.append(identity)
        return presence
    }

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
        onOpen?(bundleIdentifier)
    }
}

@MainActor
final class HermesWindowResolverTests: XCTestCase {
    func testHermesReopenedStandardWindowWithoutFocusOrMainHandleIsResolved() {
        let app = AXUIElementCreateApplication(701)
        let helper = AXUIElementCreateApplication(703)
        let window = AXUIElementCreateApplication(701)
        var queries: [String] = []
        let resolved = HermesWindowResolver.resolve(application: app, processIdentifier: 701) { element, attribute in
            queries.append(attribute)
            if CFEqual(element, app) && attribute == kAXWindowsAttribute { return (.success, [helper, window] as CFArray) }
            if attribute == kAXRoleAttribute { return (.success, kAXWindowRole as CFString) }
            if attribute == kAXSubroleAttribute { return (.success, (CFEqual(element, helper) ? kAXFloatingWindowSubrole : kAXStandardWindowSubrole) as CFString) }
            if attribute == kAXMinimizedAttribute { return (.success, kCFBooleanFalse) }
            return (.noValue, nil)
        }
        XCTAssertTrue(resolved != nil)
        XCTAssertTrue(queries.contains(kAXWindowsAttribute))
    }

    func testHermesFallbackRejectsForeignAndNonstandardWindows() {
        let app = AXUIElementCreateApplication(701), foreign = AXUIElementCreateApplication(702), floating = AXUIElementCreateApplication(701)
        let resolved = HermesWindowResolver.resolve(application: app, processIdentifier: 701) { _, attribute in
            if attribute == kAXWindowsAttribute { return (.success, [foreign, floating] as CFArray) }
            if attribute == kAXRoleAttribute { return (.success, kAXWindowRole as CFString) }
            if attribute == kAXSubroleAttribute { return (.success, kAXFloatingWindowSubrole as CFString) }
            if attribute == kAXMinimizedAttribute { return (.success, kCFBooleanFalse) }
            return (.noValue, nil)
        }
        XCTAssertNil(resolved)
    }

    func testHermesExistingFocusOrMainHandleKeepsFastPath() {
        for handle in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            let app = AXUIElementCreateApplication(701)
            var queriedWindows = false
            let resolved = HermesWindowResolver.resolve(application: app, processIdentifier: 701) { _, attribute in
                if attribute == handle { return (.success, app) }
                if attribute == kAXWindowsAttribute { queriedWindows = true }
                return (.noValue, nil)
            }
            XCTAssertTrue(resolved != nil)
            XCTAssertFalse(queriedWindows)
        }
    }

    func testHermesFallbackDoesNotTreatMinimizedWindowAsReady() {
        let app = AXUIElementCreateApplication(701)
        let resolved = HermesWindowResolver.resolve(application: app, processIdentifier: 701) { _, attribute in
            switch attribute {
            case kAXWindowsAttribute: return (.success, [app] as CFArray)
            case kAXRoleAttribute: return (.success, kAXWindowRole as CFString)
            case kAXSubroleAttribute: return (.success, kAXStandardWindowSubrole as CFString)
            case kAXMinimizedAttribute: return (.success, kCFBooleanTrue)
            default: return (.noValue, nil)
            }
        }
        XCTAssertNil(resolved)
    }

    func testHermesFocusQueryFailureDoesNotEnumerateWindows() {
        let app = AXUIElementCreateApplication(701)
        var queriedWindows = false
        let resolved = HermesWindowResolver.resolve(application: app, processIdentifier: 701) { _, attribute in
            if attribute == kAXWindowsAttribute { queriedWindows = true }
            return (.cannotComplete, nil)
        }
        XCTAssertNil(resolved)
        XCTAssertFalse(queriedWindows)
    }
}
