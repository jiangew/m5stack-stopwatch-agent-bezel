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
    private let ids = ["com.openai.codex", "com.zarifpour.superconductor", "com.nousresearch.hermes"]

    func testSelectingHermesDoesNotLaunchOrActivate() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: ids[1])
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start(); controller.cycle()
        XCTAssertTrue(ws.launchRequests.isEmpty)
        XCTAssertTrue(ws.activations.isEmpty)
        XCTAssertTrue(scheduler.tasks.isEmpty)
    }

    func testFullCycleUsesActualForegroundAndNeverPreviousApp() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start()
        for id in ids {
            let identity = ApplicationIdentity(processIdentifier: pid_t(ws.runningByBundleID.count + 1), bundleIdentifier: id)
            ws.runningByBundleID[id] = identity; ws.activatable.insert(identity)
        }
        for (source, destination) in [(ids[0], ids[1]), (ids[1], ids[2]), (ids[2], ids[0])] {
            ws.frontmost = ws.runningByBundleID[source]
            controller.cycle()
            if source == ids[1] { controller.openHermes() }
            XCTAssertEqual(ws.activations.last?.bundleIdentifier, destination)
            ws.frontmost = ws.runningByBundleID[destination]
            observer.change(destination)
        }
        XCTAssertEqual(ws.activations.map(\.bundleIdentifier), [ids[1], ids[2], ids[0]])
        XCTAssertEqual(scheduler.intervals, [3, 3, 3])
        XCTAssertTrue(scheduler.tasks.allSatisfy(\.cancelled))
    }

    func testHermesTapTimeoutRequiresExplicitRetryAndIgnoresLateCompletion() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: ids[1])
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start(); controller.cycle()
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
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: ids[1])
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start(); controller.cycle(); controller.openHermes()
        let completion = ws.launchCompletion
        controller.cycle()
        XCTAssertEqual(ws.launchRequests, [ids[2], ids[0]])
        completion?(false)
        XCTAssertFalse(controller.displayMode.awaitingHermes)
        observer.change(ids[1]); controller.cycle()
        XCTAssertEqual(controller.displayMode, .hermesIdle)
        observer.change(ids[1])
        XCTAssertEqual(controller.displayMode, .super)
        controller.cycle(); controller.resetToForeground()
        XCTAssertEqual(controller.displayMode, .super)
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
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: ids[0])
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start(); controller.cycle()
        ws.frontmost = ApplicationIdentity(processIdentifier: 2, bundleIdentifier: ids[2])
        observer.change(ids[2]); controller.cycle()
        XCTAssertEqual(ws.launchRequests, [ids[1], ids[0]])
    }

    func testRejectedRunningActivationDoesNotSkipTarget() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: ids[0])
        ws.runningByBundleID[ids[1]] = ApplicationIdentity(processIdentifier: 2, bundleIdentifier: ids[1])
        var logs: [String] = []
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { logs.append($0) })
        controller.start(); controller.cycle(); controller.cycle()
        XCTAssertEqual(logs.count, 2)
        XCTAssertTrue(ws.launchRequests.isEmpty)
        XCTAssertTrue(scheduler.tasks.allSatisfy(\.cancelled))
    }
}
