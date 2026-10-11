import CoreGraphics
import XCTest
@testable import CodexWatchCompanion

@MainActor private final class GuardPoster: ProcessKeySequencePosting {
    var count = 0
    func post(_ strokes: [ProcessKeyStroke], to processIdentifier: pid_t) -> Bool {
        count += strokes.count; return true
    }
}
@MainActor final class SuperEngineeringKeyEmitterTests: XCTestCase {
    func testDeepseekCommandsRejectExitedBackgroundReusedAndWrongProfileIdentities() {
        let target = ApplicationIdentity(processIdentifier: 404, bundleIdentifier: "com.deepseek.dsh", launchDate: Date(timeIntervalSince1970: 1))
        let reused = ApplicationIdentity(processIdentifier: 404, bundleIdentifier: "com.deepseek.dsh", launchDate: Date(timeIntervalSince1970: 2))
        let superApp = ApplicationIdentity(processIdentifier: 202, bundleIdentifier: "engineering.super.app")
        let cases: [(ApplicationIdentity?, ApplicationIdentity?, ApplicationIdentity)] = [
            (target,nil,target), (target,reused,target), (superApp,target,target),
            (superApp,superApp,superApp),
        ]
        for command: WorkspaceNavigationCommand in [.previousDeepseekThread, .nextDeepseekThread, .toggleDeepseekView] {
            for (front,actual,requested) in cases {
                let poster = GuardPoster()
                let emitter = SystemProcessTargetedKeyEmitter(frontmostIdentity:{front},identityForProcess:{_ in actual},poster:poster,trusted:{true})
                XCTAssertFalse(emitter.emit(command,to:requested))
                XCTAssertEqual(poster.count,0); emitter.stop()
            }
        }
        for command: WorkspaceNavigationCommand in [.previousProject, .nextTab, .nextHermesTab, .confirmHermesSelection] {
            let poster = GuardPoster()
            let emitter = SystemProcessTargetedKeyEmitter(frontmostIdentity:{target},identityForProcess:{_ in target},poster:poster,trusted:{true})
            XCTAssertFalse(emitter.emit(command,to:target))
            XCTAssertEqual(poster.count,0); emitter.stop()
        }
    }

    func testRightWithoutOwnedHermesSelectionPostsNothing() {
        let hermes = ApplicationIdentity(processIdentifier:303,bundleIdentifier:"com.nousresearch.hermes")
        let poster = GuardPoster()
        let emitter = SystemProcessTargetedKeyEmitter(frontmostIdentity:{ hermes },identityForProcess:{ _ in hermes },poster:poster,trusted:{true})
        XCTAssertTrue(emitter.emit(.confirmHermesSelection,to:hermes))
        XCTAssertEqual(poster.count,0)
        emitter.stop()
    }
    func testExitedReusedBackgroundAndWrongProfileIdentitiesPostNothing() {
        let target = ApplicationIdentity(processIdentifier:202,bundleIdentifier:"com.zarifpour.superconductor")
        let other = ApplicationIdentity(processIdentifier:202,bundleIdentifier:"com.example.reused")
        let cases: [(ApplicationIdentity?, ApplicationIdentity?, ApplicationIdentity, WorkspaceNavigationCommand)] = [
            (target,nil,target,.nextTab), (target,other,target,.nextTab),
            (other,target,target,.nextTab), (other,other,other,.nextTab),
            (target,target,target,.confirmHermesSelection)
        ]
        for (front,actual,requested,command) in cases {
            let poster = GuardPoster()
            let emitter = SystemProcessTargetedKeyEmitter(frontmostIdentity:{front},identityForProcess:{_ in actual},poster:poster,trusted:{true})
            XCTAssertFalse(emitter.emit(command,to:requested))
            XCTAssertEqual(poster.count,0); emitter.stop()
        }
    }
    func testSameBundleReusingPIDCannotReceiveOldSelectionRelease() {
        let original = ApplicationIdentity(processIdentifier:202,bundleIdentifier:"com.nousresearch.hermes",launchDate:Date(timeIntervalSince1970:1))
        var actual = original
        let poster = GuardPoster()
        let emitter = SystemProcessTargetedKeyEmitter(frontmostIdentity:{original},identityForProcess:{_ in actual},poster:poster,trusted:{true})
        XCTAssertTrue(emitter.emit(.nextHermesTab,to:original))
        XCTAssertEqual(poster.count,1)
        actual = ApplicationIdentity(processIdentifier:202,bundleIdentifier:"com.nousresearch.hermes",launchDate:Date(timeIntervalSince1970:2))
        emitter.stop()
        XCTAssertEqual(poster.count,1)
    }
}
