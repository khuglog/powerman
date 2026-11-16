import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var batteryInfo: BatteryInfo
    var bluetoothDevices: [BluetoothDeviceBattery] = []
    var historySamples: [BatteryHistorySample] = []
    var topEnergyApps: [AppEnergyUsage] = []
    var chargeLimitStatus: ChargeLimitStatus = .unsupported
    var isLowPowerModeEnabled: Bool = false
    var isLaunchAtLoginEnabled: Bool = false
    var launchAtLoginError: String?
    var isAccessibilityGranted: Bool = false

    let settings: AppSettings
    var selectedTab: SettingsTab = .battery
    var activeTestRuleID: UUID?
    var isPluggedChargeTransitionActive: Bool = false

    private let batteryService: BatteryMonitoring
    private let bluetoothService: BluetoothBatteryMonitoring
    private let historyStore: BatteryHistoryStoring
    private let energyService: EnergyConsuming
    private let chargeLimitService: ChargeLimitManaging
    private let systemService: SystemIntegrating
    private let alertEngine: AlertEngine
    private let alertPresenter: AlertPresenting
    private let soundPreviewPlayer: SoundPlaying
    private var firedDeviceAlertIDs: Set<String> = []
    private var chargeTransitionTask: Task<Void, Never>?

    var onOpenSettings: (() -> Void)?
    var onDismissPopover: (() -> Void)?
    var onQuitApp: (() -> Void)?

    init(
        batteryService: BatteryMonitoring = IOKitBatteryService(),
        bluetoothService: BluetoothBatteryMonitoring = BluetoothBatteryService(),
        historyStore: BatteryHistoryStoring = JSONBatteryHistoryStore(),
        energyService: EnergyConsuming = ProcessEnergyConsumerService(),
        chargeLimitService: ChargeLimitManaging = NativeChargeLimitService(),
        systemService: SystemIntegrating = MacSystemIntegrationService(),
        settings: AppSettings = AppSettings(),
        alertEngine: AlertEngine = AlertEngine(),
        alertPresenter: AlertPresenting = OverlayWindowManager(),
        soundPreviewPlayer: SoundPlaying = SystemSoundPlayer()
    ) {
        self.batteryService = batteryService
        self.bluetoothService = bluetoothService
        self.historyStore = historyStore
        self.energyService = energyService
        self.chargeLimitService = chargeLimitService
        self.systemService = systemService
        self.settings = settings
        self.alertEngine = alertEngine
        self.alertPresenter = alertPresenter
        self.soundPreviewPlayer = soundPreviewPlayer
        self.batteryInfo = batteryService.currentBattery
    }

    var visibleDropdownDevices: [BluetoothDeviceBattery] {
        guard settings.showBluetoothDevices else { return [] }
        return bluetoothDevices.filter { device in
            let pref = settings.preference(for: device.id)
            guard !pref.isHiddenFromDropdown else { return false }
            return device.isConnected && device.displayPercentage != nil
        }
    }

    var pinnedMenuBarDevices: [BluetoothDeviceBattery] {
        settings.orderedPinnedDevices(from: bluetoothDevices).filter {
            $0.isConnected && $0.displayPercentage != nil
        }
    }

    var launchAtLoginRequiresApproval: Bool {
        systemService.launchAtLoginRequiresApproval
    }

    var isPausedAtChargeLimit: Bool {
        isPausedAtChargeLimit(for: batteryInfo)
    }

    var menuBarShowsChargingStatus: Bool {
        batteryInfo.isCharging
            || (batteryInfo.isPluggedIn && isPluggedChargeTransitionActive && !isPausedAtChargeLimit)
    }

    private func isPausedAtChargeLimit(for info: BatteryInfo) -> Bool {
        chargeLimitStatus.isEnabled
            && info.isPluggedIn
            && !info.isCharging
            && info.percentage >= chargeLimitStatus.limitPercentage - 2
            && info.percentage < 100
    }

    func start() {
        historyStore.load()
        historySamples = historyStore.samples
        chargeLimitStatus = chargeLimitService.fetchStatus()
        syncSystemIntegrationState()

        systemService.startLowPowerObserver { [weak self] enabled in
            self?.isLowPowerModeEnabled = enabled
        }

        batteryService.startMonitoring { [weak self] info in
            self?.handleBatteryUpdate(info)
        }
        bluetoothService.startMonitoring { [weak self] devices in
            self?.handleBluetoothUpdate(devices)
        }
        refreshEnergyConsumers()
    }

    func stop() {
        chargeTransitionTask?.cancel()
        chargeTransitionTask = nil
        isPluggedChargeTransitionActive = false
        batteryService.stopMonitoring()
        bluetoothService.stopMonitoring()
        systemService.stopLowPowerObserver()
        systemService.stopNotificationDismisser()
        alertPresenter.dismiss()
        soundPreviewPlayer.stop()
    }

    func refreshBattery() {
        let info = batteryService.refreshNow()
        handleBatteryUpdate(info)
    }

    func refreshDevices() {
        bluetoothService.refreshNow()
    }

    func refreshEnergyConsumers() {
        energyService.refresh { [weak self] consumers in
            self?.topEnergyApps = consumers
        }
    }

    func refreshChargeLimit() {
        chargeLimitStatus = chargeLimitService.fetchStatus()
    }

    func setChargeLimitEnabled(_ enabled: Bool) {
        let target = chargeLimitStatus.limitPercentage >= 80 && chargeLimitStatus.limitPercentage <= 100
            ? chargeLimitStatus.limitPercentage
            : 80
        chargeLimitStatus = chargeLimitService.setEnabled(enabled, targetLimit: target)
    }

    func setChargeLimitPercentage(_ percentage: Int) {
        chargeLimitStatus = chargeLimitService.setLimit(percentage)
    }

    func syncSystemIntegrationState() {
        isLowPowerModeEnabled = systemService.isLowPowerModeEnabled
        isLaunchAtLoginEnabled = systemService.isLaunchAtLoginEnabled
        isAccessibilityGranted = systemService.isAccessibilityGranted
        systemService.applyAppearance(settings.appAppearance)

        if settings.dismissSystemBatteryNotifications && isAccessibilityGranted {
            systemService.startNotificationDismisser()
        } else {
            systemService.stopNotificationDismisser()
        }
    }

    func applyAppAppearance(_ appearance: AppAppearanceOption) {
        settings.appAppearance = appearance
        systemService.applyAppearance(appearance)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = systemService.setLaunchAtLogin(enabled)
        isLaunchAtLoginEnabled = systemService.isLaunchAtLoginEnabled
    }

    func setDismissSystemNotifications(_ enabled: Bool) {
        settings.dismissSystemBatteryNotifications = enabled
        if enabled && !systemService.isAccessibilityGranted {
            systemService.requestAccessibilityPermission()
        }
        syncSystemIntegrationState()
    }

    func requestAccessibilityPermission() {
        systemService.requestAccessibilityPermission()
        isAccessibilityGranted = systemService.isAccessibilityGranted
    }

    func setLowPowerMode(_ enabled: Bool) {
        Task { [weak self] in
            guard let self else { return }
            let success = await self.systemService.setLowPowerMode(
                enabled,
                restoreBrightness: self.settings.restoreBrightnessOnLowPowerOff
            )
            if success {
                self.isLowPowerModeEnabled = enabled
            } else {
                self.isLowPowerModeEnabled = self.systemService.isLowPowerModeEnabled
            }
        }
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
        alertPresenter.present(
            presentation,
            bubbleSize: settings.alertBubbleSize,
            glowIntensity: settings.screenEdgeGlowIntensity
        ) { [weak self] in
            self?.activeTestRuleID = nil
        }
    }

    func stopTestAlert() {
        activeTestRuleID = nil
        alertPresenter.dismiss()
        soundPreviewPlayer.stop()
    }

    func previewSound(_ sound: AlertSoundOption) {
        soundPreviewPlayer.play(sound: sound, repeating: false)
    }

    func openSettings(tab: SettingsTab? = nil) {
        if let tab {
            selectedTab = tab
        }
        onDismissPopover?()
        onOpenSettings?()
    }

    func dismissPopover() {
        onDismissPopover?()
    }

    func openSystemBatterySettings() {
        onDismissPopover?()
        if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    func quit() {
        onQuitApp?()
    }

    private func handleBatteryUpdate(_ info: BatteryInfo) {
        let previous = batteryInfo
        batteryInfo = info
        updateChargeTransitionState(previous: previous, current: info)
        if historyStore.recordIfNeeded(from: info) {
            historySamples = historyStore.samples
        }
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
            alertPresenter.present(
                alert,
                bubbleSize: settings.alertBubbleSize,
                glowIntensity: settings.screenEdgeGlowIntensity,
                onDismiss: nil
            )
        }
    }

    private func updateChargeTransitionState(previous: BatteryInfo, current: BatteryInfo) {
        if !current.isPluggedIn || current.isCharging || current.isFullyCharged || isPausedAtChargeLimit(for: current) {
            chargeTransitionTask?.cancel()
            chargeTransitionTask = nil
            isPluggedChargeTransitionActive = false
            return
        }

        // Reflect newly attached AC power immediately while USB-PD negotiates IsCharging.
        if !previous.isPluggedIn && current.isPluggedIn {
            isPluggedChargeTransitionActive = true
            chargeTransitionTask?.cancel()
            chargeTransitionTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                guard !Task.isCancelled else { return }
                self?.isPluggedChargeTransitionActive = false
                self?.chargeTransitionTask = nil
            }
        }
    }

    private func handleBluetoothUpdate(_ devices: [BluetoothDeviceBattery]) {
        bluetoothDevices = devices
        guard settings.notificationsEnabled else { return }

        for device in devices {
            guard device.isConnected, let pct = device.displayPercentage else {
                firedDeviceAlertIDs.remove(device.id)
                continue
            }

            let pref = settings.preference(for: device.id)
            guard let threshold = pref.lowBatteryAlertThreshold else {
                firedDeviceAlertIDs.remove(device.id)
                continue
            }

            if pct >= threshold + 5 {
                firedDeviceAlertIDs.remove(device.id)
            } else if pct <= threshold && !firedDeviceAlertIDs.contains(device.id) {
                firedDeviceAlertIDs.insert(device.id)
                let alert = ActiveAlertPresentation(
                    id: UUID(),
                    ruleID: nil,
                    kind: nil,
                    title: "\(device.name) • \(device.formattedPercentage)",
                    subtitle: "Device battery is below \(threshold)%",
                    percentage: pct,
                    colorHex: AlertColorPreset.orange.rawValue,
                    showPopup: true,
                    position: .topOfScreen,
                    sound: .lowWarning,
                    borderGlow: false,
                    persistent: false,
                    isChargingIcon: false
                )
                alertPresenter.present(
                    alert,
                    bubbleSize: settings.alertBubbleSize,
                    glowIntensity: settings.screenEdgeGlowIntensity,
                    onDismiss: nil
                )
            }
        }
    }
}
