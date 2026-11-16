import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var batteryInfo: BatteryInfo
    let settings: AppSettings
    var selectedTab: SettingsTab = .battery

    private let batteryService: BatteryMonitoring
    var onOpenSettings: (() -> Void)?
    var onQuitApp: (() -> Void)?

    init(
        batteryService: BatteryMonitoring = IOKitBatteryService(),
        settings: AppSettings = AppSettings()
    ) {
        self.batteryService = batteryService
        self.settings = settings
        self.batteryInfo = batteryService.currentBattery
    }

    func start() {
        batteryService.startMonitoring { [weak self] info in
            self?.batteryInfo = info
        }
    }

    func stop() {
        batteryService.stopMonitoring()
    }

    func refreshBattery() {
        batteryInfo = batteryService.refreshNow()
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
}
