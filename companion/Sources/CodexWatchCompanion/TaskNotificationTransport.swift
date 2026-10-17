import CoreBluetooth
import Foundation

/// Dedicated persistent connection to the explicitly bound C152. Device-side GATT
/// permissions enforce encryption; CoreBluetooth does not expose pairing status.
final class TaskNotificationTransport: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let service = CBUUID(string: "7F0D4E66-2AC2-4A71-BFBE-4EF61A0E5C11")
    static let cardUUID = CBUUID(string: "7F0D4E66-2AC2-4A71-BFBE-4EF61A0E5C12")
    static let actionUUID = CBUUID(string: "7F0D4E66-2AC2-4A71-BFBE-4EF61A0E5C13")
    // Existing firmware advertises quota/HID; the notification UUID exists only in GATT.
    static let advertisedService = CBUUID(string: "7F0D4E66-2AC2-4A71-BFBE-4EF61A0E5C01")
    private let identifier: UUID
    private let receive: (TaskNotificationAction) -> Void
    private let connectionChanged: () -> Void
    private let log: (String) -> Void
    private var manager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var cardCharacteristic: CBCharacteristic?
    private var actionCharacteristic: CBCharacteristic?
    private var active = false
    private var ready = false
    private var writing = false
    private var seen: Set<Data> = []
    private var lastReadAt = Date.distantPast
    private var reconnectTimer: Timer?
    init(identifier: UUID, receive: @escaping (TaskNotificationAction) -> Void, connectionChanged: @escaping () -> Void, log: @escaping (String) -> Void) {
        self.identifier = identifier; self.receive = receive; self.connectionChanged = connectionChanged; self.log = log
        super.init()
    }
    func start() { active = true; manager = CBCentralManager(delegate: self, queue: .main) }
    func stop() {
        active = false; reconnectTimer?.invalidate(); reconnectTimer = nil
        manager?.stopScan()
        if let peripheral { manager?.cancelPeripheralConnection(peripheral) }
        reset(); manager?.delegate = nil; manager = nil
    }
    private func reset() { ready = false; writing = false; seen.removeAll(); cardCharacteristic = nil; actionCharacteristic = nil }
    private func connect() {
        guard active, manager.state == .poweredOn else { return }
        if let found = manager.retrievePeripherals(withIdentifiers: [identifier]).first {
            peripheral = found; found.delegate = self; manager.connect(found)
        } else { manager.scanForPeripherals(withServices: [Self.advertisedService]) }
    }
    private func retry() {
        reset(); peripheral?.delegate = nil; peripheral = nil
        guard active else { return }
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in self?.connect() }
    }
    private func reject() {
        reset()
        if let peripheral { manager.cancelPeripheralConnection(peripheral) }
        log("通知 BLE 未就绪；等待安全重连")
    }
    /// Returns true only when one complete <=512-byte ATT withResponse write starts.
    /// That ACK never resolves a native decision.
    func pollActions() {
        guard ready, let peripheral, let actionCharacteristic, Date().timeIntervalSince(lastReadAt) >= 1 else { return }
        lastReadAt = Date(); peripheral.readValue(for: actionCharacteristic)
    }
    func send(_ payload: Data) -> Bool {
        guard active, ready, !writing, payload.count <= 512, let peripheral, let cardCharacteristic,
              payload.count <= peripheral.maximumWriteValueLength(for: .withResponse) else { return false }
        writing = true
        peripheral.writeValue(payload, for: cardCharacteristic, type: .withResponse)
        return true
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        reset(); connectionChanged()
        if central.state == .poweredOn { connect() }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard peripheral.identifier == identifier else { return }
        central.stopScan(); self.peripheral = peripheral; peripheral.delegate = self; central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard active, peripheral === self.peripheral, peripheral.identifier == identifier else { return }
        reset(); connectionChanged(); peripheral.discoverServices([Self.service])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) { connectionChanged(); retry() }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral === self.peripheral else { return }; connectionChanged(); retry()
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral === self.peripheral, error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == Self.service }) else { reject(); return }
        peripheral.discoverCharacteristics([Self.cardUUID, Self.actionUUID], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral === self.peripheral, service.uuid == Self.service, error == nil,
              let card = service.characteristics?.first(where: { $0.uuid == Self.cardUUID }), card.properties.contains(.write),
              let action = service.characteristics?.first(where: { $0.uuid == Self.actionUUID }), action.properties.contains(.read), action.properties.contains(.notify) else { reject(); return }
        cardCharacteristic = card; actionCharacteristic = action
        peripheral.setNotifyValue(true, for: action)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral === self.peripheral, characteristic === actionCharacteristic, error == nil, characteristic.isNotifying else { reject(); return }
        ready = true
        // Do not read stored action value on reconnect. Notifications must carry current g.
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral === self.peripheral, characteristic === cardCharacteristic else { return }
        writing = false
        if error != nil { reject() }
        else { pollActions() }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard ready, peripheral === self.peripheral, characteristic === actionCharacteristic, error == nil else { return }
        guard let data = characteristic.value, data.count <= 160,
              let action = try? JSONDecoder().decode(TaskNotificationAction.self, from: data), action.v == 1 else {
            // Short-MTU notify is only a hint; bounded periodic read recovers the complete value.
            pollActions(); return
        }
        if action.seq != nil { receive(action); return }
        guard !seen.contains(data), seen.count < 1024 else { return }
        seen.insert(data); receive(action)
    }
}
