import XCTest
import IOKit.hid
@testable import CodexWatchCompanion

@MainActor
private final class ListenerOutputDeviceStub: StopwatchHIDOutputDevice {
    let deviceKey: UInt
    private(set) var writes: [[UInt8]] = []

    init(deviceKey: UInt) {
        self.deviceKey = deviceKey
    }

    func setOutputReport(reportID: Int, bytes: [UInt8]) -> IOReturn {
        XCTAssertEqual(reportID, 6)
        writes.append(bytes)
        return kIOReturnSuccess
    }
}

@MainActor
final class HIDShortcutDecoderTests: XCTestCase {
    func testHomeResyncBypassesUserCooldownButRejectsExtraFields() {
        var decoder=HIDShortcutDecoder()
        func consume(_ text:String,_ now:Double)->[CompanionShortcutEvent] {
            WorkspaceModeHIDReportFramer.reports(payloadBytes:Array((text+"\n").utf8)).flatMap {
                decoder.consume(reportID:6,bytes:$0,now:now)
            }
        }
        let left = #"{"method":"host.workspace_navigation","params":{"workspace":"home","direction":"left","phase":"press"}}"#
        let sync = #"{"method":"host.workspace_action","params":{"action":"show_home"}}"#
        XCTAssertEqual(consume(left,1),[.navigation(.home,.left)])
        XCTAssertEqual(consume(sync,1.01),[.showHome])
        XCTAssertEqual(consume(left,2),[.navigation(.home,.left)])
        XCTAssertEqual(consume(sync.replacingOccurrences(of:"\"show_home\"",with:"\"show_home\",\"extra\":1"),2),[])
        for direction in ["up","down","right"] {
            XCTAssertEqual(consume(left.replacingOccurrences(of:"left",with:direction),3),[])
        }
    }
    func testDedicatedNavigationRejectsMalformedShapesAndPreservesOrigin() {
        var decoder = HIDShortcutDecoder()
        func consume(_ json: String, _ time: Double) -> [CompanionShortcutEvent] {
            WorkspaceModeHIDReportFramer.reports(payloadBytes: Array((json + "\n").utf8)).flatMap {
                decoder.consume(reportID: 6, bytes: $0, now: time)
            }
        }
        let valid = #"{"method":"host.workspace_navigation","params":{"workspace":"hermes","direction":"up","phase":"press"}}"#
        for invalid in [
            valid.replacingOccurrences(of: "\"hermes\"", with: "true"),
            valid.replacingOccurrences(of: "\"up\"", with: "1"),
            valid.replacingOccurrences(of: "\"press\"", with: "null"),
            valid.replacingOccurrences(of: "\"phase\":\"press\"", with: "\"extra\":\"press\""),
            valid.replacingOccurrences(of: "\"phase\":\"press\"", with: "\"phase\":\"press\",\"extra\":1"),
            valid.replacingOccurrences(of: "\"params\":", with: "\"id\":1,\"params\":")
        ] { XCTAssertEqual(consume(invalid, 1), []) }
        XCTAssertEqual(consume(valid, 1), [.navigation(.hermes, .up)])
        // A native release cannot release the dedicated latch.
        _ = decoder.consume(reportID: 6, bytes: radial(angle: 0.75, distance: 0), now: 2)
        XCTAssertEqual(consume(valid, 2), [])
        _ = consume(valid.replacingOccurrences(of: "press", with: "release"), 2)
        XCTAssertEqual(consume(valid, 2), [.navigation(.hermes, .up)])
        _ = consume(valid.replacingOccurrences(of: "press", with: "release"), 2.1)
        XCTAssertEqual(consume(valid, 2.2), [])
        XCTAssertEqual(consume(valid, 3), [])
        _ = consume(valid.replacingOccurrences(of: "press", with: "release"), 3)
        XCTAssertEqual(consume(valid, 3), [.navigation(.hermes, .up)])
        decoder.reset()
        XCTAssertEqual(consume(valid.replacingOccurrences(of: "hermes", with: "super"), 1), [.navigation(.super, .up)])
    }
    func testDedicatedNavigationRequiresMatchingReleaseAndStrictFields() {
        var decoder = HIDShortcutDecoder()
        func consume(_ workspace: String, _ direction: String, _ phase: String, _ time: Double) -> [CompanionShortcutEvent] {
            let json = "{\"method\":\"host.workspace_navigation\",\"params\":{\"workspace\":\"\(workspace)\",\"direction\":\"\(direction)\",\"phase\":\"\(phase)\"}}\n"
            return WorkspaceModeHIDReportFramer.reports(payloadBytes: Array(json.utf8)).flatMap {
                decoder.consume(reportID: 6, bytes: $0, now: time)
            }
        }
        XCTAssertEqual(consume("hermes", "up", "press", 1).count, 1)
        XCTAssertEqual(consume("hermes", "up", "press", 2).count, 0)
        XCTAssertEqual(consume("super", "up", "release", 2).count, 0)
        XCTAssertEqual(consume("hermes", "down", "release", 2).count, 0)
        XCTAssertEqual(consume("hermes", "up", "press", 3).count, 0)
        XCTAssertEqual(consume("hermes", "up", "release", 3).count, 0)
        XCTAssertEqual(consume("codex", "up", "press", 4).count, 0)
        XCTAssertEqual(consume("hermes", "bad", "press", 4).count, 0)
        XCTAssertEqual(consume("hermes", "up", "bad", 4).count, 0)
        XCTAssertEqual(consume("super", "right", "press", 4).count, 1)
    }
    func testWorkspaceActionIsStrictFragmentedAndSharesDirectionCooldown() {
        var decoder = HIDShortcutDecoder()
        func consume(_ json: String, _ time: TimeInterval) -> [CompanionShortcutEvent] {
            WorkspaceModeHIDReportFramer.reports(payloadBytes: Array((json + "\n").utf8)).flatMap {
                decoder.consume(reportID: 6, bytes: $0, now: time)
            }
        }
        let valid = #"{"method":"host.workspace_action","params":{"action":"open_hermes"}}"#
        XCTAssertEqual(consume(valid, 1).count, 1)
        XCTAssertEqual(consume(valid, 1.5), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: radial(angle: 0.5, distance: 1), now: 1.6), [])
        _ = decoder.consume(reportID: 6, bytes: radial(angle: 0.5, distance: 0), now: 1.7)
        for invalid in [
            #"{"method":"host.workspace_action","params":{"action":"other"}}"#,
            #"{"method":"host.workspace_action","params":{"action":"open_hermes","extra":1}}"#,
            #"{"method":"host.workspace_action","params":{"action":true}}"#,
            #"{"method":"host.workspace_action","params":{"action":"open_hermes"},"id":1}"#
        ] { XCTAssertEqual(consume(invalid, 2), []) }
        XCTAssertEqual(consume(valid, 2).count, 1)
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: radial(angle: 0.5, distance: 1), now: 2.9), [.left])
    }
    func testInvalidatedCallbackContextIgnoresDelayedDelivery() {
        var delivered: [HIDShortcutCallbackAction] = []
        let session = HIDShortcutCallbackSession { delivered.append($0) }
        let context = HIDShortcutCallbackRegistry.retain(session)
        let delayedSession = HIDShortcutCallbackRegistry.session(for: context)

        session.deliver(.matched(deviceKey: 1))
        XCTAssertEqual(delivered, [.matched(deviceKey: 1)])

        HIDShortcutCallbackRegistry.invalidate(context)
        delayedSession?.deliver(.removed(deviceKey: 1))

        XCTAssertEqual(delivered, [.matched(deviceKey: 1)])
        XCTAssertNil(HIDShortcutCallbackRegistry.session(for: context))
    }

    func testMatchedDevicesCreateIndependentWorkspaceSendersAndRemovalOnlyClearsOne() {
        let first = ListenerOutputDeviceStub(deviceKey: 1)
        let second = ListenerOutputDeviceStub(deviceKey: 2)
        var attached: [UInt] = []
        var removed: [UInt] = []
        let listener = HIDShortcutListener(
            eventHandler: { _ in },
            log: { _ in },
            workspaceSenderMatched: { attached.append($0.deviceKey) },
            workspaceSenderRemoved: { removed.append($0) }
        )

        listener.handle(.matched(deviceKey: 1, outputDevice: first))
        listener.handle(.matched(deviceKey: 2, outputDevice: second))

        XCTAssertEqual(attached, [1, 2])
        XCTAssertEqual(listener.activeWorkspaceSenderDeviceKeys, Set([1, 2]))

        listener.handle(.removed(deviceKey: 1))

        XCTAssertEqual(removed, [1])
        XCTAssertEqual(listener.activeWorkspaceSenderDeviceKeys, Set([2]))
        XCTAssertTrue(listener.workspaceSender(deviceKey: 2)?.send(.codex) == true)
        XCTAssertFalse(second.writes.isEmpty)
    }

    func testStopClearsOutputHandlesWhenManagerHasNotStarted() {
        let device = ListenerOutputDeviceStub(deviceKey: 1)
        var removed: [UInt] = []
        let listener = HIDShortcutListener(
            eventHandler: { _ in },
            log: { _ in },
            workspaceSenderRemoved: { removed.append($0) }
        )
        listener.handle(.matched(deviceKey: 1, outputDevice: device))

        listener.stop()

        XCTAssertTrue(listener.activeWorkspaceSenderDeviceKeys.isEmpty)
        XCTAssertEqual(removed, [1])
    }

    func testInvalidatedCallbackCannotAttachDelayedOutputDevice() {
        let device = ListenerOutputDeviceStub(deviceKey: 9)
        let listener = HIDShortcutListener(eventHandler: { _ in }, log: { _ in })
        let session = HIDShortcutCallbackSession { listener.handle($0) }
        let context = HIDShortcutCallbackRegistry.retain(session)
        let delayedSession = HIDShortcutCallbackRegistry.session(for: context)

        HIDShortcutCallbackRegistry.invalidate(context)
        delayedSession?.deliver(.matched(deviceKey: 9, outputDevice: device))

        XCTAssertTrue(listener.activeWorkspaceSenderDeviceKeys.isEmpty)
    }

    func testMatchingDictionaryContainsOnlyExpectedDeviceIdentity() {
        XCTAssertEqual(HIDShortcutListener.matching.count, 4)
        XCTAssertEqual(HIDShortcutListener.matching[kIOHIDVendorIDKey as String] as? Int, 0x303A)
        XCTAssertEqual(HIDShortcutListener.matching[kIOHIDProductIDKey as String] as? Int, 0x8360)
        XCTAssertEqual(HIDShortcutListener.matching[kIOHIDPrimaryUsagePageKey as String] as? Int, 0xFF00)
        XCTAssertEqual(HIDShortcutListener.matching[kIOHIDPrimaryUsageKey as String] as? Int, 1)
    }

    private func report(_ fragment: String, paddedTo size: Int = 63) -> [UInt8] {
        let payload = Array(fragment.utf8)
        precondition(payload.count <= 61)
        return [0x02, UInt8(payload.count)] + payload
            + Array(repeating: 0, count: max(0, size - payload.count - 2))
    }

    private func radial(angle: Double, distance: Double) -> [UInt8] {
        report(#"{"method":"v.oai.rad","params":{"a":\#(angle),"d":\#(distance)}}"# + "\n")
    }

    func testFourPhysicalAnglesProduceTypedEvents() {
        let cases: [(Double, CompanionShortcutEvent)] = [
            (0.00, .right),
            (0.25, .down),
            (0.50, .left),
            (0.75, .up),
        ]

        for (angle, expected) in cases {
            var decoder = HIDShortcutDecoder()
            XCTAssertEqual(
                decoder.consume(reportID: 6, bytes: radial(angle: angle, distance: 1), now: 10),
                [expected]
            )
        }
    }

    func testUnknownAngleOutsideToleranceIsIgnored() {
        var decoder = HIDShortcutDecoder()
        XCTAssertEqual(
            decoder.consume(reportID: 6, bytes: radial(angle: 0.12, distance: 1), now: 10),
            []
        )
    }

    func testFragmentedLeftPressProducesOneToggle() {
        var decoder = HIDShortcutDecoder()
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai."#), now: 10), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"rad","params":{"a":0.5,"d":1.0}}"# + "\n"), now: 10.01), [.left])
    }

    func testRawMacOSCallbackIncludingReportIDProducesToggle() {
        var decoder = HIDShortcutDecoder()
        let body = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        let rawReport = [UInt8(StopwatchHIDDescriptor.reportID)] + body

        XCTAssertEqual(
            decoder.consume(reportID: 6, bytes: rawReport, now: 10),
            [.left]
        )
    }

    func testReleaseRearmsButCooldownBlocksImmediateSecondPress() {
        var decoder = HIDShortcutDecoder()
        let press = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        let release = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":0.0}}"# + "\n")
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1), [.left])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1.1), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: release, now: 1.2), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1.3), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: release, now: 1.4), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1.81), [.left])
    }

    func testPressRejectedByCooldownStillRequiresReleaseBeforeAnotherDirectionCanFire() {
        var decoder = HIDShortcutDecoder()
        XCTAssertEqual(
            decoder.consume(reportID: 6, bytes: radial(angle: 0, distance: 1), now: 1),
            [.right]
        )
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: radial(angle: 0, distance: 0), now: 1.1), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: radial(angle: 0.75, distance: 1), now: 1.2), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: radial(angle: 0.75, distance: 1), now: 2.1), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: radial(angle: 0.75, distance: 0), now: 2.2), [])
        XCTAssertEqual(
            decoder.consume(reportID: 6, bytes: radial(angle: 0.25, distance: 1), now: 2.3),
            [.down]
        )
    }

    func testMalformedFrameClearsBufferAndNextMessageRecovers() {
        var decoder = HIDShortcutDecoder()
        _ = decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai."#), now: 1)
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: [0x02, 60, 0x7B], now: 1.1), [])
        let valid = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: valid, now: 2), [.left])
    }

    func testWrongReportMethodDirectionAndNonFiniteValuesAreIgnored() {
        var decoder = HIDShortcutDecoder()
        let left = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        XCTAssertEqual(decoder.consume(reportID: 5, bytes: left, now: 1), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"other","params":{"a":0.5,"d":1.0}}"# + "\n"), now: 2), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai.rad","params":{"a":0.12,"d":1.0}}"# + "\n"), now: 3), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai.rad","params":{"a":"NaN","d":1.0}}"# + "\n"), now: 4), [])
    }

    func testOtherReportIDDoesNotDiscardAnInProgressVendorMessage() {
        var decoder = HIDShortcutDecoder()
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai."#), now: 1), [])
        XCTAssertEqual(decoder.consume(reportID: 5, bytes: [0x00], now: 1.1), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"rad","params":{"a":0.5,"d":1.0}}"# + "\n"), now: 1.2), [.left])
    }

    func testDescriptorConstantsMatchPhysicalProbe() {
        XCTAssertEqual(StopwatchHIDDescriptor.vendorID, 0x303A)
        XCTAssertEqual(StopwatchHIDDescriptor.productID, 0x8360)
        XCTAssertEqual(StopwatchHIDDescriptor.usagePage, 0xFF00)
        XCTAssertEqual(StopwatchHIDDescriptor.usage, 1)
        XCTAssertEqual(StopwatchHIDDescriptor.reportID, 6)
    }

    func testOversizedBufferIsClearedAndNextMessageRecovers() {
        var decoder = HIDShortcutDecoder()
        for index in 0 ..< 68 {
            XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(String(repeating: "x", count: 61)), now: TimeInterval(index)), [])
        }
        let valid = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: valid, now: 100), [.left])
    }

    func testConsumesEveryNewlineInOneFragment() {
        var decoder = HIDShortcutDecoder()
        let payload = "{}\n" + #"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n"
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(payload), now: 1), [.left])
    }
}
