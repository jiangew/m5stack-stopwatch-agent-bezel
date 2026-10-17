// Narrow API double for compiling the real transport without activating Bluetooth.
import Foundation

public protocol CBCentralManagerDelegate: AnyObject {}
public protocol CBPeripheralDelegate: AnyObject {}
public enum CBManagerState { case poweredOn, poweredOff }
public struct CBUUID: Equatable {
    public let uuidString: String
    public init(string: String) { uuidString = string.uppercased() }
}
public struct CBCharacteristicProperties: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let write = Self(rawValue: 1)
    public static let read = Self(rawValue: 2)
    public static let notify = Self(rawValue: 4)
}
public enum CBCharacteristicWriteType { case withResponse }
public final class CBCharacteristic {
    public var uuid = CBUUID(string: "")
    public var properties: CBCharacteristicProperties = []
    public var isNotifying = false
    public var value: Data?
}
public final class CBService {
    public var uuid = CBUUID(string: "")
    public var characteristics: [CBCharacteristic]?
}
public final class CBPeripheral {
    public let identifier: UUID
    public weak var delegate: CBPeripheralDelegate?
    public var services: [CBService]?
    public var discoveredServices: [CBUUID]?
    public init(identifier: UUID) { self.identifier = identifier }
    public func discoverServices(_ services: [CBUUID]?) { discoveredServices = services }
    public func discoverCharacteristics(_ characteristics: [CBUUID]?, for service: CBService) {}
    public func setNotifyValue(_ value: Bool, for characteristic: CBCharacteristic) {}
    public func readValue(for characteristic: CBCharacteristic) {}
    public func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int { 512 }
    public func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {}
}
public final class CBCentralManager {
    public static var latest: CBCentralManager!
    public weak var delegate: CBCentralManagerDelegate?
    public var state = CBManagerState.poweredOn
    public var retrieved: [CBPeripheral] = []
    public var requestedIdentifiers: [UUID] = []
    public var scanHistory: [[CBUUID]?] = []
    public var connected: [CBPeripheral] = []
    public var stoppedScans = 0
    public init(delegate: CBCentralManagerDelegate?, queue: DispatchQueue?) {
        self.delegate = delegate; Self.latest = self
    }
    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        requestedIdentifiers = identifiers; return retrieved
    }
    public func scanForPeripherals(withServices services: [CBUUID]?) { scanHistory.append(services) }
    public func connect(_ peripheral: CBPeripheral) { connected.append(peripheral) }
    public func stopScan() { stoppedScans += 1 }
    public func cancelPeripheralConnection(_ peripheral: CBPeripheral) {}
}
