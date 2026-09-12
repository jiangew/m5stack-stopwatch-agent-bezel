import AppKit
import CoreBluetooth
import Darwin
import Foundation

private let quotaServiceUUID = CBUUID(string: "7F0D4E66-2AC2-4A71-BFBE-4EF61A0E5C01")
private let quotaWriteUUID = CBUUID(string: "7F0D4E66-2AC2-4A71-BFBE-4EF61A0E5C02")
private let hidServiceUUID = CBUUID(string: "1812")

private struct QuotaSnapshot: Codable {
    let remainingPercent: Double
    let resetInSeconds: Int

    enum CodingKeys: String, CodingKey {
        case remainingPercent = "remaining_percent"
        case resetInSeconds = "reset_in_seconds"
    }
}

private enum CompanionError: LocalizedError {
    case appServer(String)
    case malformedRateLimits(String)
    case bluetooth(String)
    case usage(String)

    var errorDescription: String? {
        switch self {
        case .appServer(let message), .malformedRateLimits(let message),
             .bluetooth(let message), .usage(let message):
            return message
        }
    }
}

private enum BLEWritePurpose {
    case quota
    case enterBootloader
}

private enum BLEWriteOutcome {
    case completed
    case commandAcknowledgedAndDisconnected
}

private final class AppServerClient {
    private let process = Process()
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    private let condition = NSCondition()
    private var receiveBuffer = Data()
    private var responses: [Int: [String: Any]] = [:]
    private var stderrTail = ""
    private var nextID = 1

    init(codexPath: String) throws {
        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consume(handle.availableData)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self, let text = String(data: handle.availableData, encoding: .utf8), !text.isEmpty else {
                return
            }
            condition.lock()
            stderrTail = String((stderrTail + text).suffix(2_000))
            condition.unlock()
        }

        do {
            try process.run()
        } catch {
            throw CompanionError.appServer("无法启动 Codex App Server（\(codexPath)）：\(error.localizedDescription)")
        }

        try send([
            "method": "initialize",
            "id": 0,
            "params": [
                "clientInfo": [
                    "name": "codex_watch_companion",
                    "title": "Codex Watch Companion",
                    "version": "0.1.0",
                ],
                "capabilities": [
                    "optOutNotificationMethods": [
                        "item/agentMessage/delta",
                        "item/reasoning/textDelta",
                    ],
                ],
            ],
        ])
        _ = try waitForResponse(id: 0, timeout: 12)
        try send(["method": "initialized", "params": [:]])
    }

    deinit {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        if process.isRunning {
            process.terminate()
        }
    }

    func readRateLimits() throws -> QuotaSnapshot {
        let id = nextID
        nextID += 1
        try send(["method": "account/rateLimits/read", "id": id, "params": [:]])
        let response = try waitForResponse(id: id, timeout: 20)

        if let error = response["error"] as? [String: Any] {
            throw CompanionError.appServer("Codex 额度请求失败：\(error["message"] ?? error)")
        }
        guard let result = response["result"] as? [String: Any] else {
            throw CompanionError.malformedRateLimits("Codex 没有返回 rateLimits result")
        }

        let bucket: [String: Any]?
        if let buckets = result["rateLimitsByLimitId"] as? [String: Any],
           let codex = buckets["codex"] as? [String: Any] {
            bucket = codex
        } else if let legacy = result["rateLimits"] as? [String: Any],
                  (legacy["limitId"] as? String) == "codex" {
            bucket = legacy
        } else {
            bucket = nil
        }

        guard let bucket,
              let primary = bucket["primary"] as? [String: Any],
              let usedNumber = primary["usedPercent"] as? NSNumber,
              let resetNumber = primary["resetsAt"] as? NSNumber else {
            throw CompanionError.malformedRateLimits("没有找到 Codex primary 额度窗口")
        }

        let used = min(100, max(0, usedNumber.doubleValue))
        let resetIn = max(0, Int(resetNumber.doubleValue - Date().timeIntervalSince1970))
        return QuotaSnapshot(
            remainingPercent: 100 - used,
            resetInSeconds: resetIn
        )
    }

    private func send(_ object: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: object, options: [])
        data.append(0x0A)
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
    }

    private func waitForResponse(id: Int, timeout: TimeInterval) throws -> [String: Any] {
        let deadline = Date().addingTimeInterval(timeout)
        _ = waitForAppServerState(condition: condition, deadline: deadline) {
            if responses[id] != nil { return .responseAvailable }
            return process.isRunning ? .waiting : .processExited
        }

        condition.lock()
        defer { condition.unlock() }
        if let response = responses.removeValue(forKey: id) {
            return response
        }

        let detail = stderrTail.isEmpty ? "无错误输出" : stderrTail.trimmingCharacters(in: .whitespacesAndNewlines)
        throw CompanionError.appServer("等待 Codex App Server 响应超时：\(detail)")
    }

    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        condition.lock()
        receiveBuffer.append(data)

        while let newline = receiveBuffer.firstIndex(of: 0x0A) {
            let line = receiveBuffer[..<newline]
            receiveBuffer.removeSubrange(...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let id = (object["id"] as? NSNumber)?.intValue else {
                continue
            }
            responses[id] = object
        }
        condition.broadcast()
        condition.unlock()
    }
}

private final class BLEQuotaWriter: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var manager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private let payload: Data
    private let verbose: Bool
    private let expectedIdentifier: UUID?
    private let purpose: BLEWritePurpose
    private var finished = false
    private var result: Result<BLEWriteOutcome, Error>?
    private var pendingPeripherals: [CBPeripheral] = []
    private var rejectedIdentifiers = Set<UUID>()
    private var writeAcknowledgedAt: Date?

    init(
        payload: Data,
        verbose: Bool,
        expectedIdentifier: UUID?,
        purpose: BLEWritePurpose = .quota
    ) {
        self.payload = payload
        self.verbose = verbose
        self.expectedIdentifier = expectedIdentifier
        self.purpose = purpose
        super.init()
    }

    func write(timeout: TimeInterval = 40) throws -> BLEWriteOutcome {
        guard payload.count <= 512 else {
            throw CompanionError.bluetooth("额度 payload 超过固件的 512-byte 上限")
        }
        manager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )

        let discoveryDeadline = Date().addingTimeInterval(timeout)
        while !finished {
            let now = Date()
            if let writeAcknowledgedAt {
                if now.timeIntervalSince(writeAcknowledgedAt) >= 5.0 {
                    finish(.failure(CompanionError.bluetooth(
                        "bootloader 命令已获 ATT ACK，但设备在 5 秒内没有断开；未确认进入下载模式"
                    )))
                    continue
                }
            } else if now >= discoveryDeadline {
                break
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        if !finished {
            if let peripheral {
                manager.cancelPeripheralConnection(peripheral)
            }
            throw CompanionError.bluetooth("未在 \(Int(timeout)) 秒内发现带有专属额度服务的 StopWatch")
        }
        guard let result else {
            throw CompanionError.bluetooth("BLE 写入没有返回结果")
        }
        return try result.get()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // A bonded HOGP peripheral can already be connected by macOS while
            // CoreBluetooth has never cached this app's private quota service.
            // In that state it stops advertising and therefore cannot be found
            // by a scan or retrieveConnectedPeripherals(withServices:). An
            // explicitly pinned CoreBluetooth identifier is still retrievable;
            // connect to that exact object and discover the service directly.
            let pinned = expectedIdentifier.map {
                central.retrievePeripherals(withIdentifiers: [$0])
            } ?? []
            let quotaConnected = central.retrieveConnectedPeripherals(withServices: [quotaServiceUUID])
            let hidConnected = central.retrieveConnectedPeripherals(withServices: [hidServiceUUID])
            pendingPeripherals = uniquePeripherals(pinned + quotaConnected + hidConnected)
                .filter(matchesExpectedDevice)
            if let peripheral = nextPendingPeripheral() {
                if verbose {
                    if purpose == .enterBootloader {
                        print("BLE 已开启；找到已绑定的 StopWatch…")
                    } else {
                        print("BLE 已开启；找到已连接的 StopWatch [\(peripheral.identifier)]…")
                    }
                }
                use(peripheral, with: central)
            } else {
                if verbose {
                    if let expectedIdentifier {
                        if purpose == .enterBootloader {
                            print("BLE 已开启；只扫描已绑定的 StopWatch…")
                        } else {
                            print("BLE 已开启；只扫描已绑定的 StopWatch [\(expectedIdentifier)]…")
                        }
                    } else {
                        print("BLE 已开启；扫描 StopWatch 专属服务（demo 发现模式）…")
                    }
                }
                // Scan broadly because a bonded HID connection can retain an
                // older service cache after firmware gains the private quota
                // service. Candidate names/UUIDs are checked before connect,
                // and the service itself is verified before any write.
                central.scanForPeripherals(withServices: nil)
            }
        case .unauthorized:
            finish(.failure(CompanionError.bluetooth("macOS 未授权此程序使用蓝牙")))
        case .unsupported:
            finish(.failure(CompanionError.bluetooth("这台 Mac 不支持 CoreBluetooth")))
        case .poweredOff:
            finish(.failure(CompanionError.bluetooth("Mac 蓝牙当前已关闭")))
        case .resetting, .unknown:
            break
        @unknown default:
            finish(.failure(CompanionError.bluetooth("未知蓝牙状态：\(central.state.rawValue)")))
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard self.peripheral == nil else { return }
        guard matchesExpectedDevice(peripheral) else {
            if verbose {
                if purpose == .enterBootloader {
                    print("忽略未绑定的 peripheral")
                } else {
                    print("忽略未绑定的 peripheral [\(peripheral.identifier)]")
                }
            }
            return
        }
        if expectedIdentifier == nil {
            let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            guard name == "Codex Micro" else { return }
        }
        guard !rejectedIdentifiers.contains(peripheral.identifier) else { return }
        if verbose {
            let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "未命名设备"
            if purpose == .enterBootloader {
                print("发现 \(name) RSSI=\(RSSI)")
            } else {
                print("发现 \(name) [\(peripheral.identifier)] RSSI=\(RSSI)")
            }
        }
        use(peripheral, with: central)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if verbose { print("BLE 已连接；发现额度服务…") }
        peripheral.discoverServices([quotaServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if expectedIdentifier == nil {
            rejectAndContinue(peripheral, reason: "连接失败：\(safeErrorDescription(error))")
        } else {
            finish(.failure(CompanionError.bluetooth("连接 StopWatch 失败：\(safeErrorDescription(error))")))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            finish(.failure(CompanionError.bluetooth("发现 StopWatch 服务失败：\(safeErrorDescription(error))")))
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == quotaServiceUUID }) else {
            if expectedIdentifier == nil {
                rejectAndContinue(peripheral, reason: "没有 StopWatch 专属额度服务")
            } else {
                finish(.failure(CompanionError.bluetooth("已绑定设备没有暴露预期的额度服务")))
            }
            return
        }
        peripheral.discoverCharacteristics([quotaWriteUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            finish(.failure(CompanionError.bluetooth("发现额度写入特征失败：\(safeErrorDescription(error))")))
            return
        }
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == quotaWriteUUID }) else {
            finish(.failure(CompanionError.bluetooth("设备没有暴露预期的额度写入特征")))
            return
        }

        if characteristic.properties.contains(.write) {
            if verbose {
                let label = purpose == .enterBootloader ? "bootloader 命令" : "额度快照"
                print("写入 \(payload.count) bytes \(label)…")
            }
            peripheral.writeValue(payload, for: characteristic, type: .withResponse)
        } else if characteristic.properties.contains(.writeWithoutResponse) {
            guard purpose == .quota else {
                finish(.failure(CompanionError.bluetooth("bootloader 命令要求带响应的 ATT 写入")))
                return
            }
            peripheral.writeValue(payload, for: characteristic, type: .withoutResponse)
            finish(.success(.completed))
        } else {
            finish(.failure(CompanionError.bluetooth("额度特征不可写")))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            finish(.failure(CompanionError.bluetooth("BLE 写入失败：\(safeErrorDescription(error))")))
        } else if purpose == .enterBootloader {
            writeAcknowledgedAt = Date()
            if verbose { print("bootloader 命令已收到 ATT ACK；等待设备重启…") }
        } else {
            finish(.success(.completed))
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard self.peripheral === peripheral else { return }
        if purpose == .enterBootloader, writeAcknowledgedAt != nil {
            finish(.success(.commandAcknowledgedAndDisconnected))
            return
        }
        guard !finished else { return }
        finish(.failure(CompanionError.bluetooth(
            "StopWatch 在写入完成前断开：\(safeErrorDescription(error, fallback: "连接已关闭"))"
        )))
    }

    private func finish(_ result: Result<BLEWriteOutcome, Error>) {
        guard !finished else { return }
        self.result = result
        finished = true
        manager?.stopScan()
        if let peripheral {
            manager?.cancelPeripheralConnection(peripheral)
        }
    }

    private func use(_ peripheral: CBPeripheral, with central: CBCentralManager) {
        guard self.peripheral == nil else { return }
        self.peripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        if verbose { print("CoreBluetooth peripheral state=\(peripheral.state.rawValue)") }
        if peripheral.state == .connected {
            if verbose { print("BLE 已由 macOS 连接；直接发现额度服务…") }
            peripheral.discoverServices([quotaServiceUUID])
            return
        }
        // retrieveConnectedPeripherals reports a system-level link. This
        // process still calls connect so CoreBluetooth establishes app-level
        // ownership and delivers didConnect before service discovery.
        central.connect(peripheral)
    }

    private func matchesExpectedDevice(_ peripheral: CBPeripheral) -> Bool {
        guard let expectedIdentifier else { return true }
        return peripheral.identifier == expectedIdentifier
    }

    private func safeErrorDescription(_ error: Error?, fallback: String = "未知错误") -> String {
        guard let error else { return fallback }
        if purpose == .enterBootloader {
            // NSError domain/code preserves actionable CoreBluetooth context
            // without echoing an arbitrary localized string that could embed
            // the bound peripheral identifier.
            let cocoaError = error as NSError
            return "\(cocoaError.domain) code \(cocoaError.code)"
        }
        return error.localizedDescription
    }

    private func uniquePeripherals(_ peripherals: [CBPeripheral]) -> [CBPeripheral] {
        var seen = Set<UUID>()
        return peripherals.filter { seen.insert($0.identifier).inserted }
    }

    private func nextPendingPeripheral() -> CBPeripheral? {
        while !pendingPeripherals.isEmpty {
            let candidate = pendingPeripherals.removeFirst()
            if !rejectedIdentifiers.contains(candidate.identifier) {
                return candidate
            }
        }
        return nil
    }

    private func rejectAndContinue(_ rejected: CBPeripheral, reason: String) {
        if verbose {
            if purpose == .enterBootloader {
                print("跳过候选设备：\(reason)")
            } else {
                print("跳过 [\(rejected.identifier)]：\(reason)")
            }
        }
        rejectedIdentifiers.insert(rejected.identifier)
        manager.cancelPeripheralConnection(rejected)
        peripheral = nil
        if let next = nextPendingPeripheral() {
            use(next, with: manager)
        } else {
            manager.scanForPeripherals(withServices: nil)
        }
    }
}

struct Options {
    var codexPath = defaultCodexPath()
    var demo = false
    var jsonOnly = false
    var watch = false
    var interval: TimeInterval = 60
    var verbose = false
    var deviceIdentifier: UUID?
    var enterBootloader = false

    var startsHIDShortcutListener: Bool {
        watch && !demo && !jsonOnly && !enterBootloader
    }

    var startsWorkspaceModeCoordinator: Bool {
        startsHIDShortcutListener
    }
}

private func executableInPath(named executable: String) -> String? {
    let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
    for directory in path.split(separator: ":", omittingEmptySubsequences: true) {
        let candidate = URL(fileURLWithPath: String(directory))
            .appendingPathComponent(executable).path
        if FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
    }
    return nil
}

private func defaultCodexPath() -> String {
    if let pathBinary = executableInPath(named: "codex") {
        return pathBinary
    }

    let knownLocations = [
        "/Applications/ChatGPT.app/Contents/Resources/codex",
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex",
    ]
    for candidate in knownLocations where FileManager.default.isExecutableFile(atPath: candidate) {
        return candidate
    }

    // Preserve a useful path in the eventual process error. Background installs
    // should always pass an explicit --codex-path in their local LaunchAgent.
    return "/usr/local/bin/codex"
}

func parseOptions(_ arguments: [String] = CommandLine.arguments) throws -> Options {
    var options = Options()
    var index = 1
    while index < arguments.count {
        switch arguments[index] {
        case "--codex-path":
            index += 1
            guard index < arguments.count else { throw CompanionError.usage("--codex-path 需要路径") }
            options.codexPath = arguments[index]
        case "--demo":
            options.demo = true
        case "--json-only":
            options.jsonOnly = true
        case "--watch":
            options.watch = true
        case "--enter-bootloader":
            options.enterBootloader = true
        case "--interval":
            index += 1
            guard index < arguments.count, let seconds = Double(arguments[index]), seconds >= 10 else {
                throw CompanionError.usage("--interval 需要不少于 10 秒的数字")
            }
            options.interval = seconds
        case "--device-id":
            index += 1
            guard index < arguments.count, let identifier = UUID(uuidString: arguments[index]) else {
                throw CompanionError.usage("--device-id 需要有效的 CoreBluetooth UUID")
            }
            options.deviceIdentifier = identifier
        case "--verbose", "-v":
            options.verbose = true
        case "--help", "-h":
            print("""
            用法: codex-watch-companion --device-id UUID [--watch] [--interval 60] [-v]

              --watch          持续刷新；默认只写入一次
              --interval N     额度刷新间隔，至少 10 秒，默认 60
              --demo           使用合成额度，不启动 Codex App Server
              --json-only      只打印 JSON，不连接蓝牙
              --device-id UUID 只向这块已绑定的 StopWatch 写入
              --enter-bootloader
                              请求 USB-mic 固件重启到串口下载模式
              --codex-path P   指定 codex CLI 路径
              -v, --verbose    打印 App Server/BLE 进度
            """)
            exit(0)
        default:
            throw CompanionError.usage("未知参数：\(arguments[index])；使用 --help 查看用法")
        }
        index += 1
    }
    return options
}

private func formatReset(seconds: Int) -> String {
    if seconds >= 86_400 { return "\(seconds / 86_400)d \((seconds % 86_400) / 3_600)h" }
    if seconds >= 3_600 { return "\(seconds / 3_600)h \((seconds % 3_600) / 60)m" }
    return "\(max(0, seconds) / 60)m"
}

@MainActor
private func run() throws {
    setbuf(stdout, nil)
    setbuf(stderr, nil)
    // launchd starts this executable directly from its .app bundle. Creating
    // the background NSApplication registers that process with the logged-in
    // Aqua session so CoreBluetooth can deliver delegate callbacks reliably.
    _ = NSApplication.shared
    NSApplication.shared.setActivationPolicy(.prohibited)
    let options = try parseOptions()
    if options.enterBootloader {
        guard options.deviceIdentifier != nil else {
            throw CompanionError.usage("--enter-bootloader 必须同时提供 --device-id")
        }
        guard !options.demo, !options.watch, !options.jsonOnly else {
            throw CompanionError.usage("--enter-bootloader 不能与 --demo、--watch 或 --json-only 同时使用")
        }

        let payload = Data(#"{"op":"enter_bootloader","version":1,"confirm":true}"#.utf8)
        let outcome = try BLEQuotaWriter(
            payload: payload,
            verbose: options.verbose,
            expectedIdentifier: options.deviceIdentifier,
            purpose: .enterBootloader
        ).write()
        switch outcome {
        case .commandAcknowledgedAndDisconnected:
            print("bootloader 命令已获 ATT ACK，随后 BLE 断开；仅在新 USB 串口出现后继续刷写")
        case .completed:
            throw CompanionError.bluetooth("bootloader 命令返回了意外的写入结果")
        }
        return
    }
    if !options.demo, !options.jsonOnly, options.deviceIdentifier == nil {
        throw CompanionError.usage("写入真实额度必须提供 --device-id；先运行 --demo --verbose 查看 StopWatch UUID")
    }

    var workspaceCycleController: WorkspaceCycleController?
    var shortcutRouter: WorkspaceCommandRouter?
    var shortcutListener: HIDShortcutListener?
    var workspaceModeCoordinator: WorkspaceModeCoordinator?
    var navigationDiagnosticSignal: NavigationDiagnosticSignal?
    var navigationLifecycle: WorkspaceNavigationLifecycle?
    var watchTermination: WatchTerminationSignal?
    if options.startsHIDShortcutListener,
       options.startsWorkspaceModeCoordinator {
        let diagnostics = NavigationDiagnostics(log: { fputs("\($0)\n", stderr) })
        let workspace = NSWorkspaceApplications()
        let toggler = WorkspaceCycleController(
            workspace: workspace,
            observer: SystemForegroundApplicationObserver(),
            scheduler: SystemWorkspaceModeScheduler(),
            log: { fputs("快捷键：\($0)\n", stderr) }
        )
        let keyEmitter = SystemProcessTargetedKeyEmitter(diagnose: { diagnostics.record($0) })
        let keyLifecycle = WorkspaceNavigationLifecycle(observer: SystemForegroundApplicationObserver(), emitter: keyEmitter)
        let router = WorkspaceCommandRouter(
            workspace: workspace,
            toggler: toggler,
            emitter: keyEmitter,
            accessibility: SystemAccessibilityTrustChecker(),
            log: { fputs("快捷键：\($0)\n", stderr) },
            diagnose: { diagnostics.record($0) }
        )
        let coordinator = WorkspaceModeCoordinator(
            interaction: toggler,
            log: { fputs("屏幕：\($0)\n", stderr) }
        )
        toggler.start()
        coordinator.start()
        keyLifecycle.start()
        let listener = HIDShortcutListener(
            eventHandler: { [weak router] event in
                diagnostics.recordInput(event)
                router?.handle(event)
            },
            log: { fputs("快捷键：\($0)\n", stderr) },
            workspaceSenderMatched: { [weak coordinator, weak keyLifecycle] sender in
                keyLifecycle?.cancel()
                coordinator?.attach(sender)
            },
            workspaceSenderRemoved: { [weak coordinator, weak keyLifecycle] deviceKey in
                keyLifecycle?.cancel()
                coordinator?.detach(deviceKey: deviceKey)
            }
        )
        do {
            try listener.start()
            let diagnosticSignal = NavigationDiagnosticSignal(diagnostics: diagnostics)
            diagnosticSignal.start()
            navigationDiagnosticSignal = diagnosticSignal
            navigationLifecycle = keyLifecycle
            workspaceCycleController = toggler
            shortcutRouter = router
            shortcutListener = listener
            workspaceModeCoordinator = coordinator
            let termination = WatchTerminationSignal {
                keyLifecycle.stop()
                diagnosticSignal.stop()
                toggler.stop()
                coordinator.stop()
                listener.stop()
                exit(EXIT_SUCCESS)
            }
            termination.start()
            watchTermination = termination
        } catch {
            keyLifecycle.stop()
            toggler.stop()
            coordinator.stop()
            fputs("快捷键不可用：\(error.localizedDescription)\n", stderr)
        }
    }
    defer {
        watchTermination?.stop()
        watchTermination = nil
        navigationLifecycle?.stop()
        navigationLifecycle = nil
        navigationDiagnosticSignal?.stop()
        navigationDiagnosticSignal = nil
        workspaceCycleController?.stop()
        workspaceCycleController = nil
        workspaceModeCoordinator?.stop()
        withExtendedLifetime(shortcutRouter) {
            shortcutListener?.stop()
        }
        workspaceModeCoordinator = nil
        shortcutListener = nil
        shortcutRouter = nil
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    var client: AppServerClient?

    try runQuotaLoop(
        watch: options.watch,
        interval: options.interval,
        cycle: {
            if !options.demo, client == nil {
                client = try AppServerClient(codexPath: options.codexPath)
            }
            let snapshot: QuotaSnapshot
            if options.demo {
                snapshot = QuotaSnapshot(remainingPercent: 59, resetInSeconds: 3_600)
            } else {
                snapshot = try client!.readRateLimits()
            }
            let payload = try encoder.encode(snapshot)
            guard let json = String(data: payload, encoding: .utf8) else {
                throw CompanionError.malformedRateLimits("无法编码额度 JSON")
            }
            print(json)
            if !options.jsonOnly {
                _ = try BLEQuotaWriter(
                    payload: payload,
                    verbose: options.verbose,
                    expectedIdentifier: options.deviceIdentifier
                ).write()
                print("✓ 已写入 StopWatch：剩余 \(Int(snapshot.remainingPercent.rounded()))%，\(formatReset(seconds: snapshot.resetInSeconds)) 后重置")
            }
        },
        wait: { seconds in
            RunLoop.current.run(until: Date().addingTimeInterval(seconds))
        },
        reportError: { error in
            client = nil
            fputs("额度同步失败，将重试：\(error.localizedDescription)\n", stderr)
        }
    )
}

do {
    try MainActor.assumeIsolated {
        try run()
    }
} catch {
    fputs("错误：\(error.localizedDescription)\n", stderr)
    exit(1)
}
