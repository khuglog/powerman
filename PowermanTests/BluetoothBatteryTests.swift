import XCTest
@testable import Powerman

final class BluetoothBatteryTests: XCTestCase {
    func testParseSystemProfilerJSONWithAirPodsAndMouse() throws {
        let json = """
        {
          "SPBluetoothDataType" : [
            {
              "device_connected" : [
                {
                  "AirPods Pro" : {
                    "device_address" : "AA:BB:CC:DD:EE:01",
                    "device_minorType" : "Headphones",
                    "device_batteryLevelLeft" : "45%",
                    "device_batteryLevelRight" : "50%",
                    "device_batteryLevelCase" : "80%"
                  }
                },
                {
                  "Magic Mouse" : {
                    "device_address" : "AA:BB:CC:DD:EE:02",
                    "device_minorType" : "Mouse",
                    "device_batteryLevelMain" : "22%"
                  }
                }
              ],
              "device_not_connected" : [
                {
                  "HƯNGhobo" : {
                    "device_address" : "5C:AD:BA:02:0D:5B"
                  }
                }
              ]
            }
          ]
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let parsed = BluetoothBatteryParser.parseSystemProfilerJSON(data)
        let sorted = BluetoothBatteryParser.mergeAndSort(parsed)

        XCTAssertEqual(sorted.count, 3)
        // Lowest battery connected device comes first (Magic Mouse 22% < AirPods 45%)
        XCTAssertEqual(sorted[0].name, "Magic Mouse")
        XCTAssertEqual(sorted[0].category, .mouse)
        XCTAssertEqual(sorted[0].displayPercentage, 22)
        XCTAssertTrue(sorted[0].isConnected)

        XCTAssertEqual(sorted[1].name, "AirPods Pro")
        XCTAssertEqual(sorted[1].category, .earbuds)
        XCTAssertEqual(sorted[1].displayPercentage, 45)
        XCTAssertEqual(sorted[1].subBatterySummary, "L 45% • R 50% • Case 80%")

        XCTAssertEqual(sorted[2].name, "HƯNGhobo")
        XCTAssertFalse(sorted[2].isConnected)
        XCTAssertNil(sorted[2].displayPercentage)
    }

    func testParseIORegistryHIDAndMergeDeduplicatesByAddress() {
        let hidList: [[String: Any]] = [
            [
                "Product": "Magic Keyboard",
                "Transport": "Bluetooth",
                "DeviceAddress": "aa-bb-cc-dd-ee-03",
                "BatteryPercent": 78
            ],
            [
                "Product": "USB Wired Mouse",
                "Transport": "USB",
                "BatteryPercent": 100
            ]
        ]

        let parsedHID = BluetoothBatteryParser.parseIORegistryHID(hidList)
        XCTAssertEqual(parsedHID.count, 1)
        XCTAssertEqual(parsedHID[0].id, "AA:BB:CC:DD:EE:03")
        XCTAssertEqual(parsedHID[0].category, .keyboard)
        XCTAssertEqual(parsedHID[0].displayPercentage, 78)

        let duplicateWithoutBattery = BluetoothDeviceBattery(
            id: "AA:BB:CC:DD:EE:03",
            name: "Magic Keyboard",
            category: .keyboard,
            batteryPercentage: nil,
            leftBattery: nil,
            rightBattery: nil,
            caseBattery: nil,
            isApproximate: false,
            isConnected: true,
            lastUpdated: Date()
        )

        let merged = BluetoothBatteryParser.mergeAndSort([duplicateWithoutBattery] + parsedHID)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].displayPercentage, 78)
    }

    @MainActor
    func testDevicePreferencesPinHideAndReorder() {
        let suiteName = "com.powerman.devices.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let d1 = BluetoothDeviceBattery(
            id: "DEV-1", name: "Mouse", category: .mouse, batteryPercentage: 40,
            leftBattery: nil, rightBattery: nil, caseBattery: nil,
            isApproximate: false, isConnected: true, lastUpdated: Date()
        )
        let d2 = BluetoothDeviceBattery(
            id: "DEV-2", name: "Keyboard", category: .keyboard, batteryPercentage: 80,
            leftBattery: nil, rightBattery: nil, caseBattery: nil,
            isApproximate: false, isConnected: true, lastUpdated: Date()
        )

        let settings = AppSettings(defaults: defaults)
        settings.togglePinDevice("DEV-1")
        settings.togglePinDevice("DEV-2")
        settings.toggleHideDevice("DEV-1")
        settings.setDeviceAlertThreshold(20, for: "DEV-2")

        XCTAssertEqual(settings.orderedPinnedDevices(from: [d1, d2]).map(\.id), ["DEV-1", "DEV-2"])
        settings.movePinnedDevice(id: "DEV-2", direction: -1, allDevices: [d1, d2])
        XCTAssertEqual(settings.orderedPinnedDevices(from: [d1, d2]).map(\.id), ["DEV-2", "DEV-1"])

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertTrue(reloaded.preference(for: "DEV-1").isHiddenFromDropdown)
        XCTAssertEqual(reloaded.preference(for: "DEV-2").lowBatteryAlertThreshold, 20)
        XCTAssertEqual(reloaded.orderedPinnedDevices(from: [d1, d2]).map(\.id), ["DEV-2", "DEV-1"])
    }
}
