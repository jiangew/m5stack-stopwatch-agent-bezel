import Foundation

@MainActor private final class Observer: ForegroundApplicationObserving {
    var frontmostBundleIdentifier: String?
    var handler: (@MainActor (String?) -> Void)?
    func start(_ handler: @MainActor @escaping (String?) -> Void) { self.handler=handler }
    func stop() { handler=nil }
}
@MainActor private final class Scheduled: WorkspaceModeScheduledTask {
    let action: @MainActor () -> Void
    var cancelled=false
    init(_ action: @MainActor @escaping () -> Void) { self.action=action }
    func cancel() { cancelled=true }
}
@MainActor private final class Scheduler: WorkspaceModeScheduling {
    var tasks=[Scheduled]()
    func scheduleRepeating(every interval: TimeInterval, _ handler: @MainActor @escaping () -> Void) -> WorkspaceModeScheduledTask {
        let task=Scheduled(handler); tasks.append(task); return task
    }
}
@MainActor private final class Applications: WorkspaceApplications {
    var frontmost: ApplicationIdentity?
    var launches=[String]()
    var presence=ApplicationWindowPresence.available
    var presenceReads=0
    func runningApplication(bundleIdentifier: String) -> ApplicationIdentity? { nil }
    func activate(_ identity: ApplicationIdentity) -> Bool { fatalError("cycle must not activate") }
    func focusWindow(_ identity: ApplicationIdentity) -> Bool { fatalError("cycle must not focus") }
    func windowPresence(_ identity: ApplicationIdentity) -> ApplicationWindowPresence { presenceReads+=1; return presence }
    func launchAndActivate(bundleIdentifier: String, completion: @MainActor @escaping (Bool) -> Void) { launches.append(bundleIdentifier) }
}
@MainActor private final class Sender: WorkspaceModeSending {
    let deviceKey: UInt=1
    var modes=[StopwatchWorkspaceMode]()
    func send(_ mode: StopwatchWorkspaceMode) -> Bool { modes.append(mode);return true }
}

@main private enum Regression {
    @MainActor static func main() {
        var decoder=HIDShortcutDecoder()
        func send(_ line: String,_ time: Double) -> [CompanionShortcutEvent] {
            WorkspaceModeHIDReportFramer.reports(payloadBytes:Array((line+"\n").utf8)).flatMap {
                decoder.consume(reportID:6,bytes:$0,now:time)
            }
        }
        var accepted=0
        for (i,origin) in ["home","codex","deepseek","super"].enumerated() {
            let time=1.0+Double(i)*0.25
            let press = origin == "codex" ? #"{"method":"v.oai.rad","params":{"a":0.5,"d":1}}"# :
                "{\"method\":\"host.workspace_navigation\",\"params\":{\"workspace\":\"\(origin)\",\"direction\":\"left\",\"phase\":\"press\"}}"
            let expected: CompanionShortcutEvent = origin == "codex" ? .left : .navigation(WorkspaceNavigationOrigin(rawValue:origin)!,.left)
            let events=send(press,time)
            precondition(events == [expected],"released left at 250ms must be accepted: \(origin)")
            accepted+=events.count
            precondition(send(press,time+0.01).isEmpty,"held press must not repeat")
            let release = origin == "codex" ? press.replacingOccurrences(of:"\"d\":1",with:"\"d\":0") : press.replacingOccurrences(of:"press",with:"release")
            precondition(send(release,time+0.05).isEmpty)
        }
        precondition(accepted==4)
        let nativePress = #"{"method":"v.oai.rad","params":{"a":0.5,"d":1}}"#
        precondition(send(nativePress,1.85).isEmpty,"sub-200ms press must be blocked")
        precondition(send(nativePress,2.5).isEmpty,"rejected press still requires release")
        _=send(nativePress.replacingOccurrences(of:"\"d\":1",with:"\"d\":0"),2.6)
        precondition(send(nativePress,2.7)==[.left])
        decoder.reset()
        let right = #"{"method":"v.oai.rad","params":{"a":0,"d":1}}"#
        precondition(send(right,3)==[.right])
        _=send(right.replacingOccurrences(of:"\"d\":1",with:"\"d\":0"),3.05)
        precondition(send(nativePress,3.25).isEmpty,"non-page 800ms guard must remain")
        let apps=Applications(), observer=Observer(), scheduler=Scheduler()
        let cycle=WorkspaceCycleController(workspace:apps,observer:observer,scheduler:scheduler,log:{_ in})
        cycle.start()
        for mode: StopwatchWorkspaceMode in [.codexIdle,.deepseekIdle,.superIdle,.home,.codexIdle] {
            cycle.cycle(); precondition(cycle.displayMode == mode,"cycle must omit Hermes")
        }
        precondition(apps.launches.isEmpty)
        cycle.showHome()
        apps.frontmost=ApplicationIdentity(processIdentifier:12,bundleIdentifier:"com.nousresearch.hermes")
        observer.handler?(apps.frontmost?.bundleIdentifier)
        precondition(cycle.displayMode == .home)
        cycle.cycle()
        precondition(cycle.displayMode == .codexIdle)
        cycle.openSelectedWorkspace()
        precondition(apps.launches == ["com.openai.codex"])
        cycle.stop()
        for task in scheduler.tasks { task.action() }
        precondition(cycle.displayMode == .home,"late timer must not revive a desktop")
        let sharedApps=Applications(), sharedObserver=Observer(), sharedScheduler=Scheduler()
        let shared=WorkspaceCycleController(workspace:sharedApps,observer:sharedObserver,scheduler:sharedScheduler,log:{_ in})
        let coordinator=WorkspaceModeCoordinator(foregroundObserver:Observer(),scheduler:sharedScheduler,
            uptime:{0},log:{_ in},interaction:shared)
        let sender=Sender()
        shared.start();coordinator.start();coordinator.attach(sender)
        precondition(sender.modes.last == .home)
        for mode: StopwatchWorkspaceMode in [.codexIdle,.deepseekIdle,.superIdle,.home] {
            shared.cycle();precondition(sender.modes.last == mode)
        }
        for task in sharedScheduler.tasks { task.action() }
        precondition(sender.modes.last == .home && sharedApps.launches.isEmpty)
        shared.stop();coordinator.stop()
        print("PASS released 250ms page swipes, 200ms/release/non-page guards, four-page cycle and mode coordinator, Hermes foreground isolation, explicit launch and stale timer")
    }
}
