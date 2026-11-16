import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var batteryInfo: BatteryInfo
    let settings: AppSettings
    var selectedTab: SettingsTab = .battery
    var activeTestRuleID: UUID?

    private let batteryService: BatteryMonitoring
    private let alertEngine: AlertEngine
    private let alertPresenter: AlertPresenting

    var onOpenSettings: (() -> Void)?
    var onQuitApp: (() -> Void)?

    init(
        batteryService: BatteryMonitoring = IOKitBatteryService(),
        settings: AppSettings = AppSettings(),
        alertEngine: AlertEngine = AlertEngine(),
        alertPresenter: AlertPresenting = OverlayWindowManager()
    ) {
        self.batteryService = batteryService
        self.settings = settings
        self.alertEngine = alertEngine
        self.alertPresenter = alertPresenter
        self.batteryInfo = batteryService.currentBattery
    }

    func start() {
        batteryService.startMonitoring { [weak self] info in
            self?.handleBatteryUpdate(info)
        }
    }

    func stop() {
        batteryService.stopMonitoring()
        alertPresenter.dismiss()
    }

    func refreshBattery() {
        let info = batteryService.refreshNow()
        handleBatteryUpdate(info)
    }

    func testAlert(rule: AlertRule) {
        if activeTestRuleID == rule.id {
            stopTestAlert()
            return
        }

        let previewBattery = BatteryInfo(
            percentage: rule.threshold,
            isCharging: rule.kind == .charged,
            isPluggedIn: rule.kind == .charged,
            isFullyCharged: rule.threshold >= 100,
            timeRemainingMinutes: rule.kind == .lowBattery ? max(3, rule.threshold / 2) : nil,
            cycleCount: batteryInfo.cycleCount,
            ratedCycleCount: batteryInfo.ratedCycleCount,
            designCapacityMah: batteryInfo.designCapacityMah,
            maxCapacityMah: batteryInfo.maxCapacityMah,
            currentCapacityMah: batteryInfo.currentCapacityMah,
            temperatureCelsius: batteryInfo.temperatureCelsius,
            voltageMv: batteryInfo.voltageMv,
            amperageMa: batteryInfo.amperageMa,
            batteryPowerMw: batteryInfo.batteryPowerMw,
            adapterWatts: batteryInfo.adapterWatts,
            adapterName: batteryInfo.adapterName,
            hasBattery: true,
            lastUpdated: Date()
        )

        let presentation = ActiveAlertPresentation.from(rule: rule, battery: previewBattery)
        activeTestRuleID = rule.id
        alertPresenter.present(presentation) { [weak self] in
            self?.activeTestRuleID = nil
        }
    }

    func stopTestAlert() {
        activeTestRuleID = nil
        alertPresenter.dismiss()
    }

    func openSettings(tab: SettingsTab? = nil) {
        if let tab {
            selectedTab = tab
        }
        onOpenSettings?()
    }

    func openSystemBatterySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    func quit() {
        onQuitApp?()
    }

    private func handleBatteryUpdate(_ info: BatteryInfo) {
        batteryInfo = info
        let result = alertEngine.evaluate(
            battery: info,
            rules: settings.alertRules,
            powerSource: settings.powerSourceAlerts,
            notificationsEnabled: settings.notificationsEnabled
        )

        if let dismissKind = result.dismissKind,
           alertPresenter.activeAlert?.kind == dismissKind {
            activeTestRuleID = nil
            alertPresenter.dismiss()
        }

        if let alert = result.triggeredAlert {
            activeTestRuleID = nil
            alertPresenter.present(alert, onDismiss: nil)
        }
    }
}
