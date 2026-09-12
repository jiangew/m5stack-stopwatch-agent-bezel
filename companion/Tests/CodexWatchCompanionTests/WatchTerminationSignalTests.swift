import Darwin
import XCTest
@testable import CodexWatchCompanion

@MainActor final class WatchTerminationSignalTests: XCTestCase {
    func testTerminationCallbackRunsOnceAndCanceledSignalsDoNotRepeatCleanup() {
        var calls = 0
        let termination = WatchTerminationSignal { calls += 1 }
        termination.start()
        // Only this test process receives the signal. Callback does not exit.
        XCTAssertEqual(kill(getpid(),SIGTERM),0)
        RunLoop.main.run(until:Date().addingTimeInterval(0.08))
        XCTAssertEqual(calls,1)
        termination.stop()
        XCTAssertEqual(kill(getpid(),SIGTERM),0)
        RunLoop.main.run(until:Date().addingTimeInterval(0.03))
        XCTAssertEqual(calls,1)
    }
}
