import Foundation
import IOKit.hid

enum StopwatchWorkspaceMode: Equatable {
    case home
    case codex
    case `super`
    case hermes
    case hermesIdle, hermesOpening, hermesError

    var awaitingHermes: Bool {
        self == .hermesIdle || self == .hermesOpening || self == .hermesError
    }

    static func foreground(_ bundle: String?) -> Self {
        switch WorkspaceAppProfile(bundleIdentifier: bundle) {
        case .super: return .super
        case .hermes: return .hermes
        default: return .codex
        }
    }
}

@MainActor
protocol StopwatchHIDOutputDevice: AnyObject {
    var deviceKey: UInt { get }
    func setOutputReport(reportID: Int, bytes: [UInt8]) -> IOReturn
}

@MainActor
protocol WorkspaceModeSending: AnyObject {
    var deviceKey: UInt { get }
    func send(_ mode: StopwatchWorkspaceMode) -> Bool
}

enum WorkspaceModeHIDReportFramer {
    static let reportID = 6
    static let command: UInt8 = 0x02
    static let reportSize = 64
    static let maximumPayloadSize = reportSize - 3

    static func reports(payloadBytes: [UInt8]) -> [[UInt8]] {
        guard !payloadBytes.isEmpty else { return [] }

        return stride(from: 0, to: payloadBytes.count, by: maximumPayloadSize).map { start in
            let end = min(start + maximumPayloadSize, payloadBytes.count)
            let chunk = payloadBytes[start..<end]
            var report = [UInt8](repeating: 0, count: reportSize)
            report[0] = UInt8(reportID)
            report[1] = command
            report[2] = UInt8(chunk.count)
            report.replaceSubrange(3..<(3 + chunk.count), with: chunk)
            return report
        }
    }
}

@MainActor
final class WorkspaceModeHIDWriter: WorkspaceModeSending {
    private let device: StopwatchHIDOutputDevice
    private var nextRequestID: UInt32

    init(
        device: StopwatchHIDOutputDevice,
        initialRequestID: UInt32 = 1
    ) {
        self.device = device
        nextRequestID = initialRequestID
    }

    var deviceKey: UInt {
        device.deviceKey
    }

    func send(_ mode: StopwatchWorkspaceMode) -> Bool {
        let requestID = nextRequestID
        nextRequestID &+= 1

        let request: String
        switch mode {
        case .home:
            request = #"{"method":"host.workspace_mode","params":{"mode":"home"},"id":\#(requestID)}"# + "\n"
        case .codex:
            request = #"{"method":"host.workspace_mode","params":{"mode":"codex","ttl_ms":15000},"id":\#(requestID)}"# + "\n"
        case .super:
            request = #"{"method":"host.workspace_mode","params":{"mode":"super","ttl_ms":15000},"id":\#(requestID)}"# + "\n"
        case .hermes:
            request = #"{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000},"id":\#(requestID)}"# + "\n"
        case .hermesIdle, .hermesOpening, .hermesError:
            let state = mode == .hermesIdle ? "idle" : (mode == .hermesOpening ? "opening" : "error")
            request = #"{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000,"state":"\#(state)"},"id":\#(requestID)}"# + "\n"
        }

        for report in WorkspaceModeHIDReportFramer.reports(payloadBytes: Array(request.utf8)) {
            guard device.setOutputReport(
                reportID: WorkspaceModeHIDReportFramer.reportID,
                bytes: report
            ) == kIOReturnSuccess else {
                return false
            }
        }
        return true
    }
}

@MainActor
final class SystemStopwatchHIDOutputDevice: StopwatchHIDOutputDevice {
    private let device: IOHIDDevice

    init(device: IOHIDDevice) {
        self.device = device
    }

    var deviceKey: UInt {
        UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque())
    }

    func setOutputReport(reportID: Int, bytes: [UInt8]) -> IOReturn {
        bytes.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return kIOReturnBadArgument
            }
            return IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                CFIndex(reportID),
                baseAddress,
                CFIndex(buffer.count)
            )
        }
    }
}
