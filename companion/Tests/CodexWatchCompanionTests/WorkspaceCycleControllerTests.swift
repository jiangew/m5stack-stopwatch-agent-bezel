import XCTest
@testable import CodexWatchCompanion

@MainActor
private final class CycleObserver: ForegroundApplicationObserving {
    var frontmostBundleIdentifier: String?
    var handler: (@MainActor (String?) -> Void)?
    func start(_ handler: @MainActor @escaping (String?) -> Void) { self.handler = handler }
    func stop() { handler = nil }
    func change(_ id: String?) { frontmostBundleIdentifier = id; handler?(id) }
}

@MainActor
private final class CycleTask: WorkspaceModeScheduledTask {
    let handler: @MainActor () -> Void
    var cancelled = false
    init(_ handler: @MainActor @escaping () -> Void) { self.handler = handler }
    func cancel() { cancelled = true }
    // Deliberately simulate a queued callback even after cancel.
    func fire() { handler() }
}

@MainActor
private final class CycleScheduler: WorkspaceModeScheduling {
    var tasks: [CycleTask] = []
    var intervals: [TimeInterval] = []
    func scheduleRepeating(every interval: TimeInterval, _ handler: @MainActor @escaping () -> Void) -> WorkspaceModeScheduledTask {
        intervals.append(interval)
        let task = CycleTask(handler); tasks.append(task); return task
    }
}

@MainActor
final class WorkspaceCycleControllerTests: XCTestCase {
    func testHermesCentralOpenRequiresWindowFocusAndDoesNotFocusAfterExit() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: "com.zarifpour.superconductor")
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start(); controller.resetToForeground(); controller.cycle(); controller.openHermes()
        let hermes = ApplicationIdentity(processIdentifier: 3, bundleIdentifier: "com.nousresearch.hermes")
        ws.frontmost = hermes
        ws.windowFocusSucceeds = false
        observer.change(hermes.bundleIdentifier)
        XCTAssertEqual(controller.displayMode, .hermesOpening)
        XCTAssertEqual(ws.focusedWindows, [hermes])
        ws.windowFocusSucceeds = true
        ws.launchCompletion?(true)
        XCTAssertEqual(controller.displayMode, .hermes)
        controller.cycle()
        let count = ws.focusedWindows.count
        ws.launchCompletion?(true)
        observer.change(hermes.bundleIdentifier)
        XCTAssertEqual(ws.focusedWindows.count, count)
        XCTAssertEqual(controller.displayMode, .home)
    }
    func testHomePinsForegroundWithoutLaunching() {
        let ws=WorkspaceStub(), observer=CycleObserver(), scheduler=CycleScheduler()
        let controller=WorkspaceCycleController(workspace:ws,observer:observer,scheduler:scheduler,log:{_ in})
        controller.start()
        XCTAssertFalse(controller.allowsNavigation)
        observer.change("com.nousresearch.hermes")
        XCTAssertFalse(controller.allowsNavigation)
        XCTAssertTrue(ws.launchRequests.isEmpty)
    }
    private let ids = ["com.openai.codex", "com.zarifpour.superconductor", "com.nousresearch.hermes"]

    func testSelectingHermesDoesNotLaunchOrActivate() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: ids[1])
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start(); controller.resetToForeground(); controller.cycle()
        XCTAssertTrue(ws.launchRequests.isEmpty)
        XCTAssertTrue(ws.activations.isEmpty)
        XCTAssertTrue(scheduler.tasks.isEmpty)
    }

    func testRunningHermesTapReopensOnceAndWaitsForRealForeground() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: ids[1])
        let hermes = ApplicationIdentity(processIdentifier: 3, bundleIdentifier: ids[2])
        ws.runningByBundleID[ids[2]] = hermes
        ws.activatable.insert(hermes)
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start(); controller.resetToForeground(); controller.cycle()
        controller.openHermes(); controller.openHermes()
        XCTAssertEqual(ws.launchRequests, [ids[2]])
        XCTAssertTrue(ws.activations.isEmpty)
        XCTAssertEqual(controller.displayMode, .hermesOpening)
        ws.launchCompletion?(true)
        XCTAssertEqual(controller.displayMode, .hermesOpening)
        ws.frontmost = hermes; observer.change(ids[2])
        XCTAssertEqual(controller.displayMode, .hermes)
        controller.openHermes()
        XCTAssertEqual(ws.launchRequests, [ids[2]])
    }

    func testFullCycleUsesActualForegroundAndNeverPreviousApp() {
        let ws=WorkspaceStub(), observer=CycleObserver(), scheduler=CycleScheduler()
        let controller=WorkspaceCycleController(workspace:ws,observer:observer,scheduler:scheduler,log:{_ in})
        controller.start()
        XCTAssertEqual(controller.displayMode,.home)
        for id in ids {
            let app=ApplicationIdentity(processIdentifier:pid_t(ws.runningByBundleID.count+1),bundleIdentifier:id)
            ws.runningByBundleID[id]=app;ws.activatable.insert(app)
        }
        controller.cycle()
        XCTAssertEqual(ws.activations.last?.bundleIdentifier,ids[0])
        ws.frontmost=ws.runningByBundleID[ids[0]];observer.change(ids[0])
        controller.cycle()
        XCTAssertEqual(ws.activations.last?.bundleIdentifier,ids[1])
        ws.frontmost=ws.runningByBundleID[ids[1]];observer.change(ids[1])
        controller.cycle()
        XCTAssertEqual(controller.displayMode,.hermesIdle)
        controller.openHermes()
        ws.frontmost=ws.runningByBundleID[ids[2]];observer.change(ids[2])
        controller.cycle()
        XCTAssertEqual(controller.displayMode,.home)
        XCTAssertNil(controller.selectedProfile)
        XCTAssertEqual(ws.activations.map(\.bundleIdentifier),[ids[0],ids[1]])
        XCTAssertEqual(ws.launchRequests,[ids[2]])
        observer.change(ids[1])
        XCTAssertEqual(controller.displayMode,.home)
    }

    func testHermesTapTimeoutRequiresExplicitRetryAndIgnoresLateCompletion() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: ids[1])
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start(); controller.resetToForeground(); controller.cycle()
        XCTAssertEqual(controller.displayMode, .hermesIdle)
        XCTAssertFalse(controller.allowsNavigation)
        controller.openHermes(); controller.openHermes()
        XCTAssertEqual(ws.launchRequests, [ids[2]])
        XCTAssertEqual(controller.displayMode, .hermesOpening)
        let oldCompletion = ws.launchCompletion
        scheduler.tasks[0].fire()
        XCTAssertEqual(controller.displayMode, .hermesError)
        oldCompletion?(true); scheduler.tasks[0].fire()
        XCTAssertEqual(controller.displayMode, .hermesError)
        XCTAssertEqual(ws.launchRequests.count, 1)
        controller.openHermes()
        oldCompletion?(false)
        XCTAssertEqual(controller.displayMode, .hermesOpening)
        ws.frontmost = ApplicationIdentity(processIdentifier: 3, bundleIdentifier: ids[2])
        observer.change(ids[2])
        XCTAssertEqual(controller.displayMode, .hermes)
        XCTAssertTrue(controller.allowsNavigation)
        controller.openHermes()
        XCTAssertEqual(ws.launchRequests.count, 2)
    }

    func testHermesExitAndExternalActivationInvalidatePendingSelection() {
        let ws=WorkspaceStub(), observer=CycleObserver(), scheduler=CycleScheduler()
        ws.frontmost=ApplicationIdentity(processIdentifier:1,bundleIdentifier:ids[1])
        let controller=WorkspaceCycleController(workspace:ws,observer:observer,scheduler:scheduler,log:{_ in})
        controller.start();controller.resetToForeground();controller.cycle();controller.openHermes()
        let completion=ws.launchCompletion
        controller.cycle()
        XCTAssertEqual(controller.displayMode,.home)
        XCTAssertEqual(ws.launchRequests,[ids[2]])
        completion?(true);observer.change(ids[2])
        XCTAssertEqual(controller.displayMode,.home)
        controller.resetToForeground();controller.cycle()
        XCTAssertEqual(controller.displayMode,.hermesIdle)
        observer.change(ids[1])
        XCTAssertEqual(controller.displayMode,.super)
    }

    func testUnknownForegroundStartsAtCodexAndFailedLaunchCanRetry() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start(); controller.cycle(); controller.cycle()
        XCTAssertEqual(ws.launchRequests, [ids[0]])
        ws.launchCompletion?(false); controller.cycle()
        XCTAssertEqual(ws.launchRequests, [ids[0], ids[0]])
    }

    func testTimeoutAndOldCompletionsCannotClearNewRequest() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start(); controller.cycle()
        let oldCompletion = ws.launchCompletion
        scheduler.tasks[0].fire()
        controller.cycle()
        oldCompletion?(false); scheduler.tasks[0].fire(); controller.cycle()
        XCTAssertEqual(ws.launchRequests.count, 2)
        let oldObserver = observer.handler
        controller.stop(); controller.start(); controller.cycle()
        oldObserver?("com.example.old-callback")
        oldCompletion?(true); scheduler.tasks[1].fire(); controller.cycle()
        XCTAssertEqual(ws.launchRequests.count, 3)
        controller.stop(); controller.cycle()
        XCTAssertEqual(ws.launchRequests.count, 3)
    }

    func testExternalForegroundCancelsPendingAndFollowsNewIdentity() {
        let ws=WorkspaceStub(), observer=CycleObserver(), scheduler=CycleScheduler()
        ws.frontmost=ApplicationIdentity(processIdentifier:1,bundleIdentifier:ids[0])
        let controller=WorkspaceCycleController(workspace:ws,observer:observer,scheduler:scheduler,log:{_ in})
        controller.start();controller.resetToForeground();controller.cycle()
        ws.frontmost=ApplicationIdentity(processIdentifier:2,bundleIdentifier:ids[2])
        observer.change(ids[2]);controller.cycle()
        XCTAssertEqual(ws.launchRequests,[ids[1]])
        XCTAssertEqual(controller.displayMode,.home)
    }

    func testRejectedRunningActivationDoesNotSkipTarget() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: ids[0])
        ws.runningByBundleID[ids[1]] = ApplicationIdentity(processIdentifier: 2, bundleIdentifier: ids[1])
        var logs: [String] = []
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { logs.append($0) })
        controller.start(); controller.resetToForeground(); controller.cycle(); controller.cycle()
        XCTAssertEqual(logs.count, 2)
        XCTAssertTrue(ws.launchRequests.isEmpty)
        XCTAssertTrue(scheduler.tasks.allSatisfy(\.cancelled))
    }
}
