import IOKit.hid
import XCTest
@testable import CodexWatchCompanion

@MainActor
private final class StopwatchHIDOutputDeviceStub: StopwatchHIDOutputDevice {
    struct Write: Equatable {
        let reportID: Int
        let bytes: [UInt8]
    }

    let deviceKey: UInt
    var results: [IOReturn] = []
    private(set) var writes: [Write] = []

    init(deviceKey: UInt = 42) {
        self.deviceKey = deviceKey
    }

    func setOutputReport(reportID: Int, bytes: [UInt8]) -> IOReturn {
        writes.append(.init(reportID: reportID, bytes: bytes))
        return results.isEmpty ? kIOReturnSuccess : results.removeFirst()
    }
}

@MainActor
final class WorkspaceModeHIDWriterTests: XCTestCase {
    func testHomeUsesFixedModeWithoutLeaseOrDisplayContent() {
        let device=StopwatchHIDOutputDeviceStub()
        XCTAssertTrue(WorkspaceModeHIDWriter(device:device).send(.home))
        XCTAssertEqual(String(decoding:reassembledPayload(device.writes),as:UTF8.self),
            #"{"method":"host.workspace_mode","params":{"mode":"home"},"id":1}"# + "\n")
    }
    func testHermesPresentationWireStatesAreFixedAndActiveOmitsState() {
        let cases: [(StopwatchWorkspaceMode, String)] = [
            (.hermesIdle, "idle"), (.hermesOpening, "opening"), (.hermesError, "error")
        ]
        for (mode, state) in cases {
            let device = StopwatchHIDOutputDeviceStub()
            let writer = WorkspaceModeHIDWriter(device: device)
            XCTAssertTrue(writer.send(mode))
            XCTAssertEqual(String(decoding: reassembledPayload(device.writes), as: UTF8.self),
                #"{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000,"state":"\#(state)"},"id":1}"# + "\n")
            XCTAssertTrue(device.writes.allSatisfy { $0.reportID == 6 && $0.bytes.count == 64 })
        }
    }
    func testHermesUsesFixedLeasePayloadAndFullReports() {
        let device = StopwatchHIDOutputDeviceStub()
        let writer = WorkspaceModeHIDWriter(device: device, initialRequestID: 9)
        XCTAssertTrue(writer.send(.hermes))
        XCTAssertEqual(String(decoding: reassembledPayload(device.writes), as: UTF8.self),
            #"{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000},"id":9}"# + "\n")
        XCTAssertTrue(device.writes.allSatisfy { $0.reportID == 6 && $0.bytes.count == 64 })
    }
    func testCodexUsesFullPaddedReportID6FramesAndFixedPayload() {
        let device = StopwatchHIDOutputDeviceStub()
        let writer = WorkspaceModeHIDWriter(device: device, initialRequestID: 7)

        XCTAssertTrue(writer.send(.codex))
        XCTAssertEqual(writer.deviceKey, 42)
        XCTAssertFalse(device.writes.isEmpty)
        XCTAssertTrue(device.writes.allSatisfy { $0.reportID == 6 })
        XCTAssertTrue(device.writes.allSatisfy { $0.bytes.count == 64 })

        let payload = reassembledPayload(device.writes)
        XCTAssertEqual(
            String(decoding: payload, as: UTF8.self),
            #"{"method":"host.workspace_mode","params":{"mode":"codex","ttl_ms":15000},"id":7}"# + "\n"
        )
        for write in device.writes {
            XCTAssertEqual(write.bytes[0], 0x06)
            XCTAssertEqual(write.bytes[1], 0x02)
            let length = Int(write.bytes[2])
            XCTAssertLessThanOrEqual(length, 61)
            XCTAssertTrue(write.bytes[(3 + length)...].allSatisfy { $0 == 0 })
        }
    }

    func testFramerSplitsUTF8BytesAt61AndKeepsNewlineInLastFrame() {
        let payload = Array((String(repeating: "界", count: 21) + "\n").utf8)
        XCTAssertEqual(payload.count, 64)

        let reports = WorkspaceModeHIDReportFramer.reports(payloadBytes: payload)

        XCTAssertEqual(reports.count, 2)
        XCTAssertEqual(reports.map { Int($0[2]) }, [61, 3])
        XCTAssertEqual(reports.flatMap(reportPayload), payload)
        XCTAssertEqual(reports.last?[5], 0x0A)
        XCTAssertTrue(reports.allSatisfy { $0.count == 64 && $0[0] == 6 })
    }

    func testSuperPayloadIsFixedAndRequestIDWraps() {
        let device = StopwatchHIDOutputDeviceStub()
        let writer = WorkspaceModeHIDWriter(
            device: device,
            initialRequestID: UInt32.max
        )

        XCTAssertTrue(writer.send(.super))
        let firstWriteCount = device.writes.count
        XCTAssertEqual(
            String(decoding: reassembledPayload(Array(device.writes[..<firstWriteCount])), as: UTF8.self),
            #"{"method":"host.workspace_mode","params":{"mode":"super","ttl_ms":15000},"id":4294967295}"# + "\n"
        )

        XCTAssertTrue(writer.send(.codex))
        XCTAssertEqual(
            String(decoding: reassembledPayload(Array(device.writes[firstWriteCount...])), as: UTF8.self),
            #"{"method":"host.workspace_mode","params":{"mode":"codex","ttl_ms":15000},"id":0}"# + "\n"
        )
    }

    func testFirstFailedFragmentStopsRemainingWrites() {
        let device = StopwatchHIDOutputDeviceStub()
        device.results = [kIOReturnSuccess, kIOReturnError, kIOReturnSuccess]
        let writer = WorkspaceModeHIDWriter(device: device)

        XCTAssertFalse(writer.send(.super))
        XCTAssertEqual(device.writes.count, 2)
    }

    private func reportPayload(
        _ report: [UInt8]
    ) -> ArraySlice<UInt8> {
        let length = Int(report[2])
        return report[3..<(3 + length)]
    }

    private func reassembledPayload(
        _ writes: [StopwatchHIDOutputDeviceStub.Write]
    ) -> [UInt8] {
        writes.flatMap { reportPayload($0.bytes) }
    }
}
