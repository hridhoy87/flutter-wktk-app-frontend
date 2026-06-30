import Foundation
import CoreBluetooth

enum BleConnectionState: String {
    case searching = "SEARCHING"
    case connecting = "CONNECTING"
    case connected = "CONNECTED"
    case disconnected = "DISCONNECTED"
}

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var discoveredPeripheral: CBPeripheral?
    private var pttCharacteristic: CBCharacteristic?

    private let serviceUUID = CBUUID(string: "A1000000-0000-1000-8000-00805F9B34FB")
    private let characteristicUUID = CBUUID(string: "A1010000-0000-1000-8000-00805F9B34FB")

    @Published var connectionState: BleConnectionState = .disconnected

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        if centralManager.state == .poweredOn {
            connectionState = .searching
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }

    func sendPttEvent(pressed: Bool) {
        guard let peripheral = discoveredPeripheral, let characteristic = pttCharacteristic else { return }

        let value: UInt8 = pressed ? 0x01 : 0x00
        let data = Data([value])

        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            connectionState = .disconnected
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveredPeripheral = peripheral
        centralManager.stopScan()
        connectionState = .connecting
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        discoveredPeripheral = nil
        pttCharacteristic = nil
        startScanning() // Auto-reconnect
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                pttCharacteristic = characteristic
                connectionState = .connected
            }
        }
    }
}
