import CoreGraphics
import Foundation

@MainActor
private final class WorkspaceFake: WorkspaceApplications {
    var frontmost: ApplicationIdentity?
    var running: [String: ApplicationIdentity] = [:]
    var activations: [ApplicationIdentity] = []
    var launchRequests: [String] = []

    func runningApplication(bundleIdentifier: String) -> ApplicationIdentity? {
        running[bundleIdentifier]
    }

    func activate(_ identity: ApplicationIdentity) -> Bool {
        activations.append(identity)
        return true
    }

    func focusWindow(_ identity: ApplicationIdentity) -> Bool { true }

    func launchAndActivate(bundleIdentifier: String, completion: @MainActor @escaping (Bool) -> Void) {
        launchRequests.append(bundleIdentifier)
    }
}

@MainActor
private final class ForegroundFake: ForegroundApplicationObserving {
    var frontmostBundleIdentifier: String?
    private var handler: (@MainActor (String?) -> Void)?

    func start(_ handler: @MainActor @escaping (String?) -> Void) { self.handler = handler }
    func stop() { handler = nil }
    func change(to bundleIdentifier: String) {
        frontmostBundleIdentifier = bundleIdentifier
        handler?(bundleIdentifier)
    }
}

@MainActor
private final class ClockTask: WorkspaceModeScheduledTask {
    let action: @MainActor () -> Void
    var cancelled = false

    init(_ action: @MainActor @escaping () -> Void) { self.action = action }
    func cancel() { cancelled = true }
}

@MainActor
private final class ClockFake: WorkspaceModeScheduling {
    var now = 100.0
    var tasks: [ClockTask] = []

    func scheduleRepeating(every interval: TimeInterval, _ handler: @MainActor @escaping () -> Void) -> WorkspaceModeScheduledTask {
        let task = ClockTask(handler)
        tasks.append(task)
        return task
    }

    func drain() {
        for _ in 0..<12 {
            now += 0.031
            for task in tasks where !task.cancelled { task.action() }
        }
    }
}

@MainActor
private final class KeyPosterFake: ProcessKeySequencePosting {
    var strokes: [ProcessKeyStroke] = []
    func post(_ strokes: [ProcessKeyStroke], to processIdentifier: pid_t) -> Bool {
        self.strokes += strokes
        return true
    }
}

@MainActor
private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

@MainActor
private func checkActivation(_ bundleIdentifier: String) {
    let workspace = WorkspaceFake(), observer = ForegroundFake(), clock = ClockFake()
    let target = ApplicationIdentity(processIdentifier: 2, bundleIdentifier: bundleIdentifier)
    workspace.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: "com.openai.codex")
    workspace.running[bundleIdentifier] = target
    let controller = WorkspaceCycleController(workspace: workspace, observer: observer, scheduler: clock, log: { _ in })
    controller.start()
    controller.resetToForeground()
    controller.cycle()
    check(workspace.activations == [target], "activation failed for \(bundleIdentifier)")
    check(workspace.launchRequests.isEmpty, "running app was relaunched")
    workspace.frontmost = target
    observer.change(to: bundleIdentifier)
    check(controller.displayMode == .super, "foreground did not select SUPER")
}

@MainActor
private func checkCurrentLaunch() {
    let workspace = WorkspaceFake(), observer = ForegroundFake(), clock = ClockFake()
    workspace.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: "com.openai.codex")
    let controller = WorkspaceCycleController(workspace: workspace, observer: observer, scheduler: clock, log: { _ in })
    controller.start()
    controller.resetToForeground()
    controller.cycle()
    check(workspace.launchRequests == ["engineering.super.app"], "missing SUPER used the wrong bundle ID")
    workspace.frontmost = ApplicationIdentity(processIdentifier: 2, bundleIdentifier: "engineering.super.app")
    observer.change(to: "engineering.super.app")
    check(controller.displayMode == .super, "launched SUPER did not become selected")
}

@MainActor
private func checkCurrentPrecedence() {
    let workspace = WorkspaceFake(), observer = ForegroundFake(), clock = ClockFake()
    let current = ApplicationIdentity(processIdentifier: 2, bundleIdentifier: "engineering.super.app")
    let legacy = ApplicationIdentity(processIdentifier: 3, bundleIdentifier: "com.zarifpour.superconductor")
    workspace.running[current.bundleIdentifier] = current
    workspace.running[legacy.bundleIdentifier] = legacy
    workspace.frontmost = ApplicationIdentity(processIdentifier: 1, bundleIdentifier: "com.openai.codex")
    let controller = WorkspaceCycleController(workspace: workspace, observer: observer, scheduler: clock, log: { _ in })
    controller.start()
    controller.resetToForeground()
    controller.cycle()
    check(workspace.activations == [current], "current SUPER did not take priority")
}

@MainActor
private func checkKeySequence(_ bundleIdentifier: String) {
    let target = ApplicationIdentity(processIdentifier: 202, bundleIdentifier: bundleIdentifier)
    let clock = ClockFake(), poster = KeyPosterFake()
    let emitter = SystemProcessTargetedKeyEmitter(
        frontmostIdentity: { target }, identityForProcess: { _ in target },
        poster: poster, scheduler: clock, uptime: { clock.now }, trusted: { true }
    )
    check(emitter.emit(.nextTab, to: target), "SUPER key sequence rejected for \(bundleIdentifier)")
    check(poster.strokes.count == 1, "first key stroke was not sent")
    clock.drain()
    let expected = [
        ProcessKeyStroke(keyCode: 59, keyDown: true, flags: .maskControl),
        ProcessKeyStroke(keyCode: 58, keyDown: true, flags: [.maskControl, .maskAlternate]),
        ProcessKeyStroke(keyCode: 124, keyDown: true, flags: [.maskControl, .maskAlternate]),
        ProcessKeyStroke(keyCode: 124, keyDown: false, flags: [.maskControl, .maskAlternate]),
        ProcessKeyStroke(keyCode: 58, keyDown: false, flags: .maskControl),
        ProcessKeyStroke(keyCode: 59, keyDown: false, flags: [])
    ]
    check(poster.strokes == expected, "incomplete SUPER key sequence for \(bundleIdentifier)")
    emitter.stop()
}

@main
private struct BundleIDRegression {
    static func main() async {
        await MainActor.run {
            checkActivation("engineering.super.app")
            checkActivation("com.zarifpour.superconductor")
            checkCurrentLaunch()
            checkCurrentPrecedence()
            checkKeySequence("engineering.super.app")
            checkKeySequence("com.zarifpour.superconductor")
            print("PASS: current and legacy SUPER activation, cold launch, priority, foreground, paced keys")
        }
    }
}
