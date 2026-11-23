import XCTest
@testable import Powerman

@MainActor
private final class MockSleepPreventionService: SleepPreventing {
    var isPreventingSleep: Bool = false
    var activeAllowsScreenSaver: Bool?
    var shouldSucceed: Bool = true
    var beginCount: Int = 0
    var endCount: Int = 0
    var lastReason: String?

    func beginPreventingSystemSleep(reason: String, allowScreenSaver: Bool) -> Bool {
        beginCount += 1
        lastReason = reason
        guard shouldSucceed else { return false }
        isPreventingSleep = true
        activeAllowsScreenSaver = allowScreenSaver
        return true
    }

    func endPreventingSystemSleep() {
        endCount += 1
        isPreventingSleep = false
        activeAllowsScreenSaver = nil
    }
}

@MainActor
private final class MockKeepAwakeBatteryService: BatteryMonitoring {
    var currentBattery: BatteryInfo
    private var onUpdate: (@MainActor (BatteryInfo) -> Void)?

    init(initial: BatteryInfo) {
        self.currentBattery = initial
    }

    func startMonitoring(onUpdate: @escaping @MainActor (BatteryInfo) -> Void) {
        self.onUpdate = onUpdate
        onUpdate(currentBattery)
    }

    func stopMonitoring() {
        onUpdate = nil
    }

    func refreshNow() -> BatteryInfo {
        currentBattery
    }

    func emit(_ info: BatteryInfo) {
        currentBattery = info
        onUpdate?(info)
    }
}

private func makeBattery(percentage: Int, isPluggedIn: Bool = false, isCharging: Bool = false) -> BatteryInfo {
    BatteryInfo(
        percentage: percentage,
        isCharging: isCharging,
        isPluggedIn: isPluggedIn,
        isFullyCharged: false,
        timeRemainingMinutes: 120,
        cycleCount: 50,
        ratedCycleCount: 1000,
        designCapacityMah: 5000,
        maxCapacityMah: 4900,
        currentCapacityMah: 49 * percentage,
        temperatureCelsius: 30.0,
        voltageMv: 12000,
        amperageMa: isCharging ? 1500 : -800,
        batteryPowerMw: 10000,
        adapterWatts: isPluggedIn ? 67 : nil,
        adapterName: nil,
        hasBattery: true,
        lastUpdated: Date()
    )
}

final class KeepAwakeTests: XCTestCase {
    @MainActor
    func testKeepAwakeSettingsDefaultsPersistenceAndSliderMapping() {
        let suiteName = "com.powerman.keepawake.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.keepAwakeDuration, .hour1)
        XCTAssertTrue(settings.keepAwakeStopBelow10Percent)
        XCTAssertTrue(settings.keepAwakeStopOnSleepOrShutdown)
        XCTAssertTrue(settings.keepAwakeAllowScreenSaver)

        settings.keepAwakeDuration = .hours4
        settings.keepAwakeStopBelow10Percent = false
        settings.keepAwakeStopOnSleepOrShutdown = false
        settings.keepAwakeAllowScreenSaver = false

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.keepAwakeDuration, .hours4)
        XCTAssertFalse(reloaded.keepAwakeStopBelow10Percent)
        XCTAssertFalse(reloaded.keepAwakeStopOnSleepOrShutdown)
        XCTAssertFalse(reloaded.keepAwakeAllowScreenSaver)

        XCTAssertEqual(KeepAwakeDuration.fromSliderIndex(-5), .minutes15)
        XCTAssertEqual(KeepAwakeDuration.fromSliderIndex(999), .indefinite)
        for duration in KeepAwakeDuration.allCases {
            XCTAssertEqual(KeepAwakeDuration.fromSliderIndex(duration.sliderIndex), duration)
        }

        XCTAssertEqual(KeepAwakeDuration.formattedRemaining(65), "01:05")
        XCTAssertEqual(KeepAwakeDuration.formattedRemaining(3661), "1:01:01")
    }

    @MainActor
    func testKeepAwakeTimedLifecycleAndExpiration() {
        let mockSleep = MockSleepPreventionService()
        let tempHistory = FileManager.default.temporaryDirectory
            .appendingPathComponent("powerman_ka_hist_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempHistory) }

        let suiteName = "com.powerman.ka.lifecycle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.keepAwakeDuration = .minutes30

        let appState = AppState(
            historyStore: JSONBatteryHistoryStore(fileURL: tempHistory),
            sleepPreventionService: mockSleep,
            settings: settings
        )

        var menuBarUpdates = 0
        appState.onMenuBarUpdate = { menuBarUpdates += 1 }

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        appState.setKeepAwakeEnabled(true, now: start)

        XCTAssertTrue(appState.isKeepAwakeActive)
        XCTAssertTrue(mockSleep.isPreventingSleep)
        XCTAssertEqual(mockSleep.activeAllowsScreenSaver, true)
        XCTAssertEqual(mockSleep.beginCount, 1)
        XCTAssertEqual(appState.keepAwakeEndDate, start.addingTimeInterval(1800))
        XCTAssertEqual(menuBarUpdates, 1)

        appState.expireKeepAwakeIfNeeded(now: start.addingTimeInterval(1799))
        XCTAssertTrue(appState.isKeepAwakeActive)
        XCTAssertTrue(mockSleep.isPreventingSleep)

        appState.expireKeepAwakeIfNeeded(now: start.addingTimeInterval(1800))
        XCTAssertFalse(appState.isKeepAwakeActive)
        XCTAssertFalse(mockSleep.isPreventingSleep)
        XCTAssertNil(appState.keepAwakeEndDate)
        XCTAssertEqual(mockSleep.endCount, 1)
        XCTAssertEqual(menuBarUpdates, 2)
    }

    @MainActor
    func testKeepAwakeDurationAdjustmentWhileActiveAndIndefiniteMode() {
        let mockSleep = MockSleepPreventionService()
        let tempHistory = FileManager.default.temporaryDirectory
            .appendingPathComponent("powerman_ka_indef_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempHistory) }

        let suiteName = "com.powerman.ka.indef.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.keepAwakeDuration = .minutes15

        let appState = AppState(
            historyStore: JSONBatteryHistoryStore(fileURL: tempHistory),
            sleepPreventionService: mockSleep,
            settings: settings
        )

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        appState.setKeepAwakeEnabled(true, now: t0)
        XCTAssertEqual(appState.keepAwakeEndDate, t0.addingTimeInterval(900))

        let t1 = t0.addingTimeInterval(120)
        appState.setKeepAwakeDuration(.hours2, now: t1)
        XCTAssertTrue(appState.isKeepAwakeActive)
        XCTAssertEqual(appState.keepAwakeEndDate, t1.addingTimeInterval(7200))

        let t2 = t1.addingTimeInterval(60)
        appState.setKeepAwakeDuration(.indefinite, now: t2)
        XCTAssertTrue(appState.isKeepAwakeActive)
        XCTAssertNil(appState.keepAwakeEndDate)

        appState.expireKeepAwakeIfNeeded(now: t2.addingTimeInterval(100_000))
        XCTAssertTrue(appState.isKeepAwakeActive)
        XCTAssertTrue(mockSleep.isPreventingSleep)

        appState.setKeepAwakeEnabled(false)
        XCTAssertFalse(appState.isKeepAwakeActive)
        XCTAssertFalse(mockSleep.isPreventingSleep)
    }

    @MainActor
    func testKeepAwakeLowBatterySleepShutdownAndScreenSaverOptions() {
        let mockSleep = MockSleepPreventionService()
        let mockBattery = MockKeepAwakeBatteryService(initial: makeBattery(percentage: 15))
        let tempHistory = FileManager.default.temporaryDirectory
            .appendingPathComponent("powerman_ka_guards_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempHistory) }

        let suiteName = "com.powerman.ka.guards.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let appState = AppState(
            batteryService: mockBattery,
            historyStore: JSONBatteryHistoryStore(fileURL: tempHistory),
            sleepPreventionService: mockSleep,
            settings: AppSettings(defaults: defaults)
        )
        appState.start()
        defer { appState.stop() }

        // 1. Live screen saver toggle updates assertion mode without losing active session
        appState.setKeepAwakeEnabled(true)
        XCTAssertTrue(appState.isKeepAwakeActive)
        XCTAssertEqual(mockSleep.activeAllowsScreenSaver, true)

        appState.setKeepAwakeAllowScreenSaver(false)
        XCTAssertTrue(appState.isKeepAwakeActive)
        XCTAssertEqual(mockSleep.activeAllowsScreenSaver, false)

        // 2. Dropping below 10% on battery stops Keep Awake automatically
        mockBattery.emit(makeBattery(percentage: 9, isPluggedIn: false, isCharging: false))
        XCTAssertFalse(appState.isKeepAwakeActive)
        XCTAssertFalse(mockSleep.isPreventingSleep)
        XCTAssertTrue(appState.isKeepAwakeBlockedByLowBattery)

        // Cannot start while below 10% on battery if guard is enabled
        appState.setKeepAwakeEnabled(true)
        XCTAssertFalse(appState.isKeepAwakeActive)

        // Plugging in allows starting even at 9%
        mockBattery.emit(makeBattery(percentage: 9, isPluggedIn: true, isCharging: true))
        XCTAssertFalse(appState.isKeepAwakeBlockedByLowBattery)
        appState.setKeepAwakeEnabled(true)
        XCTAssertTrue(appState.isKeepAwakeActive)

        // Disabling 10% guard allows running on battery below 10%
        appState.setKeepAwakeStopBelow10Percent(false)
        mockBattery.emit(makeBattery(percentage: 8, isPluggedIn: false, isCharging: false))
        XCTAssertTrue(appState.isKeepAwakeActive)

        // 3. Sleep / shutdown stops Keep Awake when enabled (default)
        appState.handleSystemWillSleep()
        XCTAssertFalse(appState.isKeepAwakeActive)

        appState.setKeepAwakeEnabled(true)
        XCTAssertTrue(appState.isKeepAwakeActive)
        appState.handleSystemWillPowerOff()
        XCTAssertFalse(appState.isKeepAwakeActive)

        // When stopOnSleepOrShutdown is disabled, sleep notification leaves Keep Awake active
        appState.setKeepAwakeStopOnSleepOrShutdown(false)
        appState.setKeepAwakeEnabled(true)
        appState.handleSystemWillSleep()
        XCTAssertTrue(appState.isKeepAwakeActive)
    }

    @MainActor
    func testKeepAwakeFailureDoesNotActivateState() {
        let mockSleep = MockSleepPreventionService()
        mockSleep.shouldSucceed = false

        let tempHistory = FileManager.default.temporaryDirectory
            .appendingPathComponent("powerman_ka_fail_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempHistory) }

        let suiteName = "com.powerman.ka.fail.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let appState = AppState(
            historyStore: JSONBatteryHistoryStore(fileURL: tempHistory),
            sleepPreventionService: mockSleep,
            settings: AppSettings(defaults: defaults)
        )

        appState.setKeepAwakeEnabled(true)
        XCTAssertFalse(appState.isKeepAwakeActive)
        XCTAssertNil(appState.keepAwakeEndDate)
    }

    func testKeepAwakeAndChargingTabLocalization() {
        let vi = AppLanguageOption.vietnamese.effectiveLocalizationLocale
        XCTAssertEqual(L10n.string("Charging", locale: vi), "Đang sạc")
        XCTAssertEqual(L10n.string("Charging.tab", locale: vi), "Sạc pin")
        XCTAssertEqual(L10n.string("Keep Awake", locale: vi), "Giữ máy thức")
        XCTAssertEqual(L10n.string("Indefinite", locale: vi), "Vô thời hạn")
        XCTAssertEqual(L10n.string("Start", locale: vi), "Bắt đầu")
        XCTAssertEqual(L10n.string("Stop", locale: vi), "Dừng")
        XCTAssertEqual(L10n.string("Stop Keep Awake Below 10% Battery", locale: vi), "Dừng Giữ máy thức khi pin dưới 10%")
        XCTAssertEqual(L10n.string("Stop Keep Awake on Sleep or Shutdown", locale: vi), "Dừng Giữ máy thức khi tắt máy")
        XCTAssertEqual(L10n.string("Allow Screen Saver", locale: vi), "Cho phép trình bảo vệ màn hình")

        let ja = AppLanguageOption.japanese.effectiveLocalizationLocale
        XCTAssertEqual(L10n.string("Charging", locale: ja), "充電中")
        XCTAssertEqual(L10n.string("Charging.tab", locale: ja), "充電")
        XCTAssertEqual(L10n.string("Keep Awake", locale: ja), "スリープ防止")

        let en = AppLanguageOption.english.effectiveLocalizationLocale
        XCTAssertEqual(L10n.string("Charging", locale: en), "Charging")
        XCTAssertEqual(L10n.string("Charging.tab", locale: en), "Charging")
        XCTAssertEqual(L10n.string("Allow Screen Saver", locale: en), "Allow Screen Saver")
    }
}
