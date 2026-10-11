import Foundation
import IOKit.hid

enum StopwatchWorkspaceMode: Equatable {
    case home
    case codex
    case deepseek
    case `super`
    case hermes
    case codexIdle, codexOpening, codexError
    case deepseekIdle, deepseekOpening, deepseekError
    case superIdle, superOpening, superError
    case hermesIdle, hermesOpening, hermesError

    var profile: WorkspaceAppProfile? {
        switch self {
        case .home: return nil
        case .codex, .codexIdle, .codexOpening, .codexError: return .codex
        case .deepseek, .deepseekIdle, .deepseekOpening, .deepseekError: return .deepseek
        case .super, .superIdle, .superOpening, .superError: return .super
        case .hermes, .hermesIdle, .hermesOpening, .hermesError: return .hermes
        }
    }

    var waitingState: String? {
        switch self {
        case .codexIdle, .deepseekIdle, .superIdle, .hermesIdle: return "idle"
        case .codexOpening, .deepseekOpening, .superOpening, .hermesOpening: return "opening"
        case .codexError, .deepseekError, .superError, .hermesError: return "error"
        default: return nil
        }
    }

    static func waiting(_ profile: WorkspaceAppProfile, state: String = "idle") -> Self {
        let modes: [Self]
        switch profile {
        case .codex: modes = [.codexIdle, .codexOpening, .codexError]
        case .deepseek: modes = [.deepseekIdle, .deepseekOpening, .deepseekError]
        case .super: modes = [.superIdle, .superOpening, .superError]
        case .hermes: modes = [.hermesIdle, .hermesOpening, .hermesError]
        }
        return modes[state == "opening" ? 1 : (state == "error" ? 2 : 0)]
    }

    var awaitingHermes: Bool {
        self == .hermesIdle || self == .hermesOpening || self == .hermesError
    }

    static func foreground(_ bundle: String?) -> Self {
        switch WorkspaceAppProfile(bundleIdentifier: bundle) {
        case .deepseek: return .deepseek
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
        case .deepseek:
            request = #"{"method":"host.workspace_mode","params":{"mode":"deepseek","ttl_ms":15000},"id":\#(requestID)}"# + "\n"
        case .super:
            request = #"{"method":"host.workspace_mode","params":{"mode":"super","ttl_ms":15000},"id":\#(requestID)}"# + "\n"
        case .hermes:
            request = #"{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000},"id":\#(requestID)}"# + "\n"
        case .codexIdle, .codexOpening, .codexError,
             .deepseekIdle, .deepseekOpening, .deepseekError,
             .superIdle, .superOpening, .superError,
             .hermesIdle, .hermesOpening, .hermesError:
            let name: String
            switch mode.profile! {
            case .codex: name = "codex"
            case .deepseek: name = "deepseek"
            case .super: name = "super"
            case .hermes: name = "hermes"
            }
            request = #"{"method":"host.workspace_mode","params":{"mode":"\#(name)","ttl_ms":15000,"state":"\#(mode.waitingState!)"},"id":\#(requestID)}"# + "\n"
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
