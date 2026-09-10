import XCTest
import Darwin
@testable import CodexWatchCompanion

@MainActor
final class NavigationDiagnosticsTests: XCTestCase {
    func testSignalArmsOnMainRunLoopAndStopIgnoresQueuedSignals() {
        var logs: [String] = []
        let diagnostics = NavigationDiagnostics(uptime: { 1 }, log: { logs.append($0) })
        let trigger = NavigationDiagnosticSignal(diagnostics: diagnostics)
        trigger.start()
        defer { trigger.stop() }
        // This targets only the test process, never the installed Companion.
        XCTAssertEqual(kill(getpid(), SIGUSR1), 0)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        diagnostics.recordInput(.navigation(.hermes, .up))
        XCTAssertEqual(logs, ["NAV hermes_input", "NAV up"])
        trigger.stop()
        XCTAssertEqual(kill(getpid(), SIGUSR1), 0)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        diagnostics.record(.submitted)
        XCTAssertEqual(logs.count, 2)
    }
    func testDiagnosticsDefaultOffExpireAndCannotBeExtended() {
        var now = 10.0
        var logs: [String] = []
        let diagnostics = NavigationDiagnostics(uptime: { now }, log: { logs.append($0) })
        diagnostics.record(.submitted)
        XCTAssertEqual(logs, [])
        diagnostics.arm()
        diagnostics.record(.submitted)
        XCTAssertEqual(logs, ["NAV submitted"])
        now = 309
        diagnostics.arm()
        diagnostics.record(.foregroundRejected)
        now = 310
        diagnostics.record(.submitted)
        XCTAssertEqual(logs, ["NAV submitted", "NAV foreground_rejected"])
        diagnostics.arm()
        diagnostics.record(.submitted)
        XCTAssertEqual(logs.count, 2)
    }

    func testDiagnosticsLimitAndStopArePermanentForThisRun() {
        var logs: [String] = []
        let diagnostics = NavigationDiagnostics(uptime: { 1 }, log: { logs.append($0) })
        diagnostics.arm()
        for _ in 0..<130 { diagnostics.record(.submitted) }
        diagnostics.arm(); diagnostics.record(.submitted)
        XCTAssertEqual(logs.count, 120)
        let stopped = NavigationDiagnostics(uptime: { 1 }, log: { logs.append($0) })
        stopped.stop(); stopped.arm(); stopped.record(.submitted)
        XCTAssertEqual(logs.count, 120)
    }
}
