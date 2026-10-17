import CoreBluetooth
import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

@main struct TaskNotificationTransportRegression {
    static func main() {
        let bound = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let transport = TaskNotificationTransport(identifier: bound, receive: { _ in }, connectionChanged: {}, log: { _ in })
        transport.start()
        let central = CBCentralManager.latest!
        transport.centralManagerDidUpdateState(central)
        require(central.requestedIdentifiers == [bound], "retrieve only the explicitly bound device")
        // Actual firmware advertisement fixture: HID 1812 and existing private quota UUID.
        let advertised = [CBUUID(string: "1812"), CBUUID(string: "7F0D4E66-2AC2-4A71-BFBE-4EF61A0E5C01")]
        let filter = central.scanHistory.first!!
        require(!filter.isEmpty && filter.allSatisfy { advertised.contains($0) }, "fallback scans only services actually advertised by firmware")
        require(!filter.contains(TaskNotificationTransport.service), "dedicated notification service is GATT only")
        let unrelated = CBPeripheral(identifier: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!)
        transport.centralManager(central, didDiscover: unrelated, advertisementData: [:], rssi: 0)
        require(central.connected.isEmpty && central.stoppedScans == 0, "unbound advertisements cannot be connected")
        let target = CBPeripheral(identifier: bound)
        transport.centralManager(central, didDiscover: target, advertisementData: [:], rssi: 0)
        require(central.connected.count == 1 && central.connected.first === target, "matching bound advertisement connects")
        require(central.stoppedScans == 1, "stop scanning once the bound target is found")
        transport.centralManager(central, didConnect: target)
        require(target.discoveredServices == [TaskNotificationTransport.service], "discover dedicated GATT only after matching identity")
        transport.stop()

        let cached = TaskNotificationTransport(identifier: bound, receive: { _ in }, connectionChanged: {}, log: { _ in })
        cached.start()
        let cachedCentral = CBCentralManager.latest!
        cachedCentral.retrieved = [target]
        cached.centralManagerDidUpdateState(cachedCentral)
        require(cachedCentral.scanHistory.isEmpty && cachedCentral.connected.first === target, "cached bound-device retrieval still connects without scan")
        cached.stop()
        print("PASS actual notification transport: empty-cache advertised-service fallback, exact binding, dedicated GATT discovery, cached retrieval")
    }
}
