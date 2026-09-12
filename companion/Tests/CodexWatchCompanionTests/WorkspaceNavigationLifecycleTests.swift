import XCTest
@testable import CodexWatchCompanion

@MainActor private final class NavigationObserver: ForegroundApplicationObserving {
    var frontmostBundleIdentifier: String? = nil
    var handler: (@MainActor (String?) -> Void)?
    var starts = 0
    var stops = 0
    func start(_ handler: @MainActor @escaping (String?) -> Void) { starts += 1; self.handler = handler }
    func stop() { stops += 1 }
}
@MainActor private final class NavigationOwner: ProcessTargetedKeyEmitting {
    var cancels = 0
    var stops = 0
    func emit(_ command: WorkspaceNavigationCommand, to identity: ApplicationIdentity) -> Bool { true }
    func cancel() { cancels += 1 }
    func stop() { stops += 1 }
}
@MainActor final class WorkspaceNavigationLifecycleTests: XCTestCase {
    func testForegroundDeviceCancellationAndStopInvalidateLateCallbacks() {
        let observer = NavigationObserver(); let owner = NavigationOwner()
        let lifecycle = WorkspaceNavigationLifecycle(observer:observer,emitter:owner)
        lifecycle.start(); lifecycle.start()
        XCTAssertEqual(observer.starts,1)
        observer.handler?("com.openai.codex")
        lifecycle.cancel() // Device attach/removal use this same cancellation path.
        XCTAssertEqual(owner.cancels,2)
        lifecycle.stop(); lifecycle.stop()
        observer.handler?("com.nousresearch.hermes"); lifecycle.cancel(); lifecycle.start()
        XCTAssertEqual(owner.cancels,2); XCTAssertEqual(owner.stops,1)
        XCTAssertEqual(observer.stops,1); XCTAssertEqual(observer.starts,1)
    }
}
