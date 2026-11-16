import XCTest
@testable import Powerman

@MainActor
private final class MockSystemIntegrationService: SystemIntegrating {
    var isLaunchAtLoginEnabled: Bool = false
    var launchAtLoginRequiresApproval: Bool = false
    var isAccessibilityGranted: Bool = false
    var isLowPowerModeEnabled: Bool = false

    var appliedAppearance: AppAppearanceOption = .auto
    var requestedAccessibility = false
    var notificationDismisserRunning = false

    func setLaunchAtLogin(_ enabled: Bool) -> String? {
        isLaunchAtLoginEnabled = enabled
        return nil
    }

    func applyAppearance(_ appearance: AppAppearanceOption) {
        appliedAppearance = appearance
    }

    func requestAccessibilityPermission() {
        requestedAccessibility = true
    }

    func startLowPowerObserver(onChange: @escaping @MainActor (Bool) -> Void) {}
    func stopLowPowerObserver() {}

    func setLowPowerMode(_ enabled: Bool, restoreBrightness: Bool) async -> Bool {
        isLowPowerModeEnabled = enabled
        return true
    }

    func startNotificationDismisser() {
        notificationDismisserRunning = true
    }

    func stopNotificationDismisser() {
        notificationDismisserRunning = false
    }
}

final class GeneralSettingsTests: XCTestCase {
    @MainActor
    func testGeneralSettingsPersistence() {
        let suiteName = "com.powerman.general.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.appLanguage = .vietnamese
        settings.appAppearance = .dark
        settings.dismissSystemBatteryNotifications = true
        settings.restoreBrightnessOnLowPowerOff = false
        settings.alertBubbleSize = .large
        settings.screenEdgeGlowIntensity = .intense

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.appLanguage, .vietnamese)
        XCTAssertEqual(reloaded.appAppearance, .dark)
        XCTAssertTrue(reloaded.dismissSystemBatteryNotifications)
        XCTAssertFalse(reloaded.restoreBrightnessOnLowPowerOff)
        XCTAssertEqual(reloaded.alertBubbleSize, .large)
        XCTAssertEqual(reloaded.screenEdgeGlowIntensity, .intense)
    }

    @MainActor
    func testAppStateSystemIntegrationActions() {
        let mockSys = MockSystemIntegrationService()
        let tempHistory = FileManager.default.temporaryDirectory
            .appendingPathComponent("powerman_gen_hist_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempHistory) }

        let suiteName = "com.powerman.sys.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let appState = AppState(
            historyStore: JSONBatteryHistoryStore(fileURL: tempHistory),
            systemService: mockSys,
            settings: AppSettings(defaults: defaults)
        )

        appState.applyAppAppearance(.dark)
        XCTAssertEqual(mockSys.appliedAppearance, .dark)

        appState.setLaunchAtLogin(true)
        XCTAssertTrue(appState.isLaunchAtLoginEnabled)

        mockSys.isAccessibilityGranted = true
        appState.setDismissSystemNotifications(true)
        XCTAssertTrue(mockSys.notificationDismisserRunning)

        appState.setDismissSystemNotifications(false)
        XCTAssertFalse(mockSys.notificationDismisserRunning)
    }

    func testBubbleAndGlowScalingValues() {
        XCTAssertLessThan(AlertBubbleSize.compact.scale, AlertBubbleSize.default.scale)
        XCTAssertGreaterThan(AlertBubbleSize.large.scale, AlertBubbleSize.default.scale)
        XCTAssertLessThan(ScreenEdgeGlowIntensity.subtle.edgeThickness, ScreenEdgeGlowIntensity.default.edgeThickness)
        XCTAssertGreaterThan(ScreenEdgeGlowIntensity.intense.edgeThickness, ScreenEdgeGlowIntensity.default.edgeThickness)
    }
}
