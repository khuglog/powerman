import XCTest
@testable import Powerman

@MainActor
private final class MockChargeLimitService: ChargeLimitManaging {
    var status = ChargeLimitStatus(
        isSupported: true,
        isEnabled: false,
        limitPercentage: 80,
        availableLimits: [80, 85, 90, 95, 100],
        lastError: nil
    )

    func fetchStatus() -> ChargeLimitStatus {
        status
    }

    func setEnabled(_ enabled: Bool, targetLimit: Int) -> ChargeLimitStatus {
        status.isEnabled = enabled
        if enabled {
            status.limitPercentage = ChargeLimitHelpers.snapToSupportedLimit(targetLimit, availableLimits: status.availableLimits)
        }
        return status
    }

    func setLimit(_ percentage: Int) -> ChargeLimitStatus {
        status.limitPercentage = ChargeLimitHelpers.snapToSupportedLimit(percentage, availableLimits: status.availableLimits)
        return status
    }
}

@MainActor
private final class StubBatteryService: BatteryMonitoring {
    var currentBattery: BatteryInfo
    private var handler: (@MainActor (BatteryInfo) -> Void)?

    init(initial: BatteryInfo) {
        self.currentBattery = initial
    }

    func startMonitoring(onUpdate: @escaping @MainActor (BatteryInfo) -> Void) {
        self.handler = onUpdate
        onUpdate(currentBattery)
    }

    func stopMonitoring() {
        handler = nil
    }

    @discardableResult
    func refreshNow() -> BatteryInfo {
        currentBattery
    }

    func push(_ info: BatteryInfo) {
        currentBattery = info
        handler?(info)
    }
}

@MainActor
private final class StubBluetoothService: BluetoothBatteryMonitoring {
    var devices: [BluetoothDeviceBattery] = []
    func startMonitoring(onUpdate: @escaping @MainActor ([BluetoothDeviceBattery]) -> Void) {}
    func stopMonitoring() {}
    func refreshNow() {}
}

@MainActor
private final class StubEnergyService: EnergyConsuming {
    var topConsumers: [AppEnergyUsage] = []
    func refresh(completion: (@MainActor @Sendable ([AppEnergyUsage]) -> Void)?) { completion?([]) }
}

@MainActor
private final class StubAlertPresenter: AlertPresenting {
    var activeAlert: ActiveAlertPresentation?
    func present(_ alert: ActiveAlertPresentation, bubbleSize: AlertBubbleSize, glowIntensity: ScreenEdgeGlowIntensity, onDismiss: (() -> Void)?) {
        activeAlert = alert
    }
    func dismiss() { activeAlert = nil }
}

@MainActor
private final class StubSystemService: SystemIntegrating {
    var isLaunchAtLoginEnabled: Bool = false
    var launchAtLoginRequiresApproval: Bool = false
    var isAccessibilityGranted: Bool = false
    var isLowPowerModeEnabled: Bool = false
    func setLaunchAtLogin(_ enabled: Bool) -> String? { nil }
    func applyAppearance(_ appearance: AppAppearanceOption) {}
    func requestAccessibilityPermission() {}
    func startLowPowerObserver(onChange: @escaping @MainActor @Sendable (Bool) -> Void) {}
    func stopLowPowerObserver() {}
    func setLowPowerMode(_ enabled: Bool, restoreBrightness: Bool) async -> Bool { true }
    func startNotificationDismisser() {}
    func stopNotificationDismisser() {}
}

final class ChargeLimitTests: XCTestCase {
    func testSnapToSupportedLimit() {
        XCTAssertEqual(ChargeLimitHelpers.snapToSupportedLimit(75), 80)
        XCTAssertEqual(ChargeLimitHelpers.snapToSupportedLimit(82), 80)
        XCTAssertEqual(ChargeLimitHelpers.snapToSupportedLimit(83), 85)
        XCTAssertEqual(ChargeLimitHelpers.snapToSupportedLimit(90), 90)
        XCTAssertEqual(ChargeLimitHelpers.snapToSupportedLimit(98), 100)
        XCTAssertEqual(ChargeLimitHelpers.snapToSupportedLimit(87, availableLimits: [80, 100]), 80)
    }

    @MainActor
    func testAppStateChargeLimitLifecycle() {
        let mockCharge = MockChargeLimitService()
        let tempHistory = FileManager.default.temporaryDirectory
            .appendingPathComponent("powerman_cl_hist_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempHistory) }

        let suiteName = "com.powerman.cl.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let appState = AppState(
            historyStore: JSONBatteryHistoryStore(fileURL: tempHistory),
            chargeLimitService: mockCharge,
            settings: AppSettings(defaults: defaults)
        )

        appState.refreshChargeLimit()
        XCTAssertTrue(appState.chargeLimitStatus.isSupported)
        XCTAssertFalse(appState.chargeLimitStatus.isEnabled)

        appState.setChargeLimitEnabled(true)
        XCTAssertTrue(appState.chargeLimitStatus.isEnabled)
        XCTAssertEqual(appState.chargeLimitStatus.limitPercentage, 80)

        appState.setChargeLimitPercentage(89)
        XCTAssertEqual(appState.chargeLimitStatus.limitPercentage, 90)

        appState.setChargeLimitEnabled(false)
        XCTAssertFalse(appState.chargeLimitStatus.isEnabled)
    }

    @MainActor
    func testInstantPlugInStatusSyncAndChargeLimitPause() {
        func makeBattery(percentage: Int, isPluggedIn: Bool, isCharging: Bool) -> BatteryInfo {
            BatteryInfo(
                percentage: percentage,
                isCharging: isCharging,
                isPluggedIn: isPluggedIn,
                isFullyCharged: false,
                timeRemainingMinutes: nil,
                cycleCount: 167,
                ratedCycleCount: 1000,
                designCapacityMah: 6000,
                maxCapacityMah: 5700,
                currentCapacityMah: 3000,
                temperatureCelsius: 32.0,
                voltageMv: 12000,
                amperageMa: isCharging ? 2000 : -1000,
                batteryPowerMw: isCharging ? 24000 : -12000,
                adapterWatts: isPluggedIn ? 60 : nil,
                adapterName: isPluggedIn ? "pd charger" : nil,
                hasBattery: true,
                lastUpdated: Date()
            )
        }

        let tempHistory = FileManager.default.temporaryDirectory
            .appendingPathComponent("powerman_instant_hist_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempHistory) }

        let suiteName = "com.powerman.instant.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let stubBattery = StubBatteryService(initial: makeBattery(percentage: 40, isPluggedIn: false, isCharging: false))
        let mockCharge = MockChargeLimitService()
        let appState = AppState(
            batteryService: stubBattery,
            bluetoothService: StubBluetoothService(),
            historyStore: JSONBatteryHistoryStore(fileURL: tempHistory),
            energyService: StubEnergyService(),
            chargeLimitService: mockCharge,
            systemService: StubSystemService(),
            settings: AppSettings(defaults: defaults),
            alertPresenter: StubAlertPresenter()
        )
        appState.start()
        defer { appState.stop() }

        XCTAssertFalse(appState.menuBarShowsChargingStatus)
        XCTAssertFalse(appState.isPluggedChargeTransitionActive)

        // 1. Just plugged in at 40% while USB-PD negotiates (ExternalConnected=true, IsCharging=false).
        stubBattery.push(makeBattery(percentage: 40, isPluggedIn: true, isCharging: false))
        XCTAssertTrue(appState.isPluggedChargeTransitionActive)
        XCTAssertTrue(appState.menuBarShowsChargingStatus)

        // 2. Hardware finishes PD negotiation and begins active charging.
        stubBattery.push(makeBattery(percentage: 40, isPluggedIn: true, isCharging: true))
        XCTAssertFalse(appState.isPluggedChargeTransitionActive)
        XCTAssertTrue(appState.menuBarShowsChargingStatus)

        // 3. Charger unplugged clears charging status immediately.
        stubBattery.push(makeBattery(percentage: 40, isPluggedIn: false, isCharging: false))
        XCTAssertFalse(appState.isPluggedChargeTransitionActive)
        XCTAssertFalse(appState.menuBarShowsChargingStatus)

        // 4. Plugged in at 82% while 80% Charge Limit pauses charging must NOT show fake charging.
        appState.setChargeLimitEnabled(true)
        stubBattery.push(makeBattery(percentage: 82, isPluggedIn: true, isCharging: false))
        XCTAssertTrue(appState.isPausedAtChargeLimit)
        XCTAssertFalse(appState.isPluggedChargeTransitionActive)
        XCTAssertFalse(appState.menuBarShowsChargingStatus)
    }
}
