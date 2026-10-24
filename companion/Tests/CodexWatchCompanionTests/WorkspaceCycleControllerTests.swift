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
    func fire() { handler() } // Deliberately deliver even cancelled callbacks.
}

@MainActor
private final class CycleScheduler: WorkspaceModeScheduling {
    var tasks: [CycleTask] = []
    var monitors: [CycleTask] = []
    func scheduleRepeating(every interval: TimeInterval, _ handler: @MainActor @escaping () -> Void) -> WorkspaceModeScheduledTask {
        XCTAssertTrue(interval == 3 || interval == 1)
        let task = CycleTask(handler)
        if interval == 1 { monitors.append(task) } else { tasks.append(task) }
        return task
    }
}

@MainActor
final class WorkspaceCycleControllerTests: XCTestCase {
    func testSelectableCycleOmitsHermesAndReturnsHomeAfterSuper() {
        let ws=WorkspaceStub(), observer=CycleObserver(), scheduler=CycleScheduler()
        let controller=WorkspaceCycleController(workspace:ws,observer:observer,scheduler:scheduler,log:{_ in})
        controller.start()
        for expected: StopwatchWorkspaceMode in [.codexIdle,.deepseekIdle,.superIdle,.home,.codexIdle] {
            controller.cycle()
            XCTAssertEqual(controller.displayMode,expected)
        }
        XCTAssertTrue(ws.launchRequests.isEmpty)
        XCTAssertTrue(ws.activations.isEmpty)
    }

    private func fixture() -> (WorkspaceStub, CycleObserver, CycleScheduler, WorkspaceCycleController) {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start()
        return (ws, observer, scheduler, controller)
    }

    func testClosedDedicatedAgentWindowImmediatelyBlocksNavigationAndNextPollShowsOpen() {
        for profile in [WorkspaceAppProfile.deepseek, .super] {
            let (ws, _, scheduler, controller) = fixture()
            let target = ApplicationIdentity(processIdentifier: 92, bundleIdentifier: profile.bundleIdentifier)
            ws.runningByBundleID[target.bundleIdentifier] = target; ws.frontmost = target
            while controller.selectedProfile != profile { controller.cycle() }
            XCTAssertTrue(controller.allowsNavigation)
            // Closing the last window need not emit a new application activation.
            ws.presence = .none
            XCTAssertFalse(controller.allowsNavigation)
            scheduler.monitors.last?.fire()
            XCTAssertEqual(controller.displayMode, .waiting(profile))
            XCTAssertTrue(ws.launchRequests.isEmpty)
            controller.openSelectedWorkspace()
            XCTAssertEqual(ws.launchRequests, [profile.bundleIdentifier])
        }
    }

    func testDedicatedAgentUnknownWindowStateNeverEnablesNavigation() {
        for profile in [WorkspaceAppProfile.deepseek, .super] {
            let (ws, _, scheduler, controller) = fixture()
            ws.frontmost = ApplicationIdentity(processIdentifier: 93, bundleIdentifier: profile.bundleIdentifier)
            ws.presence = .unknown
            while controller.selectedProfile != profile { controller.cycle() }
            XCTAssertEqual(controller.displayMode, .waiting(profile))
            XCTAssertFalse(controller.allowsNavigation)
            ws.presence = .available; scheduler.monitors.last?.fire()
            XCTAssertTrue(controller.allowsNavigation)
        }
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

    func testCurrentSuperEngineeringBundleActivatesFromCodex() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        let current = ApplicationIdentity(
            processIdentifier: 2,
            bundleIdentifier: "engineering.super.app"
        )
        ws.runningByBundleID[current.bundleIdentifier] = current
        ws.activatable.insert(current)
        ws.frontmost = ApplicationIdentity(
            processIdentifier: 1,
            bundleIdentifier: "com.openai.codex"
        )
        let controller = WorkspaceCycleController(
            workspace: ws,
            observer: observer,
            scheduler: scheduler,
            log: { _ in }
        )
        controller.start()
        controller.resetToForeground()
        while controller.selectedProfile != .super { controller.cycle() }
        XCTAssertTrue(ws.launchRequests.isEmpty)
        XCTAssertTrue(ws.activations.isEmpty)
        controller.openSelectedWorkspace()

        XCTAssertEqual(ws.launchRequests, [current.bundleIdentifier])
        XCTAssertTrue(ws.activations.isEmpty)
        ws.frontmost = current
        observer.change(current.bundleIdentifier)
        XCTAssertEqual(controller.displayMode, .super)
        XCTAssertEqual(controller.selectedProfile, .super)
    }

    func testLegacySuperEngineeringBundleRemainsActivatableFromCodex() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        let legacy = ApplicationIdentity(
            processIdentifier: 2,
            bundleIdentifier: "com.zarifpour.superconductor"
        )
        ws.runningByBundleID[legacy.bundleIdentifier] = legacy
        ws.activatable.insert(legacy)
        ws.frontmost = ApplicationIdentity(
            processIdentifier: 1,
            bundleIdentifier: "com.openai.codex"
        )
        let controller = WorkspaceCycleController(
            workspace: ws,
            observer: observer,
            scheduler: scheduler,
            log: { _ in }
        )
        controller.start()
        controller.resetToForeground()
        while controller.selectedProfile != .super { controller.cycle() }
        XCTAssertTrue(ws.launchRequests.isEmpty)
        XCTAssertTrue(ws.activations.isEmpty)
        controller.openSelectedWorkspace()

        XCTAssertEqual(ws.launchRequests, [legacy.bundleIdentifier])
        XCTAssertTrue(ws.activations.isEmpty)
        ws.frontmost = legacy
        observer.change(legacy.bundleIdentifier)
        XCTAssertEqual(controller.displayMode, .super)
        XCTAssertEqual(controller.selectedProfile, .super)
    }

    func testCurrentSuperEngineeringTakesPriorityWhenBothVersionsRun() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        let current = ApplicationIdentity(processIdentifier: 2, bundleIdentifier: "engineering.super.app")
        let legacy = ApplicationIdentity(processIdentifier: 3, bundleIdentifier: "com.zarifpour.superconductor")
        ws.runningByBundleID[current.bundleIdentifier] = current
        ws.runningByBundleID[legacy.bundleIdentifier] = legacy
        ws.activatable.formUnion([current, legacy])
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: "com.openai.codex")
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start()
        controller.resetToForeground()
        while controller.selectedProfile != .super { controller.cycle() }
        XCTAssertTrue(ws.launchRequests.isEmpty)
        XCTAssertTrue(ws.activations.isEmpty)
        controller.openSelectedWorkspace()

        XCTAssertEqual(ws.launchRequests, [current.bundleIdentifier])
    }

    func testMissingSuperEngineeringLaunchesCurrentBundleID() {
        let ws = WorkspaceStub(), observer = CycleObserver(), scheduler = CycleScheduler()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: "com.openai.codex")
        let controller = WorkspaceCycleController(workspace: ws, observer: observer, scheduler: scheduler, log: { _ in })
        controller.start()
        controller.resetToForeground()
        while controller.selectedProfile != .super { controller.cycle() }
        XCTAssertTrue(ws.launchRequests.isEmpty)
        XCTAssertTrue(ws.activations.isEmpty)
        controller.openSelectedWorkspace()

        XCTAssertEqual(ws.launchRequests, ["engineering.super.app"])
        let launched = ApplicationIdentity(processIdentifier: 2, bundleIdentifier: "engineering.super.app")
        ws.frontmost = launched
        observer.change(launched.bundleIdentifier)
        XCTAssertEqual(controller.displayMode, .super)
    }

    func testCenterRestoresEveryWindowlessRunningAgentBeforeEnablingNavigation() {
        for (index, profile) in WorkspaceAppProfile.selectableDesktops.enumerated() {
            let (ws, observer, scheduler, controller) = fixture()
            let target = ApplicationIdentity(processIdentifier: 90, bundleIdentifier: profile.bundleIdentifier)
            ws.runningByBundleID[target.bundleIdentifier] = target; ws.activatable.insert(target)
            ws.presence = .none; ws.windowFocusSucceeds = false
            ws.frontmost = ApplicationIdentity(processIdentifier: 91, bundleIdentifier: "com.apple.finder")
            // Model the macOS distinction: activating an existing process does
            // not recreate its closed window; opening the app requests reopen.
            ws.onOpen = { bundle in
                XCTAssertEqual(bundle, target.bundleIdentifier)
                ws.presence = .available; ws.windowFocusSucceeds = true
                ws.frontmost = target; ws.launchCompletion?(true)
                observer.change(bundle)
            }
            for _ in 0...index { controller.cycle() }
            XCTAssertEqual(controller.displayMode, .waiting(profile))
            XCTAssertTrue(ws.launchRequests.isEmpty)
            controller.openSelectedWorkspace()
            scheduler.monitors.last?.fire()
            XCTAssertEqual(controller.displayMode, .foreground(target.bundleIdentifier))
            XCTAssertTrue(controller.allowsNavigation)
            XCTAssertEqual(ws.launchRequests.count, 1)
            XCTAssertTrue(ws.activations.isEmpty)
        }
    }

    func testEveryBackgroundSelectionWaitsForCenterWithoutStealingForeground() {
        for (index, profile) in WorkspaceAppProfile.selectableDesktops.enumerated() {
            let (ws, observer, _, controller) = fixture()
            let target = ApplicationIdentity(processIdentifier: 71, bundleIdentifier: profile.bundleIdentifier)
            let other = ApplicationIdentity(processIdentifier: 72, bundleIdentifier: "com.apple.finder")
            ws.runningByBundleID[target.bundleIdentifier] = target
            ws.activatable.insert(target); ws.frontmost = other
            for _ in 0...index { controller.cycle() }
            XCTAssertEqual(controller.displayMode, .waiting(profile))
            XCTAssertFalse(controller.allowsNavigation)
            XCTAssertTrue(ws.activations.isEmpty)
            XCTAssertTrue(ws.launchRequests.isEmpty)
            controller.openSelectedWorkspace(); controller.openSelectedWorkspace()
            XCTAssertEqual(ws.launchRequests, [target.bundleIdentifier])
            XCTAssertTrue(ws.activations.isEmpty)
            XCTAssertEqual(controller.displayMode, .waiting(profile, state: "opening"))
            ws.frontmost = target; observer.change(target.bundleIdentifier)
            XCTAssertEqual(controller.displayMode, .foreground(target.bundleIdentifier))
            XCTAssertTrue(controller.allowsNavigation)
            XCTAssertEqual(ws.launchRequests.count, 1)
        }
    }

    func testEveryForegroundSelectionIsReadyWithoutLaunchOrActivation() {
        for (index, profile) in WorkspaceAppProfile.selectableDesktops.enumerated() {
            let (ws, _, _, controller) = fixture()
            let target = ApplicationIdentity(processIdentifier: 73, bundleIdentifier: profile.bundleIdentifier)
            ws.runningByBundleID[target.bundleIdentifier] = target; ws.frontmost = target
            for _ in 0...index { controller.cycle() }
            XCTAssertEqual(controller.displayMode, .foreground(target.bundleIdentifier))
            XCTAssertTrue(controller.allowsNavigation)
            XCTAssertTrue(ws.activations.isEmpty); XCTAssertTrue(ws.launchRequests.isEmpty)
        }
    }

    func testEverySelectedPageSurvivesForegroundLossAndCenterRestoresIt() {
        for (index, profile) in WorkspaceAppProfile.selectableDesktops.enumerated() {
            let (ws, observer, _, controller) = fixture()
            let target = ApplicationIdentity(processIdentifier: 74, bundleIdentifier: profile.bundleIdentifier)
            ws.runningByBundleID[target.bundleIdentifier] = target; ws.frontmost = target
            ws.activatable.insert(target)
            for _ in 0...index { controller.cycle() }
            ws.frontmost = ApplicationIdentity(processIdentifier: 75, bundleIdentifier: WorkspaceAppProfile.selectableDesktops[(index + 1) % 3].bundleIdentifier)
            observer.change(ws.frontmost?.bundleIdentifier)
            XCTAssertEqual(controller.selectedProfile, profile)
            XCTAssertEqual(controller.displayMode, .waiting(profile))
            XCTAssertFalse(controller.allowsNavigation)
            controller.openSelectedWorkspace()
            XCTAssertEqual(ws.launchRequests, [target.bundleIdentifier])
            XCTAssertTrue(ws.activations.isEmpty)
            ws.frontmost = target; observer.change(target.bundleIdentifier)
            XCTAssertTrue(controller.allowsNavigation)
        }
    }



    func testForegroundRaceRejectsNavigationBeforeNotificationThenCenterRestoresSelection() {
        for (index, profile) in WorkspaceAppProfile.selectableDesktops.enumerated() {
            let (ws, _, _, controller) = fixture()
            let target = ApplicationIdentity(processIdentifier: 81, bundleIdentifier: profile.bundleIdentifier)
            ws.runningByBundleID[target.bundleIdentifier] = target; ws.frontmost = target; ws.activatable.insert(target)
            for _ in 0...index { controller.cycle() }
            ws.frontmost = ApplicationIdentity(processIdentifier: 82, bundleIdentifier: "com.apple.finder")
            XCTAssertFalse(controller.allowsNavigation)
            controller.openSelectedWorkspace()
            XCTAssertEqual(ws.launchRequests, [target.bundleIdentifier])
            XCTAssertTrue(ws.activations.isEmpty)
            XCTAssertEqual(controller.selectedProfile, profile)
        }
    }

    func testPollingDetectsQuitAndCenterColdLaunchesOnlySelectedAgent() {
        for (index, profile) in WorkspaceAppProfile.selectableDesktops.enumerated() {
            let (ws, _, scheduler, controller) = fixture()
            let target = ApplicationIdentity(processIdentifier: 83, bundleIdentifier: profile.bundleIdentifier)
            ws.runningByBundleID[target.bundleIdentifier] = target; ws.frontmost = target
            for _ in 0...index { controller.cycle() }
            ws.runningByBundleID.removeAll(); ws.frontmost = nil
            scheduler.monitors.last?.fire()
            XCTAssertEqual(controller.displayMode, .waiting(profile))
            XCTAssertFalse(controller.allowsNavigation)
            controller.openSelectedWorkspace()
            XCTAssertEqual(ws.launchRequests, [profile.bundleIdentifier])
        }
    }

    func testAllAbsentAppsCycleWithoutAnyLaunchAndIgnoreUnrelatedForeground() {
        let (ws, observer, scheduler, controller) = fixture()
        for profile in WorkspaceAppProfile.selectableDesktops {
            controller.cycle()
            XCTAssertEqual(controller.displayMode, .waiting(profile))
            XCTAssertEqual(controller.selectedProfile, profile)
            XCTAssertFalse(controller.allowsNavigation)
            ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: "com.apple.finder")
            observer.change(ws.frontmost?.bundleIdentifier)
            XCTAssertEqual(controller.displayMode, .waiting(profile))
        }
        controller.cycle()
        XCTAssertEqual(controller.displayMode, .home)
        XCTAssertNil(controller.selectedProfile)
        XCTAssertTrue(ws.launchRequests.isEmpty)
        XCTAssertTrue(ws.activations.isEmpty)
        XCTAssertTrue(scheduler.tasks.isEmpty)
    }

    func testEveryCentralLaunchRequiresRealForegroundNotSubmissionOrNotificationAlone() {
        for (index, profile) in WorkspaceAppProfile.selectableDesktops.enumerated() {
            let (ws, observer, _, controller) = fixture()
            for _ in 0...index { controller.cycle() }
            controller.openSelectedWorkspace(); controller.openSelectedWorkspace()
            XCTAssertEqual(ws.launchRequests, [profile.bundleIdentifier])
            XCTAssertEqual(controller.displayMode, .waiting(profile, state: "opening"))
            ws.launchCompletion?(true)
            observer.change(profile.bundleIdentifier)
            XCTAssertFalse(controller.allowsNavigation)
            ws.frontmost = ApplicationIdentity(processIdentifier: 0, bundleIdentifier: profile.bundleIdentifier)
            observer.change(profile.bundleIdentifier)
            XCTAssertFalse(controller.allowsNavigation)
            ws.frontmost = ApplicationIdentity(processIdentifier: 20, bundleIdentifier: profile.bundleIdentifier)
            observer.change(profile.bundleIdentifier)
            XCTAssertEqual(controller.displayMode, .foreground(profile.bundleIdentifier))
            XCTAssertTrue(controller.allowsNavigation)
            controller.openSelectedWorkspace(); controller.openHermes()
            XCTAssertEqual(ws.launchRequests.count, 1)
        }
    }

    func testEveryCentralFailureAndTimeoutNeedsExplicitRetry() {
        for (index, profile) in WorkspaceAppProfile.selectableDesktops.enumerated() {
            let (ws, _, scheduler, controller) = fixture()
            for _ in 0...index { controller.cycle() }
            controller.openSelectedWorkspace()
            ws.launchCompletion?(false)
            XCTAssertEqual(controller.displayMode, .waiting(profile, state: "error"))
            XCTAssertFalse(controller.allowsNavigation)
            controller.openSelectedWorkspace()
            let stale = ws.launchCompletion
            scheduler.tasks.last?.fire()
            XCTAssertEqual(controller.displayMode, .waiting(profile, state: "error"))
            stale?(true)
            XCTAssertEqual(controller.displayMode, .waiting(profile, state: "error"))
            controller.openSelectedWorkspace()
            stale?(false)
            scheduler.tasks[0].fire()
            XCTAssertEqual(controller.displayMode, .waiting(profile, state: "opening"))
            XCTAssertEqual(ws.launchRequests.count, 3)
        }
    }

    func testEveryOpeningCanCycleAndHomeWithoutStaleCallbacksRestoringIt() {
        for index in 0..<4 {
            let (ws, observer, scheduler, controller) = fixture()
            for _ in 0...index { controller.cycle() }
            controller.openSelectedWorkspace()
            let completion = ws.launchCompletion, task = scheduler.tasks[0]
            controller.cycle()
            let expected = controller.displayMode
            completion?(false); task.fire()
            ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: WorkspaceAppProfile.selectableDesktops[index].bundleIdentifier)
            observer.change(ws.frontmost?.bundleIdentifier)
            XCTAssertEqual(controller.displayMode, expected)
            controller.showHome(); completion?(true); task.fire()
            XCTAssertEqual(controller.displayMode, .home)
            XCTAssertTrue(task.cancelled)
        }
    }

    func testRunningAppsReopenSingleInstanceAndRequireSamePIDAndLaunchDate() {
        for (index, profile) in WorkspaceAppProfile.selectableDesktops.enumerated() {
            let (ws, observer, _, controller) = fixture()
            let target = ApplicationIdentity(processIdentifier: 7, bundleIdentifier: profile.bundleIdentifier, launchDate: Date(timeIntervalSince1970: 1))
            ws.runningByBundleID[target.bundleIdentifier] = target
            ws.activatable.insert(target)
            for _ in 0...index { controller.cycle() }
            controller.openSelectedWorkspace()
            XCTAssertEqual(ws.launchRequests, [target.bundleIdentifier])
            XCTAssertTrue(ws.activations.isEmpty)
            XCTAssertEqual(controller.displayMode, .waiting(profile, state: "opening"))
            for wrong in [ApplicationIdentity(processIdentifier: 8, bundleIdentifier: target.bundleIdentifier), ApplicationIdentity(processIdentifier: 7, bundleIdentifier: target.bundleIdentifier, launchDate: Date(timeIntervalSince1970: 2))] {
                ws.frontmost = wrong; observer.change(target.bundleIdentifier)
                XCTAssertFalse(controller.allowsNavigation)
            }
            ws.frontmost = target; observer.change(target.bundleIdentifier)
            XCTAssertTrue(controller.allowsNavigation)
        }
    }

    func testRejectedRunningActivationStaysSelectedErrorAndCenterReopens() {
        let (ws, _, _, controller) = fixture()
        let target = ApplicationIdentity(processIdentifier: 2, bundleIdentifier: WorkspaceAppProfile.codex.bundleIdentifier)
        ws.runningByBundleID[target.bundleIdentifier] = target
        controller.cycle()
        XCTAssertEqual(controller.displayMode, .codexIdle)
        controller.openSelectedWorkspace()
        ws.launchCompletion?(false)
        XCTAssertEqual(controller.displayMode, .codexError)
        XCTAssertEqual(ws.launchRequests.count, 1)
        ws.activatable.insert(target)
        controller.openSelectedWorkspace()
        XCTAssertEqual(ws.launchRequests.count, 2)
        XCTAssertEqual(controller.displayMode, .codexOpening)
    }

    func testLegacySuperActivatesAndReopensExactRunningBundle() {
        let (ws, observer, scheduler, controller) = fixture()
        let target = ApplicationIdentity(processIdentifier: 8, bundleIdentifier: "com.zarifpour.superconductor")
        ws.runningByBundleID[target.bundleIdentifier] = target
        ws.activatable.insert(target)
        controller.cycle(); controller.cycle(); controller.cycle()
        controller.openSelectedWorkspace()
        XCTAssertEqual(ws.launchRequests, [target.bundleIdentifier])
        scheduler.tasks[0].fire()
        ws.presence = .none
        controller.openSelectedWorkspace()
        XCTAssertEqual(ws.launchRequests, [target.bundleIdentifier, target.bundleIdentifier])
        ws.presence = .available
        ws.frontmost = target; observer.change(target.bundleIdentifier)
        XCTAssertEqual(controller.displayMode, .super)
    }



    func testLegacyHermesActionCannotLaunchOtherSelections() {
        let (ws, _, _, controller) = fixture()
        for _ in 0..<3 { controller.cycle(); controller.openHermes() }
        XCTAssertTrue(ws.launchRequests.isEmpty)
    }

    func testStopRestartInvalidatesObserverCompletionAndTimer() {
        let (ws, observer, scheduler, controller) = fixture()
        controller.cycle(); controller.openSelectedWorkspace()
        let callback = ws.launchCompletion, oldObserver = observer.handler
        controller.stop(); controller.start(); controller.cycle(); controller.openSelectedWorkspace()
        callback?(false); oldObserver?(WorkspaceAppProfile.codex.bundleIdentifier); scheduler.tasks[0].fire()
        XCTAssertEqual(controller.displayMode, .codexOpening)
        controller.stop(); controller.cycle(); controller.openSelectedWorkspace()
        XCTAssertEqual(controller.displayMode, .home)
        XCTAssertEqual(ws.launchRequests.count, 2)
    }

    func testActiveSelectionBecomesIdleWhenAnotherAgentGainsForeground() {
        let (ws, observer, _, controller) = fixture()
        ws.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: WorkspaceAppProfile.codex.bundleIdentifier)
        controller.resetToForeground()
        ws.frontmost = ApplicationIdentity(processIdentifier: 2, bundleIdentifier: WorkspaceAppProfile.deepseek.bundleIdentifier)
        observer.change(ws.frontmost?.bundleIdentifier)
        XCTAssertEqual(controller.displayMode, .codexIdle)
        XCTAssertFalse(controller.allowsNavigation)
        controller.showHome(); observer.change(ws.frontmost?.bundleIdentifier)
        XCTAssertEqual(controller.displayMode, .home)
    }

    func testSuperWithNormalWindowPreservesSelectionOnForegroundLoss() {
        let (ws, observer, scheduler, controller) = fixture()
        let target = ApplicationIdentity(processIdentifier: 49, bundleIdentifier: WorkspaceAppProfile.super.bundleIdentifier)
        ws.runningByBundleID[target.bundleIdentifier] = target; ws.activatable.insert(target); ws.frontmost = target
        controller.cycle(); controller.cycle(); controller.cycle()
        XCTAssertEqual(controller.displayMode, .super)
        let monitor = scheduler.monitors.last!
        ws.frontmost = ApplicationIdentity(processIdentifier: 50, bundleIdentifier: WorkspaceAppProfile.deepseek.bundleIdentifier)
        observer.change(ws.frontmost?.bundleIdentifier)
        XCTAssertEqual(controller.displayMode, .superIdle)
        XCTAssertFalse(monitor.cancelled)
        XCTAssertTrue(ws.launchRequests.isEmpty)
    }

    func testSuperClosedWindowSelectsIdleAndReopensOnlyOnCenter() {
        for bundle in WorkspaceAppProfile.super.acceptedBundleIdentifiers {
            let (ws, observer, scheduler, controller) = fixture()
            let target = ApplicationIdentity(processIdentifier: 41, bundleIdentifier: bundle)
            ws.runningByBundleID[bundle] = target; ws.activatable.insert(target); ws.presence = .none
            controller.cycle(); controller.cycle(); controller.cycle()
            XCTAssertEqual(controller.displayMode, .superIdle)
            XCTAssertTrue(ws.activations.isEmpty); XCTAssertTrue(ws.launchRequests.isEmpty)
            controller.openSelectedWorkspace(); controller.openSelectedWorkspace()
            XCTAssertEqual(ws.launchRequests, [bundle]); XCTAssertEqual(controller.displayMode, .superOpening)
            ws.frontmost = target; observer.change(bundle); ws.launchCompletion?(true)
            XCTAssertEqual(controller.displayMode, .superOpening)
            ws.presence = .available; scheduler.monitors.last?.fire()
            XCTAssertEqual(controller.displayMode, .super)
            controller.openSelectedWorkspace(); XCTAssertEqual(ws.launchRequests.count, 1)
        }
    }

    func testSuperActiveCloseWritesIdleEvenWhenAnotherAppBecameForeground() {
        let (ws, observer, scheduler, controller) = fixture()
        let target = ApplicationIdentity(processIdentifier: 42, bundleIdentifier: WorkspaceAppProfile.super.bundleIdentifier)
        ws.runningByBundleID[target.bundleIdentifier] = target; ws.activatable.insert(target); ws.frontmost = target
        controller.cycle(); controller.cycle(); controller.cycle()
        XCTAssertEqual(controller.displayMode, .super)
        var modes: [StopwatchWorkspaceMode] = []; controller.modeDidChange = { modes.append($0) }
        ws.presence = .none
        ws.frontmost = ApplicationIdentity(processIdentifier: 3, bundleIdentifier: "com.apple.finder")
        observer.change(ws.frontmost?.bundleIdentifier)
        XCTAssertEqual(controller.displayMode, .superIdle); XCTAssertEqual(modes, [.superIdle])
        scheduler.monitors.last?.fire(); XCTAssertEqual(modes, [.superIdle])
        XCTAssertTrue(ws.launchRequests.isEmpty)
        controller.openSelectedWorkspace(); XCTAssertEqual(ws.launchRequests.count, 1)
    }

    func testSuperUnknownWindowBlocksNavigationUntilExplicitOpenIsReady() {
        let (ws, observer, scheduler, controller) = fixture()
        let target = ApplicationIdentity(processIdentifier: 43, bundleIdentifier: WorkspaceAppProfile.super.bundleIdentifier)
        ws.runningByBundleID[target.bundleIdentifier] = target; ws.activatable.insert(target); ws.frontmost = target
        controller.cycle(); controller.cycle(); controller.cycle()
        XCTAssertEqual(controller.displayMode, .super)
        ws.presence = .unknown; scheduler.monitors.last?.fire()
        XCTAssertEqual(controller.displayMode, .superIdle)
        XCTAssertFalse(controller.allowsNavigation)
        ws.frontmost = ApplicationIdentity(processIdentifier: 5, bundleIdentifier: "com.apple.finder")
        observer.change(ws.frontmost?.bundleIdentifier)
        controller.openSelectedWorkspace()
        XCTAssertTrue(ws.activations.isEmpty)
        XCTAssertEqual(ws.launchRequests, [target.bundleIdentifier])
        ws.frontmost = target; ws.presence = .available
        scheduler.monitors.last?.fire()
        XCTAssertEqual(controller.displayMode, .super)
        controller.openSelectedWorkspace()
        XCTAssertEqual(ws.launchRequests.count, 1)
    }

    func testSuperMonitoringStopsAndStaleTimerCannotChangeNewSelection() {
        let (ws, _, scheduler, controller) = fixture()
        let target = ApplicationIdentity(processIdentifier: 44, bundleIdentifier: WorkspaceAppProfile.super.bundleIdentifier)
        ws.runningByBundleID[target.bundleIdentifier] = target; ws.activatable.insert(target); ws.frontmost = target
        controller.cycle(); controller.cycle(); controller.cycle()
        let old = scheduler.monitors.last!
        controller.cycle(); ws.presence = .none; old.fire()
        XCTAssertTrue(old.cancelled); XCTAssertEqual(controller.displayMode, .home)
        controller.showHome(); controller.cycle(); controller.cycle(); controller.cycle()
        let current = scheduler.monitors.last!
        controller.stop(); current.fire(); old.fire()
        XCTAssertTrue(current.cancelled); XCTAssertEqual(controller.displayMode, .home)
    }

    func testSuperReopenRejectsReusedPIDAndForegroundWithoutReadyWindow() {
        let (ws, observer, scheduler, controller) = fixture()
        let target = ApplicationIdentity(processIdentifier: 46, bundleIdentifier: WorkspaceAppProfile.super.bundleIdentifier, launchDate: Date(timeIntervalSince1970: 1))
        ws.runningByBundleID[target.bundleIdentifier] = target; ws.presence = .none
        controller.cycle(); controller.cycle(); controller.cycle(); controller.openSelectedWorkspace()
        ws.presence = .available
        ws.frontmost = ApplicationIdentity(processIdentifier: 46, bundleIdentifier: target.bundleIdentifier, launchDate: Date(timeIntervalSince1970: 2))
        observer.change(target.bundleIdentifier); scheduler.monitors.last?.fire()
        XCTAssertEqual(controller.displayMode, .superOpening)
        ws.frontmost = target; ws.presence = .unknown
        observer.change(target.bundleIdentifier); XCTAssertEqual(controller.displayMode, .superOpening)
        ws.presence = .available; scheduler.monitors.last?.fire()
        XCTAssertEqual(controller.displayMode, .super)
    }

    func testSuperUnknownAtSelectionTimesOutAndRetriesOnlyOnCenter() {
        let (ws, _, scheduler, controller) = fixture()
        let target = ApplicationIdentity(processIdentifier: 45, bundleIdentifier: WorkspaceAppProfile.super.bundleIdentifier)
        ws.runningByBundleID[target.bundleIdentifier] = target; ws.activatable.insert(target); ws.frontmost = target; ws.presence = .unknown
        controller.cycle(); controller.cycle(); controller.cycle()
        XCTAssertEqual(controller.displayMode, .superIdle)
        XCTAssertTrue(scheduler.tasks.isEmpty)
        controller.openSelectedWorkspace()
        XCTAssertEqual(controller.displayMode, .superOpening)
        scheduler.tasks.last?.fire(); XCTAssertEqual(controller.displayMode, .superError)
        for _ in 0..<4 { controller.openSelectedWorkspace(); scheduler.tasks.last?.fire() }
        XCTAssertEqual(ws.launchRequests.count, 5)
        XCTAssertFalse(controller.allowsNavigation)
    }

    func testProfileRejectsLookalikesAndPreservesNavigationMappings() {
        for bundle in ["com.deepseek.dsh.helper", "com.deepseek", "COM.DEEPSEEK.DSH", "com.apple.Safari"] {
            XCTAssertNil(WorkspaceAppProfile(bundleIdentifier: bundle))
        }
        XCTAssertEqual(WorkspaceAppProfile.deepseek.command(for: .up), .previousDeepseekThread)
        XCTAssertEqual(WorkspaceAppProfile.deepseek.command(for: .down), .nextDeepseekThread)
        XCTAssertEqual(WorkspaceAppProfile.deepseek.command(for: .right), .toggleDeepseekView)
        XCTAssertNil(WorkspaceAppProfile.codex.command(for: .openSelectedWorkspace))
    }
}
