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
    init(hermes: Bool = false) {
        target = ApplicationIdentity(processIdentifier: 202, bundleIdentifier: hermes ? "com.nousresearch.hermes" : "com.zarifpour.superconductor")
        front = target; actual = target
    }
    func send(_ c: WorkspaceNavigationCommand) -> Bool { emitter.emit(c, to: target) }
}
@MainActor final class PacedKeyEmitterTests: XCTestCase {
    private func s(_ k: Int, _ down: Bool, _ flags: CGEventFlags) -> ProcessKeyStroke {
        ProcessKeyStroke(keyCode: CGKeyCode(k), keyDown: down, flags: flags)
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
}
