import XCTest
@testable import CodexWatchCompanion

@MainActor
private final class TogglerSpy: WorkspaceCycling {
    var toggleCount = 0
    var allowsNavigation = true
    var selectedProfile: WorkspaceAppProfile? = .codex
    var openCount = 0
    var homeCount = 0
    func showHome() { homeCount += 1; selectedProfile = nil }
    func openHermes() { openCount += 1 }

    func cycle() {
        toggleCount += 1
    }
}

@MainActor
private final class EmitterSpy: ProcessTargetedKeyEmitting {
    struct Call: Equatable {
        let command: WorkspaceNavigationCommand
        let identity: ApplicationIdentity
    }

    var calls: [Call] = []
    var cancellations = 0
    func cancel() { cancellations += 1 }
    var result = true

    func emit(
        _ command: WorkspaceNavigationCommand,
        to identity: ApplicationIdentity
    ) -> Bool {
        calls.append(Call(command: command, identity: identity))
        return result
    }
}

private struct AccessibilityTrustStub: AccessibilityTrustChecking {
    let isTrusted: Bool
}

private final class RouterLogRecorder {
    var messages: [String] = []
}

@MainActor
final class WorkspaceCommandRouterTests: XCTestCase {
    func testHomeBlocksNativeAndAppDirectionsButAllowsLeftAndControlResync() {
        let f=makeFixture(frontmost:ApplicationIdentity(processIdentifier:1,bundleIdentifier:"com.zarifpour.superconductor"),trusted:false)
        f.toggler.selectedProfile=nil
        for event:CompanionShortcutEvent in [.left,.up,.down,.right,.navigation(.super,.right),.navigation(.hermes,.down)] {
            f.router.handle(event)
        }
        XCTAssertEqual(f.toggler.toggleCount,0)
        XCTAssertTrue(f.emitter.calls.isEmpty)
        f.router.handle(.navigation(.home,.left))
        XCTAssertEqual(f.toggler.toggleCount,1)
        f.router.handle(.showHome)
        XCTAssertEqual(f.toggler.homeCount,1)
        XCTAssertEqual(f.emitter.cancellations,2)
    }
    func testAcceptedCycleAndDeniedNavigationCancelOwnedKeys() {
        let f = makeFixture(frontmost: superApp, trusted: true)
        f.toggler.selectedProfile = .super
        f.router.handle(.navigation(.super,.left))
        XCTAssertEqual(f.emitter.cancellations,1)
        let denied = makeFixture(frontmost: superApp, trusted:false)
        denied.toggler.selectedProfile = .super
        denied.router.handle(.navigation(.super,.up))
        XCTAssertEqual(denied.emitter.cancellations,1)
    }
    func testStaleSourceAndMismatchedForegroundAreIgnoredIncludingNativeLeft() {
        let fixture = makeFixture(frontmost: superApp, trusted: true)
        fixture.router.handle(.navigation(.hermes, .up))
        fixture.router.handle(.navigation(.hermes, .left))
        fixture.router.handle(.left)
        XCTAssertEqual(fixture.toggler.toggleCount, 0)
        XCTAssertTrue(fixture.emitter.calls.isEmpty)
        fixture.toggler.selectedProfile = .hermes
        fixture.router.handle(.navigation(.hermes, .up))
        fixture.router.handle(.navigation(.super, .down))
        XCTAssertTrue(fixture.emitter.calls.isEmpty)
        XCTAssertTrue(fixture.logs.messages.isEmpty)
    }
    func testNativeDirectionsCannotBeForwardedToDedicatedApps() {
        let fixture = makeFixture(frontmost: superApp, trusted: true)
        fixture.router.handle(.up); fixture.router.handle(.down); fixture.router.handle(.right)
        XCTAssertTrue(fixture.emitter.calls.isEmpty)
    }
    func testWaitingSelectionSuppressesUnderlyingSuperAndRoutesCenterWithoutAX() {
        let fixture = makeFixture(frontmost: superApp, trusted: false)
        fixture.toggler.allowsNavigation = false
        fixture.toggler.selectedProfile = .hermes
        for direction: WorkspaceSwipeDirection in [.up, .down, .right] {
            fixture.router.handle(.navigation(.hermes, direction))
        }
        XCTAssertTrue(fixture.emitter.calls.isEmpty)
        XCTAssertTrue(fixture.logs.messages.isEmpty)
        fixture.router.handle(.openHermes); fixture.router.handle(.navigation(.hermes, .left))
        XCTAssertEqual(fixture.toggler.openCount, 1)
        XCTAssertEqual(fixture.toggler.toggleCount, 1)
    }
    private let chatGPT = ApplicationIdentity(processIdentifier: 101, bundleIdentifier: "com.openai.chat")
    private let superApp = ApplicationIdentity(
        processIdentifier: 202,
        bundleIdentifier: "com.zarifpour.superconductor"
    )

    func testHermesNavigationUsesOnlyExactForegroundTarget() {
        let hermes = ApplicationIdentity(processIdentifier: 303, bundleIdentifier: "com.nousresearch.hermes")
        let fixture = makeFixture(frontmost: hermes, trusted: true)
        fixture.router.handle(.navigation(.hermes, .up))
        fixture.router.handle(.navigation(.hermes, .down))
        fixture.router.handle(.navigation(.hermes, .right))
        XCTAssertEqual(fixture.emitter.calls, [
            .init(command: .previousHermesTab, identity: hermes),
            .init(command: .nextHermesTab, identity: hermes),
            .init(command: .confirmHermesSelection, identity: hermes),
        ])
    }

    func testLeftAlwaysReachesTogglerWithoutAccessibility() {
        let fixture = makeFixture(frontmost: chatGPT, trusted: false)

        fixture.router.handle(.left)

        XCTAssertEqual(fixture.toggler.toggleCount, 1)
        XCTAssertTrue(fixture.emitter.calls.isEmpty)
        XCTAssertTrue(fixture.logs.messages.isEmpty)
    }

    func testNavigationIsSilentOutsideForegroundSuperEngineering() {
        let fixture = makeFixture(frontmost: chatGPT, trusted: true)

        fixture.router.handle(.down)

        XCTAssertEqual(fixture.toggler.toggleCount, 0)
        XCTAssertTrue(fixture.emitter.calls.isEmpty)
        XCTAssertTrue(fixture.logs.messages.isEmpty)
    }

    func testNavigationUsesExactForegroundIdentityForEveryCommand() {
        let fixture = makeFixture(frontmost: superApp, trusted: true)

        fixture.router.handle(.navigation(.super, .up))
        fixture.router.handle(.navigation(.super, .down))
        fixture.router.handle(.navigation(.super, .right))

        XCTAssertEqual(fixture.emitter.calls, [
            .init(command: .previousProject, identity: superApp),
            .init(command: .nextProject, identity: superApp),
            .init(command: .nextTab, identity: superApp),
        ])
        XCTAssertEqual(fixture.toggler.toggleCount, 0)
    }

    func testAccessibilityWarningOccursOnceAndLeftStillWorks() {
        let fixture = makeFixture(frontmost: superApp, trusted: false)

        fixture.router.handle(.navigation(.super, .up))
        fixture.router.handle(.navigation(.super, .down))
        fixture.router.handle(.navigation(.super, .left))

        XCTAssertTrue(fixture.emitter.calls.isEmpty)
        XCTAssertEqual(fixture.toggler.toggleCount, 1)
        XCTAssertEqual(fixture.logs.messages.filter { $0.contains("辅助功能") }.count, 1)
    }

    func testDeliveryFailureIsGenericAndDoesNotToggle() {
        let fixture = makeFixture(frontmost: superApp, trusted: true)
        fixture.emitter.result = false

        fixture.router.handle(.navigation(.super, .right))

        XCTAssertEqual(fixture.emitter.calls, [.init(command: .nextTab, identity: superApp)])
        XCTAssertEqual(fixture.toggler.toggleCount, 0)
        XCTAssertEqual(fixture.logs.messages, ["super.engineering 导航按键发送失败"])
    }

    private func makeFixture(
        frontmost: ApplicationIdentity,
        trusted: Bool
    ) -> (
        router: WorkspaceCommandRouter,
        toggler: TogglerSpy,
        emitter: EmitterSpy,
        logs: RouterLogRecorder
    ) {
        let workspace = WorkspaceStub()
        workspace.frontmost = frontmost
        let toggler = TogglerSpy()
        toggler.selectedProfile = WorkspaceAppProfile(bundleIdentifier: frontmost.bundleIdentifier) ?? .codex
        let emitter = EmitterSpy()
        let logs = RouterLogRecorder()
        let router = WorkspaceCommandRouter(
            workspace: workspace,
            toggler: toggler,
            emitter: emitter,
            accessibility: AccessibilityTrustStub(isTrusted: trusted),
            log: { logs.messages.append($0) }
        )
        return (router, toggler, emitter, logs)
    }
}
