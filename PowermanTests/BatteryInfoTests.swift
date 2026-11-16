import XCTest
@testable import Powerman

final class BatteryInfoTests: XCTestCase {
    func testParseAppleSiliconBatterySnapshot() {
        let iops: [String: Any] = [
            "Current Capacity": 65,
            "Max Capacity": 100,
            "Power Source State": "Battery Power",
            "Is Charging": false,
            "Is Charged": false,
            "Time to Empty": 162
        ]

        let smartBattery: [String: Any] = [
            "AppleRawCurrentCapacity": 3717,
            "AppleRawMaxCapacity": 5719,
            "DesignCapacity": 6249,
            "MaxCapacity": 100,
            "CurrentCapacity": 65,
            "CycleCount": 167,
            "DesignCycleCount9C": 1000,
            "Temperature": 30645, // 306.45 K = 33.3 C
            "Voltage": 11850,
            "InstantAmperage": -1250,
            "ExternalConnected": false,
            "IsCharging": false
        ]

        let info = BatterySnapshotParser.parse(iops: iops, smartBattery: smartBattery)

        XCTAssertTrue(info.hasBattery)
        XCTAssertEqual(info.percentage, 65)
        XCTAssertFalse(info.isCharging)
        XCTAssertFalse(info.isPluggedIn)
        XCTAssertEqual(info.chargingState, .onBattery)
        XCTAssertEqual(info.timeRemainingMinutes, 162)
        XCTAssertEqual(info.formattedTimeRemaining, "2h 42m")
        XCTAssertEqual(info.cycleCount, 167)
        XCTAssertEqual(info.ratedCycleCount, 1000)
        XCTAssertEqual(info.maxCapacityMah, 5719)
        XCTAssertEqual(info.designCapacityMah, 6249)
        XCTAssertEqual(info.roundedHealthPercentage, 92)
        XCTAssertEqual(info.healthStatus, .good)
        XCTAssertEqual(info.temperatureCelsius ?? 0, 33.3, accuracy: 0.1)
        XCTAssertEqual(info.temperatureStatus, .normal)
        XCTAssertEqual(info.wattage ?? 0, 14.8125, accuracy: 0.01)
    }

    func testParseChargingWithAdapter() {
        let iops: [String: Any] = [
            "Current Capacity": 80,
            "Max Capacity": 100,
            "Power Source State": "AC Power",
            "Is Charging": true,
            "Time to Full Charge": 35
        ]

        let smartBattery: [String: Any] = [
            "AppleRawMaxCapacity": 4800,
            "DesignCapacity": 6249,
            "CycleCount": 420,
            "Temperature": 31315, // 40.0 C
            "Voltage": 12400,
            "InstantAmperage": 3000,
            "ExternalConnected": true,
            "IsCharging": true,
            "AdapterDetails": [
                "Watts": 96,
                "Name": "96W USB-C Power Adapter"
            ]
        ]

        let info = BatterySnapshotParser.parse(iops: iops, smartBattery: smartBattery)

        XCTAssertEqual(info.chargingState, .charging)
        XCTAssertTrue(info.isPluggedIn)
        XCTAssertEqual(info.formattedTimeRemaining, "35m")
        XCTAssertEqual(info.roundedHealthPercentage, 77)
        XCTAssertEqual(info.healthStatus, .fair)
        XCTAssertEqual(info.temperatureCelsius ?? 0, 40.0, accuracy: 0.1)
        XCTAssertEqual(info.temperatureStatus, .warm)
        XCTAssertEqual(info.adapterWatts, 96)
        XCTAssertEqual(info.adapterName, "96W USB-C Power Adapter")
    }

    func testParseNilInputsReturnsPlaceholder() {
        let info = BatterySnapshotParser.parse(iops: nil, smartBattery: nil)
        XCTAssertFalse(info.hasBattery)
        XCTAssertEqual(info.percentage, 0)
        XCTAssertEqual(info.formattedTimeRemaining, "--")
    }

    func testParseAppleSiliconNestedBatteryDataAndPack() {
        let iops: [String: Any] = [
            "Current Capacity": 65,
            "Max Capacity": 100,
            "Power Source State": "Battery Power",
            "Is Charging": false,
            "Time to Empty": 304
        ]

        let smartBattery: [String: Any] = [
            "CycleCount": 167,
            "DesignCycleCount9C": 1000,
            "MaxCapacity": 100,
            "CurrentCapacity": 65,
            "Voltage": 11839,
            "InstantAmperage": -947,
            "ExternalConnected": false,
            "IsCharging": false,
            "BatteryData": [
                "DesignCapacity": 6249,
                "FullChargeCapacity": 5705,
                "NominalChargeCapacity": 5857,
                "RemainingCapacity": 3546,
                "BatteryPower": -11211
            ]
        ]

        let smartBatteryPack: [String: Any] = [
            "BatteryData": [
                "Temperature": 3239,
                "VirtualTemperature": 3239,
                "AppleRawMaxCapacity": 5693,
                "AppleRawCurrentCapacity": 3651,
                "DesignCapacity": 6249
            ]
        ]

        let info = BatterySnapshotParser.parse(
            iops: iops,
            smartBattery: smartBattery,
            smartBatteryPack: smartBatteryPack
        )

        XCTAssertTrue(info.hasBattery)
        XCTAssertEqual(info.percentage, 65)
        XCTAssertEqual(info.cycleCount, 167)
        XCTAssertEqual(info.designCapacityMah, 6249)
        XCTAssertEqual(info.maxCapacityMah, 5693)
        XCTAssertEqual(info.currentCapacityMah, 3651)
        XCTAssertEqual(info.roundedHealthPercentage, 91)
        XCTAssertEqual(info.healthStatus, .good)
        XCTAssertEqual(info.temperatureCelsius ?? 0, 32.4, accuracy: 0.1)
        XCTAssertEqual(info.temperatureStatus, .normal)
        XCTAssertEqual(info.wattage ?? 0, 11.21, accuracy: 0.05)
    }

    @MainActor
    func testAppSettingsPersistence() {
        let suiteName = "com.powerman.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.menuBarIconStyle = .batteryIndicator
        settings.menuBarDisplayMode = .timeRemaining
        settings.menuBarColorMode = .monochrome
        settings.menuBarSize = .large
        settings.statusColorsEnabled = false

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.menuBarIconStyle, .batteryIndicator)
        XCTAssertEqual(reloaded.menuBarDisplayMode, .timeRemaining)
        XCTAssertEqual(reloaded.menuBarColorMode, .monochrome)
        XCTAssertEqual(reloaded.menuBarSize, .large)
        XCTAssertFalse(reloaded.statusColorsEnabled)
    }
}
