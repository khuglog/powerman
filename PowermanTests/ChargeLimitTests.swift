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
}
