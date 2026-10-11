import CoreGraphics
import XCTest
@testable import CodexWatchCompanion

@MainActor private final class KeyTimer: WorkspaceModeScheduledTask {
    var canceled = false
    let action: @MainActor () -> Void
    init(_ action: @MainActor @escaping () -> Void) { self.action = action }
    func cancel() { canceled = true }
}
@MainActor private final class KeyClock: WorkspaceModeScheduling {
    var now = 100.0
    var tasks: [KeyTimer] = []
    func scheduleRepeating(every interval: TimeInterval, _ handler: @MainActor @escaping () -> Void) -> WorkspaceModeScheduledTask {
        let task = KeyTimer(handler); tasks.append(task); return task
    }
    func advance(_ delta: Double = 0.031) { now += delta; for t in tasks where !t.canceled { t.action() } }
    func drain() { for _ in 0..<12 { advance() } }
}
@MainActor private final class KeyPoster: ProcessKeySequencePosting {
    var strokes: [ProcessKeyStroke] = []
    var pids: [pid_t] = []
    var times: [Double] = []
    var result = true
    let clock: KeyClock
    init(_ clock: KeyClock) { self.clock = clock }
    func post(_ strokes: [ProcessKeyStroke], to processIdentifier: pid_t) -> Bool {
        guard result else { return false }
        self.strokes += strokes; pids += strokes.map { _ in processIdentifier }
        times += strokes.map { _ in clock.now }; return true
    }
}
@MainActor private final class KeyFixture {
    let target: ApplicationIdentity
    var front: ApplicationIdentity?
    var actual: ApplicationIdentity?
    var trusted = true
    let clock = KeyClock()
    lazy var poster = KeyPoster(clock)
    lazy var emitter = SystemProcessTargetedKeyEmitter(frontmostIdentity: { [unowned self] in front },
        identityForProcess: { [unowned self] _ in actual }, poster: poster, scheduler: clock,
        uptime: { [unowned self] in clock.now }, trusted: { [unowned self] in trusted })
    init(hermes: Bool = false, deepseek: Bool = false, superBundleIdentifier: String = "com.zarifpour.superconductor") {
        target = ApplicationIdentity(processIdentifier: 202, bundleIdentifier: deepseek ? "com.deepseek.dsh" : (hermes ? "com.nousresearch.hermes" : superBundleIdentifier))
        front = target; actual = target
    }
    func send(_ c: WorkspaceNavigationCommand) -> Bool { emitter.emit(c, to: target) }
}
@MainActor final class PacedKeyEmitterTests: XCTestCase {
    private func s(_ k: Int, _ down: Bool, _ flags: CGEventFlags) -> ProcessKeyStroke {
        ProcessKeyStroke(keyCode: CGKeyCode(k), keyDown: down, flags: flags)
    }
    func testCurrentAndLegacySuperBundleIDsPostCompleteSequence() {
        for bundleID in ["engineering.super.app", "com.zarifpour.superconductor"] {
            let f = KeyFixture(superBundleIdentifier: bundleID)
            XCTAssertTrue(f.send(.nextTab))
            XCTAssertEqual(f.poster.strokes.count, 1)
            f.clock.drain()
            XCTAssertEqual(f.poster.strokes, [
                s(59, true, .maskControl), s(58, true, [.maskControl, .maskAlternate]),
                s(124, true, [.maskControl, .maskAlternate]),
                s(124, false, [.maskControl, .maskAlternate]),
                s(58, false, .maskControl), s(59, false, [])
            ])
            f.emitter.stop()
        }
    }
    func testDeepseekCompleteChordsPacingAndRepeatedRightNeverRetainControl() {
        let f = KeyFixture(deepseek: true)
        let cases: [(WorkspaceNavigationCommand, Int)] = [(.previousDeepseekThread,126), (.nextDeepseekThread,125), (.toggleDeepseekView,124), (.toggleDeepseekView,124)]
        for (command, code) in cases {
            let before = f.poster.strokes.count
            XCTAssertTrue(f.send(command))
            XCTAssertFalse(f.send(command))
            f.clock.advance(0.029)
            XCTAssertEqual(f.poster.strokes.count, before + 1)
            f.clock.advance(0.002)
            XCTAssertEqual(f.poster.strokes.count, before + 2)
            f.clock.advance(1)
            XCTAssertEqual(f.poster.strokes.count, before + 3)
            f.clock.drain()
            let expected = [s(59,true,.maskControl),s(58,true,[.maskControl,.maskAlternate]),s(code,true,[.maskControl,.maskAlternate]),s(code,false,[.maskControl,.maskAlternate]),s(58,false,.maskControl),s(59,false,[])]
            XCTAssertEqual(Array(f.poster.strokes.dropFirst(before)), expected)
            XCTAssertEqual(WorkspaceKeySequence.strokes(for: command, controlHeld: true), expected)
            XCTAssertTrue(f.clock.tasks.allSatisfy { $0.canceled })
        }
        XCTAssertEqual(Set(f.poster.pids), Set([f.target.processIdentifier]))
        for (a,b) in zip(f.poster.times, f.poster.times.dropFirst()) { XCTAssertTrue(b-a >= 0.03) }
        let before = f.poster.strokes.count
        f.emitter.cancel(); f.clock.drain(); f.emitter.stop()
        XCTAssertEqual(f.poster.strokes.count, before)
    }

    func testDeepseekEveryPartialCancellationAndStopFullyReleaseOriginalPID() {
        for command: WorkspaceNavigationCommand in [.previousDeepseekThread, .nextDeepseekThread, .toggleDeepseekView] {
            for count in 1...6 {
                for stop in [false, true] {
                    let f = KeyFixture(deepseek: true)
                    XCTAssertTrue(f.send(command))
                    for _ in 1..<count { f.clock.advance() }
                    let before = f.poster.strokes
                    var held: [CGKeyCode] = []
                    for stroke in before {
                        if stroke.keyDown { held.append(stroke.keyCode) }
                        else { held.removeAll { $0 == stroke.keyCode } }
                    }
                    let stale = f.clock.tasks
                    if stop { f.emitter.stop() } else { f.emitter.cancel(); f.emitter.cancel() }
                    stale.forEach { $0.action() }; f.clock.drain()
                    XCTAssertEqual(Array(f.poster.strokes.dropFirst(before.count)), WorkspaceKeySequence.releases(held: held))
                    XCTAssertEqual(Set(f.poster.pids), Set([f.target.processIdentifier]))
                    if !stop {
                        for (a,b) in zip(f.poster.times,f.poster.times.dropFirst()) { XCTAssertTrue(b-a >= 0.03) }
                    }
                    f.emitter.stop()
                    XCTAssertFalse(f.send(command))
                }
            }
        }
    }

    func testDeepseekFocusLossCleansUpButPermissionOrIdentityLossNeverRetargets() {
        for loss in 0..<4 {
            let f = KeyFixture(deepseek: true)
            XCTAssertTrue(f.send(.toggleDeepseekView)); f.clock.advance(); f.clock.advance()
            XCTAssertEqual(f.poster.strokes.count, 3)
            switch loss {
            case 0: f.front = ApplicationIdentity(processIdentifier: 303, bundleIdentifier: "com.openai.codex")
            case 1: f.trusted = false
            case 2: f.actual = nil
            default: f.actual = ApplicationIdentity(processIdentifier: 202, bundleIdentifier: "com.deepseek.dsh", launchDate: Date(timeIntervalSince1970: 2))
            }
            f.clock.drain()
            if loss == 0 {
                XCTAssertEqual(Array(f.poster.strokes.suffix(3)), [s(124,false,[.maskControl,.maskAlternate]),s(58,false,.maskControl),s(59,false,[])])
            } else { XCTAssertEqual(f.poster.strokes.count, 3) }
            XCTAssertEqual(Set(f.poster.pids), Set([f.target.processIdentifier]))
            XCTAssertFalse(f.send(.toggleDeepseekView)); f.emitter.stop()
        }
        let f = KeyFixture(deepseek: true)
        f.trusted = false
        XCTAssertFalse(f.send(.previousDeepseekThread))
        XCTAssertTrue(f.poster.strokes.isEmpty)
        f.emitter.stop()
    }

    func testHermesOwnedControlCannotBecomeDeepseekChord() {
        let f = KeyFixture(hermes: true)
        XCTAssertTrue(f.send(.nextHermesTab)); f.clock.drain()
        let before = f.poster.strokes.count
        XCTAssertFalse(f.send(.toggleDeepseekView)); f.clock.drain()
        XCTAssertEqual(Array(f.poster.strokes.dropFirst(before)), [s(59,false,[])])
        f.emitter.stop()
    }

    func testSuperPacingBusyRejectionAndNoCatchupBurst() {
        let cases: [(WorkspaceNavigationCommand, Int)] = [(.previousProject,126),(.nextProject,125),(.nextTab,124)]
        for (command,key) in cases {
            let f = KeyFixture(); XCTAssertTrue(f.send(command))
            XCTAssertEqual(f.poster.strokes,[s(59,true,.maskControl)])
            XCTAssertFalse(f.send(.nextTab))
            f.clock.advance(0.029); XCTAssertEqual(f.poster.strokes.count,1)
            f.clock.advance(0.002); XCTAssertEqual(f.poster.strokes.count,2)
            f.clock.advance(1); XCTAssertEqual(f.poster.strokes.count,3)
            f.clock.drain()
            XCTAssertEqual(f.poster.strokes,[s(59,true,.maskControl),s(58,true,[.maskControl,.maskAlternate]),s(key,true,[.maskControl,.maskAlternate]),s(key,false,[.maskControl,.maskAlternate]),s(58,false,.maskControl),s(59,false,[])])
            XCTAssertEqual(Set(f.poster.pids),Set([pid_t(202)]))
            for (a,b) in zip(f.poster.times,f.poster.times.dropFirst()) { XCTAssertTrue(b-a >= 0.03) }
            f.emitter.stop()
        }
    }
    func testHermesRetainsControlAcrossDownDownUpUntilRight() {
        let f = KeyFixture(hermes:true)
        XCTAssertTrue(f.send(.nextHermesTab)); f.clock.drain()
        XCTAssertTrue(f.send(.nextHermesTab)); f.clock.drain()
        XCTAssertTrue(f.send(.previousHermesTab)); f.clock.drain()
        XCTAssertEqual(f.poster.strokes,[s(59,true,.maskControl),s(48,true,.maskControl),s(48,false,.maskControl),s(48,true,.maskControl),s(48,false,.maskControl),s(56,true,[.maskControl,.maskShift]),s(48,true,[.maskControl,.maskShift]),s(48,false,[.maskControl,.maskShift]),s(56,false,.maskControl)])
        XCTAssertTrue(f.send(.confirmHermesSelection)); f.clock.drain()
        XCTAssertEqual(f.poster.strokes.last,s(59,false,[]))
        let count = f.poster.strokes.count
        XCTAssertTrue(f.send(.confirmHermesSelection)); f.clock.drain()
        XCTAssertEqual(f.poster.strokes.count,count); f.emitter.stop()
    }
    func testEveryPartialCancellationReleasesOnlySubmittedKeysAndIgnoresStaleTimers() {
        for hermes in [false,true] { for count in 1...(hermes ? 4 : 5) {
            let f = KeyFixture(hermes:hermes)
            XCTAssertTrue(f.send(hermes ? .previousHermesTab : .nextTab))
            for _ in 1..<count { f.clock.advance() }
            let before = f.poster.strokes
            var held = Set<CGKeyCode>()
            for stroke in before { if stroke.keyDown { held.insert(stroke.keyCode) } else { held.remove(stroke.keyCode) } }
            let stale = f.clock.tasks
            f.emitter.cancel(); f.emitter.cancel(); stale.forEach { $0.action() }; f.clock.drain()
            let cleanup = Array(f.poster.strokes.dropFirst(before.count))
            XCTAssertTrue(cleanup.allSatisfy { !$0.keyDown })
            XCTAssertEqual(Set(cleanup.map(\.keyCode)),held); XCTAssertEqual(cleanup.count,held.count)
            XCTAssertTrue(cleanup.last!.flags.isEmpty); f.emitter.stop()
        } }
    }
    func testForegroundLossReleasesOriginalPIDAndPermissionOrIdentityLossStopsActions() {
        let f = KeyFixture(hermes:true)
        XCTAssertTrue(f.send(.nextHermesTab)); f.clock.drain()
        f.front = nil; let count = f.poster.strokes.count; f.clock.drain()
        XCTAssertEqual(Array(f.poster.strokes.dropFirst(count)),[s(59,false,[])]); f.emitter.stop()
        for revoke in [false,true] {
            let f = KeyFixture(); XCTAssertTrue(f.send(.nextTab))
            if revoke { f.trusted = false } else { f.actual = ApplicationIdentity(processIdentifier:202,bundleIdentifier:"com.example.reused") }
            f.clock.drain(); XCTAssertEqual(f.poster.strokes.count,1)
            XCTAssertFalse(f.send(.nextTab)); f.emitter.stop()
        }
    }
    func testStopReleasesImmediatelyAndCannotResume() {
        let f = KeyFixture(hermes:true)
        XCTAssertTrue(f.send(.previousHermesTab)); f.clock.advance()
        let tasks = f.clock.tasks; f.emitter.stop()
        XCTAssertEqual(Array(f.poster.strokes.suffix(2)),[s(56,false,.maskControl),s(59,false,[])])
        let count = f.poster.strokes.count
        f.emitter.stop(); tasks.forEach { $0.action() }; f.clock.drain()
        XCTAssertEqual(f.poster.strokes.count,count); XCTAssertFalse(f.send(.nextHermesTab))
    }
    func testPosterFailureDoesNotInventHeldKeys() {
        let f = KeyFixture(); f.poster.result = false
        XCTAssertFalse(f.send(.nextTab)); f.clock.drain(); XCTAssertTrue(f.poster.strokes.isEmpty)
        f.poster.result = true; XCTAssertTrue(f.send(.nextTab)); f.clock.drain()
        XCTAssertEqual(f.poster.strokes.count,6); f.emitter.stop()
    }
    func testRealRunLoopRemainsResponsiveWhileSequenceIsPending() {
        let f = KeyFixture()
        let emitter = SystemProcessTargetedKeyEmitter(frontmostIdentity:{f.target},identityForProcess:{_ in f.target},poster:f.poster,trusted:{true})
        XCTAssertTrue(emitter.emit(.nextTab,to:f.target))
        XCTAssertEqual(f.poster.strokes.count,1)
        var serviced = false
        let timer = Timer(timeInterval:0.005,repeats:false) { _ in serviced = true }
        RunLoop.main.add(timer,forMode:.common)
        RunLoop.main.run(until:Date().addingTimeInterval(0.3))
        XCTAssertTrue(serviced); XCTAssertEqual(f.poster.strokes.count,6)
        emitter.stop()
    }
}
