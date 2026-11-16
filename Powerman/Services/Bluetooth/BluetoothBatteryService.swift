import CoreBluetooth
import Foundation
import IOBluetooth
import IOKit
import IOKit.ps

@MainActor
protocol BluetoothBatteryMonitoring: AnyObject {
    var devices: [BluetoothDeviceBattery] { get }
    func startMonitoring(onUpdate: @escaping @MainActor ([BluetoothDeviceBattery]) -> Void)
    func stopMonitoring()
    func refreshNow()
}

enum BluetoothBatteryParser {
    static func parseSystemProfilerJSON(_ data: Data, now: Date = Date()) -> [BluetoothDeviceBattery] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = root["SPBluetoothDataType"] as? [[String: Any]]
        else {
            return []
        }

        var results: [BluetoothDeviceBattery] = []
        for entry in entries {
            if let connected = entry["device_connected"] as? [[String: Any]] {
                for item in connected {
                    if let parsed = parseSystemProfilerDeviceItem(item, isConnected: true, now: now) {
                        results.append(parsed)
                    }
                }
            }
            if let disconnected = entry["device_not_connected"] as? [[String: Any]] {
                for item in disconnected {
                    if let parsed = parseSystemProfilerDeviceItem(item, isConnected: false, now: now) {
                        results.append(parsed)
                    }
                }
            }
        }
        return results
    }

    private static func parseSystemProfilerDeviceItem(
        _ item: [String: Any],
        isConnected: Bool,
        now: Date
    ) -> BluetoothDeviceBattery? {
        guard let (name, detailsAny) = item.first,
              let details = detailsAny as? [String: Any] else {
            return nil
        }

        let address = (details["device_address"] as? String)
        let id = normalizedID(address: address, fallbackName: name)
        let minorType = details["device_minorType"] as? String
        let category = DeviceCategory.infer(fromMinorType: minorType, name: name)

        let mainPct = parsePercentage(details["device_batteryLevelMain"])
            ?? parsePercentage(details["device_batteryLevel"])
        let leftPct = parsePercentage(details["device_batteryLevelLeft"])
        let rightPct = parsePercentage(details["device_batteryLevelRight"])
        let casePct = parsePercentage(details["device_batteryLevelCase"])

        return BluetoothDeviceBattery(
            id: id,
            name: name,
            category: category,
            batteryPercentage: mainPct,
            leftBattery: leftPct,
            rightBattery: rightPct,
            caseBattery: casePct,
            isApproximate: false,
            isConnected: isConnected,
            lastUpdated: now
        )
    }

    static func parseIORegistryHID(_ propertiesList: [[String: Any]], now: Date = Date()) -> [BluetoothDeviceBattery] {
        var results: [BluetoothDeviceBattery] = []

        for props in propertiesList {
            guard let pct = parsePercentage(props["BatteryPercent"]) else { continue }
            let name = (props["Product"] as? String)
                ?? (props["DeviceName"] as? String)
                ?? "Bluetooth Device"

            let transport = (props["Transport"] as? String ?? "").lowercased()
            // Include Bluetooth and wireless HID accessories; skip non-wireless built-ins if any.
            if !transport.isEmpty && !transport.contains("bluetooth") && !transport.contains("wireless") {
                continue
            }

            let address = (props["DeviceAddress"] as? String) ?? (props["SerialNumber"] as? String)
            let id = normalizedID(address: address, fallbackName: name)
            let category = DeviceCategory.infer(fromMinorType: nil, name: name)

            results.append(
                BluetoothDeviceBattery(
                    id: id,
                    name: name,
                    category: category,
                    batteryPercentage: pct,
                    leftBattery: nil,
                    rightBattery: nil,
                    caseBattery: nil,
                    isApproximate: false,
                    isConnected: true,
                    lastUpdated: now
                )
            )
        }

        return results
    }

    static func parseIOPSAccessories(_ descriptions: [[String: Any]], now: Date = Date()) -> [BluetoothDeviceBattery] {
        var results: [BluetoothDeviceBattery] = []

        for desc in descriptions {
            let type = desc[kIOPSTypeKey] as? String
            if type == kIOPSInternalBatteryType { continue }

            guard let name = desc[kIOPSNameKey] as? String else { continue }
            guard let current = parsePercentage(desc[kIOPSCurrentCapacityKey]),
                  let maxVal = parsePercentage(desc[kIOPSMaxCapacityKey]),
                  maxVal > 0 else {
                continue
            }

            let pct = min(max(Int(((Double(current) / Double(maxVal)) * 100.0).rounded()), 0), 100)
            let address = desc["Accessory Identifier"] as? String
            let id = normalizedID(address: address, fallbackName: name)
            let category = DeviceCategory.infer(fromMinorType: desc["Accessory Category"] as? String, name: name)

            results.append(
                BluetoothDeviceBattery(
                    id: id,
                    name: name,
                    category: category,
                    batteryPercentage: pct,
                    leftBattery: nil,
                    rightBattery: nil,
                    caseBattery: nil,
                    isApproximate: false,
                    isConnected: true,
                    lastUpdated: now
                )
            )
        }

        return results
    }

    static func mergeAndSort(_ devices: [BluetoothDeviceBattery]) -> [BluetoothDeviceBattery] {
        var merged: [String: BluetoothDeviceBattery] = [:]

        for device in devices {
            if let existing = merged[device.id] {
                merged[device.id] = BluetoothDeviceBattery(
                    id: existing.id,
                    name: existing.name.isEmpty ? device.name : existing.name,
                    category: existing.category == .other ? device.category : existing.category,
                    batteryPercentage: device.batteryPercentage ?? existing.batteryPercentage,
                    leftBattery: device.leftBattery ?? existing.leftBattery,
                    rightBattery: device.rightBattery ?? existing.rightBattery,
                    caseBattery: device.caseBattery ?? existing.caseBattery,
                    isApproximate: existing.isApproximate && device.isApproximate,
                    isConnected: existing.isConnected || device.isConnected,
                    lastUpdated: max(existing.lastUpdated, device.lastUpdated)
                )
            } else {
                merged[device.id] = device
            }
        }

        return merged.values.sorted { lhs, rhs in
            if lhs.isConnected != rhs.isConnected {
                return lhs.isConnected && !rhs.isConnected
            }
            switch (lhs.displayPercentage, rhs.displayPercentage) {
            case let (l?, r?):
                if l != r { return l < r } // Lowest battery first!
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func normalizedID(address: String?, fallbackName: String) -> String {
        if let address {
            let cleaned = address
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
                .replacingOccurrences(of: "-", with: ":")
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        return "name:\(fallbackName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    static func parsePercentage(_ value: Any?) -> Int? {
        if let intVal = value as? Int {
            return (0...100).contains(intVal) ? intVal : nil
        }
        if let num = value as? NSNumber {
            let val = num.intValue
            return (0...100).contains(val) ? val : nil
        }
        if let str = value as? String {
            let digits = str.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "~", with: "")
            if let val = Int(digits), (0...100).contains(val) {
                return val
            }
        }
        return nil
    }
}

@MainActor
final class BluetoothBatteryService: NSObject, BluetoothBatteryMonitoring {
    private(set) var devices: [BluetoothDeviceBattery] = []

    private var updateHandler: (@MainActor ([BluetoothDeviceBattery]) -> Void)?
    private var refreshTimer: Timer?
    private var connectNotification: IOBluetoothUserNotification?
    private var isRefreshing = false

    private var centralManager: CBCentralManager?
    private var discoveredBLEPeripherals: [UUID: CBPeripheral] = [:]
    private var bleBatteryLevels: [String: BluetoothDeviceBattery] = [:]

    private static let batteryServiceUUID = CBUUID(string: "180F")
    private static let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")

    func startMonitoring(onUpdate: @escaping @MainActor ([BluetoothDeviceBattery]) -> Void) {
        stopMonitoring()
        self.updateHandler = onUpdate

        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(handleBluetoothConnect(_:device:))
        )

        centralManager = CBCentralManager(delegate: self, queue: .main)
        refreshNow()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshNow()
            }
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        connectNotification?.unregister()
        connectNotification = nil
        centralManager = nil
        discoveredBLEPeripherals.removeAll()
        updateHandler = nil
    }

    func refreshNow() {
        guard !isRefreshing else { return }
        isRefreshing = true

        queryConnectedBLEBatteries()

        let ioRegDevices = Self.readIORegistryHIDDevices()
        let iopsDevices = Self.readIOPSAccessoryDevices()
        let pairedFallback = Self.readIOBluetoothPairedDevices()
        let bleDevices = Array(bleBatteryLevels.values)

        Task.detached(priority: .utility) {
            let spDevices = Self.runSystemProfilerBluetooth()
            await MainActor.run { [weak self] in
                guard let self else { return }
                let combined = BluetoothBatteryParser.mergeAndSort(
                    spDevices + ioRegDevices + iopsDevices + bleDevices + pairedFallback
                )
                self.devices = combined
                self.isRefreshing = false
                self.updateHandler?(combined)
            }
        }
    }

    @objc private func handleBluetoothConnect(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        device.register(forDisconnectNotification: self, selector: #selector(handleBluetoothDisconnect(_:device:)))
        refreshNow()
    }

    @objc private func handleBluetoothDisconnect(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        refreshNow()
    }

    private func queryConnectedBLEBatteries() {
        guard let central = centralManager, central.state == .poweredOn else { return }
        let peripherals = central.retrieveConnectedPeripherals(withServices: [Self.batteryServiceUUID])
        for peripheral in peripherals {
            discoveredBLEPeripherals[peripheral.identifier] = peripheral
            peripheral.delegate = self
            central.connect(peripheral, options: nil)
        }
    }

    private static func readIORegistryHIDDevices() -> [BluetoothDeviceBattery] {
        var matchingIterator: io_iterator_t = 0
        guard let matchingDict = IOServiceMatching("IORegistryEntry") else { return [] }
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &matchingIterator)
        guard kr == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(matchingIterator) }

        var rawDicts: [[String: Any]] = []
        var service = IOIteratorNext(matchingIterator)
        while service != IO_OBJECT_NULL {
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = properties?.takeRetainedValue() as? [String: Any],
               dict["BatteryPercent"] != nil {
                rawDicts.append(dict)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(matchingIterator)
        }

        return BluetoothBatteryParser.parseIORegistryHID(rawDicts)
    }

    private static func readIOPSAccessoryDevices() -> [BluetoothDeviceBattery] {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return []
        }

        var descriptions: [[String: Any]] = []
        for source in list {
            if let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] {
                descriptions.append(desc)
            }
        }
        return BluetoothBatteryParser.parseIOPSAccessories(descriptions)
    }

    private static func readIOBluetoothPairedDevices() -> [BluetoothDeviceBattery] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }

        let now = Date()
        return paired.compactMap { dev in
            guard let name = dev.name, !name.isEmpty else { return nil }
            let id = BluetoothBatteryParser.normalizedID(address: dev.addressString, fallbackName: name)
            let category = inferCategory(device: dev, name: name)
            return BluetoothDeviceBattery(
                id: id,
                name: name,
                category: category,
                batteryPercentage: nil,
                leftBattery: nil,
                rightBattery: nil,
                caseBattery: nil,
                isApproximate: false,
                isConnected: dev.isConnected(),
                lastUpdated: now
            )
        }
    }

    private static func inferCategory(device: IOBluetoothDevice, name: String) -> DeviceCategory {
        let inferred = DeviceCategory.infer(fromMinorType: nil, name: name)
        if inferred != .other { return inferred }

        if device.deviceClassMajor == UInt32(kBluetoothDeviceClassMajorPhone) {
            return .phone
        }
        if device.deviceClassMajor == UInt32(kBluetoothDeviceClassMajorAudio) {
            return .headphones
        }
        if device.deviceClassMajor == UInt32(kBluetoothDeviceClassMajorPeripheral) {
            let minor = device.deviceClassMinor
            if minor == UInt32(kBluetoothDeviceClassMinorPeripheral1Pointing) {
                return .mouse
            }
            if minor == UInt32(kBluetoothDeviceClassMinorPeripheral1Keyboard) {
                return .keyboard
            }
        }
        return .other
    }

    private nonisolated static func runSystemProfilerBluetooth() -> [BluetoothDeviceBattery] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            return BluetoothBatteryParser.parseSystemProfilerJSON(data)
        } catch {
            return []
        }
    }
}

extension BluetoothBatteryService: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if central.state == .poweredOn {
                self.queryConnectedBLEBatteries()
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.batteryServiceUUID])
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { return }
        for service in services where service.uuid == Self.batteryServiceUUID {
            peripheral.discoverCharacteristics([Self.batteryLevelCharacteristicUUID], for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil, let characteristics = service.characteristics else { return }
        for char in characteristics where char.uuid == Self.batteryLevelCharacteristicUUID {
            peripheral.readValue(for: char)
            peripheral.setNotifyValue(true, for: char)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == Self.batteryLevelCharacteristicUUID,
              let data = characteristic.value,
              let byte = data.first else {
            return
        }

        let level = min(max(Int(byte), 0), 100)
        let name = peripheral.name ?? "BLE Device"
        let uuidStr = peripheral.identifier.uuidString

        Task { @MainActor [weak self] in
            guard let self else { return }
            let device = BluetoothDeviceBattery(
                id: uuidStr,
                name: name,
                category: DeviceCategory.infer(fromMinorType: nil, name: name),
                batteryPercentage: level,
                leftBattery: nil,
                rightBattery: nil,
                caseBattery: nil,
                isApproximate: false,
                isConnected: true,
                lastUpdated: Date()
            )
            self.bleBatteryLevels[uuidStr] = device
            self.devices = BluetoothBatteryParser.mergeAndSort(self.devices + [device])
            self.updateHandler?(self.devices)
        }
    }
}
