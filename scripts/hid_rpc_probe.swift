#!/usr/bin/env swift

import Foundation
import IOKit.hid

private let vendorID = 0x303A
private let productID = 0x8360
private let reportID: UInt8 = 6
private let maximumResponseBytes = 64 * 1024

private final class RpcResponseAssembler {
    enum Completion {
        case pending
        case success
        case failure(String)
    }

    let expectedID: Int
    private(set) var completion = Completion.pending
    private(set) var nonmatchingMessages = 0
    private(set) var result: [String: Any]?
    private var buffer = Data()

    init(expectedID: Int) {
        self.expectedID = expectedID
    }

    var isPending: Bool {
        if case .pending = completion { return true }
        return false
    }

    func consume(reportID incomingReportID: Int, bytes: [UInt8]) {
        guard isPending, incomingReportID == Int(reportID) else { return }

        var body = bytes[...]
        if body.first == reportID {
            body = body.dropFirst()
        }
        guard body.count >= 2, body[body.startIndex] == 0x02 else {
            completion = .failure("Malformed report-ID 6 response header")
            return
        }

        let lengthIndex = body.index(after: body.startIndex)
        let fragmentLength = Int(body[lengthIndex])
        guard fragmentLength <= 61 else {
            completion = .failure("Invalid report-ID 6 response length")
            return
        }

        let fragmentStart = body.index(after: lengthIndex)
        guard body.distance(from: fragmentStart, to: body.endIndex) >= fragmentLength else {
            completion = .failure("Truncated report-ID 6 response")
            return
        }

        let fragmentEnd = body.index(fragmentStart, offsetBy: fragmentLength)
        buffer.append(contentsOf: body[fragmentStart..<fragmentEnd])
        guard buffer.count <= maximumResponseBytes else {
            completion = .failure("RPC response exceeded the safety limit")
            return
        }

        consumeCompleteLines()
    }

    private func consumeCompleteLines() {
        while isPending, let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard !line.isEmpty else { continue }

            guard
                let object = try? JSONSerialization.jsonObject(with: line),
                let message = object as? [String: Any]
            else {
                completion = .failure("Malformed JSON in report-ID 6 response")
                return
            }

            guard let responseID = message["id"] as? NSNumber,
                  responseID.doubleValue == Double(expectedID) else {
                nonmatchingMessages += 1
                continue
            }

            if message["error"] != nil {
                completion = .failure("Device returned an RPC error")
                return
            }
            guard message.keys.contains("result") else {
                completion = .failure("Matching RPC response has no result")
                return
            }
            result = message["result"] as? [String: Any]
            completion = .success
        }
    }
}

private struct ProbeRequest {
    let mode: String
    let id: Int
    let json: String
}

private func makeRequest(mode: String) -> ProbeRequest {
    switch mode {
    case "--imu-status":
        return ProbeRequest(mode: mode, id: 4250,
            json: #"{"method":"device.imu","params":{},"id":4250}"# + "\n")
    case "--demo-lights":
        return ProbeRequest(
            mode: mode,
            id: 4243,
            json: "{\"method\":\"v.oai.thstatus\",\"params\":[{\"id\":0,\"c\":16777215,\"b\":1,\"e\":\"off\",\"s\":0},{\"id\":1,\"c\":1754367,\"b\":1,\"e\":\"breath\",\"s\":1},{\"id\":2,\"c\":4521796,\"b\":1,\"e\":\"off\",\"s\":0},{\"id\":3,\"c\":16753920,\"b\":1,\"e\":\"off\",\"s\":0},{\"id\":4,\"c\":16724787,\"b\":1,\"e\":\"off\",\"s\":0},{\"id\":5,\"c\":0,\"b\":0,\"e\":\"off\",\"s\":0}],\"id\":4243}\n"
        )
    case "--completion-idle":
        return ProbeRequest(
            mode: mode,
            id: 4244,
            json: "{\"method\":\"v.oai.thstatus\",\"params\":[{\"id\":0,\"c\":16777215,\"b\":1,\"e\":\"off\",\"s\":0}],\"id\":4244}\n"
        )
    case "--completion-done":
        return ProbeRequest(
            mode: mode,
            id: 4245,
            json: "{\"method\":\"v.oai.thstatus\",\"params\":[{\"id\":0,\"c\":2869614,\"b\":1,\"e\":\"off\",\"s\":0}],\"id\":4245}\n"
        )
    case "--workspace-super":
        return ProbeRequest(
            mode: mode,
            id: 4246,
            json: "{\"method\":\"host.workspace_mode\",\"params\":{\"mode\":\"super\",\"ttl_ms\":15000},\"id\":4246}\n"
        )
    case "--workspace-deepseek":
        return ProbeRequest(
            mode: mode,
            id: 4249,
            json: #"{"method":"host.workspace_mode","params":{"mode":"deepseek","ttl_ms":15000},"id":4249}"# + "\n"
        )
    case "--workspace-hermes":
        return ProbeRequest(
            mode: mode,
            id: 4248,
            json: #"{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000},"id":4248}"# + "\n"
        )
    case "--workspace-codex":
        return ProbeRequest(
            mode: mode,
            id: 4247,
            json: "{\"method\":\"host.workspace_mode\",\"params\":{\"mode\":\"codex\"},\"id\":4247}\n"
        )
    default:
        return ProbeRequest(
            mode: "--device-status",
            id: 4242,
            json: "{\"method\":\"device.status\",\"params\":{},\"id\":4242}\n"
        )
    }
}

private func framedReport(fragment: ArraySlice<UInt8>, includeReportID: Bool) -> [UInt8] {
    var report = [UInt8]()
    if includeReportID { report.append(reportID) }
    report.append(0x02)
    report.append(UInt8(fragment.count))
    report.append(contentsOf: fragment)
    report.append(contentsOf: repeatElement(0, count: 61 - fragment.count))
    return report
}

private func requireSelfTest(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("self-test failed: \(message)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

private func runSelfTest() {
    requireSelfTest(makeRequest(mode: "--imu-status").json.contains("device.imu"),
                    "IMU diagnostics must use control-only device.imu")
    requireSelfTest(
        makeRequest(mode: "--workspace-deepseek").json ==
            #"{"method":"host.workspace_mode","params":{"mode":"deepseek","ttl_ms":15000},"id":4249}"# + "\n",
        "workspace Deepseek request changed"
    )
    requireSelfTest(
        makeRequest(mode: "--workspace-hermes").json ==
            #"{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000},"id":4248}"# + "\n",
        "workspace Hermes request changed"
    )
    let expectedID = 4242
    requireSelfTest(
        makeRequest(mode: "--workspace-super").json ==
            "{\"method\":\"host.workspace_mode\",\"params\":{\"mode\":\"super\",\"ttl_ms\":15000},\"id\":4246}\n",
        "workspace SUPER request changed"
    )
    requireSelfTest(
        makeRequest(mode: "--workspace-codex").json ==
            "{\"method\":\"host.workspace_mode\",\"params\":{\"mode\":\"codex\"},\"id\":4247}\n",
        "workspace Codex request changed"
    )
    let response = Array("{\"id\":4242,\"result\":{\"ok\":true,\"padding\":\"abcdefghijklmnopqrstuvwxyz0123456789\"}}\n".utf8)
    let split = 31
    let assembler = RpcResponseAssembler(expectedID: expectedID)
    assembler.consume(
        reportID: Int(reportID),
        bytes: framedReport(fragment: response[..<split], includeReportID: false)
    )
    requireSelfTest(assembler.isPending, "completed before all fragments arrived")
    assembler.consume(
        reportID: Int(reportID),
        bytes: framedReport(fragment: response[split...], includeReportID: true)
    )
    if case .success = assembler.completion {
        requireSelfTest(assembler.result?["ok"] as? Bool == true, "lost decoded result")
        // Expected.
    } else {
        requireSelfTest(false, "did not reassemble a matching result")
    }

    let nonmatching = RpcResponseAssembler(expectedID: expectedID)
    let wrongID = Array("{\"id\":99,\"result\":{}}\n".utf8)
    nonmatching.consume(
        reportID: Int(reportID),
        bytes: framedReport(fragment: wrongID[...], includeReportID: false)
    )
    requireSelfTest(nonmatching.isPending, "accepted a nonmatching response id")
    requireSelfTest(nonmatching.nonmatchingMessages == 1, "did not count the nonmatching response")

    let rpcError = RpcResponseAssembler(expectedID: expectedID)
    let errorResponse = Array("{\"id\":4242,\"error\":{\"code\":-1}}\n".utf8)
    rpcError.consume(
        reportID: Int(reportID),
        bytes: framedReport(fragment: errorResponse[...], includeReportID: false)
    )
    if case .failure = rpcError.completion {
        // Expected.
    } else {
        requireSelfTest(false, "accepted an RPC error as success")
    }

    let missingResult = RpcResponseAssembler(expectedID: expectedID)
    let incompleteResponse = Array("{\"id\":4242}\n".utf8)
    missingResult.consume(
        reportID: Int(reportID),
        bytes: framedReport(fragment: incompleteResponse[...], includeReportID: false)
    )
    if case .failure = missingResult.completion {
        // Expected.
    } else {
        requireSelfTest(false, "accepted a matching response without a result")
    }

    print("hid_rpc_probe self-test passed")
}

private func fail(_ message: String) -> Never {
    fputs("hid_rpc_probe: \(message)\n", stderr)
    exit(EXIT_FAILURE)
}

private func runProbe(request: ProbeRequest, onResult: (([String: Any]) -> Void)? = nil) -> Int32 {
    let assembler = RpcResponseAssembler(expectedID: request.id)
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    let matching: [String: Any] = [
        kIOHIDVendorIDKey as String: vendorID,
        kIOHIDProductIDKey as String: productID,
        kIOHIDPrimaryUsagePageKey as String: 0xFF00,
        kIOHIDPrimaryUsageKey as String: 1,
    ]
    IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
    IOHIDManagerRegisterInputReportCallback(
        manager,
        { context, result, _, reportType, incomingReportID, report, reportLength in
            guard
                result == kIOReturnSuccess,
                reportType == kIOHIDReportTypeInput,
                let context
            else { return }
            let receiver = Unmanaged<RpcResponseAssembler>.fromOpaque(context).takeUnretainedValue()
            let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
            receiver.consume(reportID: Int(incomingReportID), bytes: bytes)
        },
        Unmanaged.passUnretained(assembler).toOpaque()
    )
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

    let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    guard managerResult == kIOReturnSuccess else {
        fail(String(format: "IOHIDManagerOpen failed: 0x%08X", managerResult))
    }
    defer {
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    guard let deviceSet = IOHIDManagerCopyDevices(manager), CFSetGetCount(deviceSet) > 0 else {
        fail("No 303A:8360 vendor HID device found")
    }
    guard CFSetGetCount(deviceSet) == 1 else {
        fail("Expected exactly one 303A:8360 vendor HID device")
    }

    var rawDevices = [UnsafeRawPointer?](repeating: nil, count: CFSetGetCount(deviceSet))
    CFSetGetValues(deviceSet, &rawDevices)
    let device = unsafeBitCast(rawDevices[0], to: IOHIDDevice.self)
    let deviceResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    guard deviceResult == kIOReturnSuccess else {
        fail(String(format: "IOHIDDeviceOpen failed: 0x%08X", deviceResult))
    }
    defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }

    if onResult == nil { print("mode=\(request.mode)") }
    let payload = Array(request.json.utf8)
    var payloadOffset = 0
    var reportNumber = 0
    while payloadOffset < payload.count {
        let chunkSize = min(61, payload.count - payloadOffset)
        var report = [UInt8](repeating: 0, count: 64)
        report[0] = reportID
        report[1] = 0x02
        report[2] = UInt8(chunkSize)
        report.replaceSubrange(
            3..<(3 + chunkSize),
            with: payload[payloadOffset..<(payloadOffset + chunkSize)]
        )

        let writeResult = report.withUnsafeBytes { bytes in
            IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                CFIndex(reportID),
                bytes.bindMemory(to: UInt8.self).baseAddress!,
                report.count
            )
        }
        reportNumber += 1
        if onResult == nil { print(String(format: "setReport[%d](full 64 bytes)=0x%08X", reportNumber, writeResult)) }
        guard writeResult == kIOReturnSuccess else { return EXIT_FAILURE }
        payloadOffset += chunkSize
        usleep(10_000)
    }

    let deadline = Date().addingTimeInterval(3.0)
    while assembler.isPending, Date() < deadline {
        _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }

    switch assembler.completion {
    case .success:
        if let result = assembler.result {
            if let onResult { onResult(result) }
            else if request.mode == "--imu-status",
                    let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
                    let json = String(data: data, encoding: .utf8) { print(json) }
        }
        if onResult == nil { print("rpcResponse=id=\(request.id) result=ok") }
        return EXIT_SUCCESS
    case let .failure(message):
        fputs("hid_rpc_probe: \(message) for id \(request.id)\n", stderr)
        return EXIT_FAILURE
    case .pending:
        fputs(
            "hid_rpc_probe: timed out waiting for matching RPC result; nonmatching=\(assembler.nonmatchingMessages)\n",
            stderr
        )
        return EXIT_FAILURE
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "--imu-watch" {
    guard arguments.count == 3, let seconds = Double(arguments[1]), seconds > 0, seconds <= 7200 else {
        fail("Usage: hid_rpc_probe.swift --imu-watch SECONDS OUTPUT.jsonl (maximum 7200 seconds)")
    }
    guard !FileManager.default.fileExists(atPath: arguments[2]),
          FileManager.default.createFile(atPath: arguments[2], contents: nil),
          let output = FileHandle(forWritingAtPath: arguments[2]) else { fail("Cannot create output") }
    defer { try? output.close() }
    let deadline = Date().addingTimeInterval(seconds)
    var count = 0
    while Date() < deadline {
        let started = Date()
        let status = runProbe(request: makeRequest(mode: "--imu-status")) { result in
            let row: [String: Any] = ["host_unix_s": Date().timeIntervalSince1970, "result": result]
            guard let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else {
                fail("Cannot serialize diagnostics")
            }
            output.write(data); output.write(Data([0x0a])); count += 1
        }
        if status != EXIT_SUCCESS { exit(status) }
        Thread.sleep(forTimeInterval: max(0, 0.5 - Date().timeIntervalSince(started)))
    }
    print("Saved \(count) IMU snapshots; current_ma is unavailable on C152; timestamps are not physical onset measurements")
    exit(EXIT_SUCCESS)
}
let knownModes = [
    "--imu-status",
    "--device-status",
    "--demo-lights",
    "--completion-idle",
    "--completion-done",
    "--workspace-super",
    "--workspace-deepseek",
    "--workspace-hermes",
    "--workspace-codex",
    "--self-test",
]
guard arguments.count <= 1, arguments.allSatisfy({ knownModes.contains($0) }) else {
    fail("Usage: hid_rpc_probe.swift [--imu-status|--device-status|--demo-lights|--completion-idle|--completion-done|--workspace-super|--workspace-deepseek|--workspace-hermes|--workspace-codex|--self-test] or --imu-watch SECONDS OUTPUT.jsonl")
}

let mode = arguments.first ?? "--device-status"
if mode == "--self-test" {
    runSelfTest()
    exit(EXIT_SUCCESS)
}
exit(runProbe(request: makeRequest(mode: mode)))
