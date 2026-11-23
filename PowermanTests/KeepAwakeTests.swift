import XCTest
@testable import Powerman

@MainActor
private final class MockSleepPreventionService: SleepPreventing {
    var isPreventingSleep: Bool = false
    var shouldSucceed: Bool = true
    var beginCount: Int = 0
    var endCount: Int = 0
    var lastReason: String?

    func beginPreventingSystemSleep(reason: String) -> Bool {
        beginCount += 1
        lastReason = reason
        guard shouldSucceed else { return false }
        isPreventingSleep = true
        return true
    }

    func endPreventingSystemSleep() {
        endCount += 1
        isPreventingSleep = false
    }
}

final class KeepAwakeTests: XCTestCase {
    @MainActor
    func testKeepAwakeDurationPersistenceAndSliderMapping() {
        let suiteName = "com.powerman.keepawake.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.keepAwakeDuration, .hour1)

        settings.keepAwakeDuration = .hours4
        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.keepAwakeDuration, .hours4)

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

        let ja = AppLanguageOption.japanese.effectiveLocalizationLocale
        XCTAssertEqual(L10n.string("Charging", locale: ja), "充電中")
        XCTAssertEqual(L10n.string("Charging.tab", locale: ja), "充電")
        XCTAssertEqual(L10n.string("Keep Awake", locale: ja), "スリープ防止")

        let en = AppLanguageOption.english.effectiveLocalizationLocale
        XCTAssertEqual(L10n.string("Charging", locale: en), "Charging")
        XCTAssertEqual(L10n.string("Charging.tab", locale: en), "Charging")
    }
}
