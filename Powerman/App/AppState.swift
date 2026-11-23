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
    var isKeepAwakeActive: Bool = false
    var keepAwakeEndDate: Date?

    let settings: AppSettings
    var selectedTab: SettingsTab = .battery
    var activeTestRuleID: UUID?

    private let batteryService: BatteryMonitoring
    private let bluetoothService: BluetoothBatteryMonitoring
    private let historyStore: BatteryHistoryStoring
    private let energyService: EnergyConsuming
    private let chargeLimitService: ChargeLimitManaging
    private let systemService: SystemIntegrating
    private let sleepPreventionService: SleepPreventing
    private let alertEngine: AlertEngine
    private let alertPresenter: AlertPresenting
    private let soundPreviewPlayer: SoundPlaying
    private var firedDeviceAlertIDs: Set<String> = []
    private var lastActiveChargeLimit: Int = 80
    private var keepAwakeExpirationTimer: Timer?
    private var keepAwakeWakeObserver: NSObjectProtocol?

    var onOpenSettings: (() -> Void)?
    var onDismissPopover: (() -> Void)?
    var onQuitApp: (() -> Void)?
    var onMenuBarUpdate: (() -> Void)?

    init(
        batteryService: BatteryMonitoring = IOKitBatteryService(),
        bluetoothService: BluetoothBatteryMonitoring = BluetoothBatteryService(),
        historyStore: BatteryHistoryStoring = JSONBatteryHistoryStore(),
        energyService: EnergyConsuming = ProcessEnergyConsumerService(),
        chargeLimitService: ChargeLimitManaging = NativeChargeLimitService(),
        systemService: SystemIntegrating = MacSystemIntegrationService(),
        sleepPreventionService: SleepPreventing = IOKitSleepPreventionService(),
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
        self.sleepPreventionService = sleepPreventionService
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

    var effectiveLocale: Locale {
        settings.appLanguage.effectiveLocalizationLocale
    }

    var isPausedAtChargeLimit: Bool {
        isPausedAtChargeLimit(for: batteryInfo)
    }

    var isTemporaryChargeOverrideActive: Bool {
        settings.temporaryChargeOverride != nil
    }

    var temporaryChargeOverrideRestoreLimit: Int? {
        settings.temporaryChargeOverride?.restoreLimitPercentage
    }

    var canActivateTemporaryChargeOverride: Bool {
        chargeLimitStatus.isSupported && chargeLimitStatus.isEnabled && !isTemporaryChargeOverrideActive
    }

    var batteryStatusLabel: String {
        if isPausedAtChargeLimit {
            return L10n.format("Paused at %d%% Limit", locale: effectiveLocale, chargeLimitStatus.limitPercentage)
        }
        if batteryInfo.isFullyCharged && batteryInfo.isPluggedIn {
            return L10n.string("Fully Charged", locale: effectiveLocale)
        }
        if batteryInfo.isCharging || batteryInfo.isPluggedIn {
            return L10n.string("Charging", locale: effectiveLocale)
        }
        return L10n.string("On Battery", locale: effectiveLocale)
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
        refreshChargeLimit()
        evaluateTemporaryChargeOverride(for: batteryInfo)
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
        keepAwakeWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.expireKeepAwakeIfNeeded()
            }
        }
        refreshEnergyConsumers()
    }

    func stop() {
        batteryService.stopMonitoring()
        bluetoothService.stopMonitoring()
        systemService.stopLowPowerObserver()
        systemService.stopNotificationDismisser()
        if let keepAwakeWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(keepAwakeWakeObserver)
            self.keepAwakeWakeObserver = nil
        }
        setKeepAwakeEnabled(false)
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
        if chargeLimitStatus.isEnabled, chargeLimitStatus.limitPercentage < 100 {
            lastActiveChargeLimit = chargeLimitStatus.limitPercentage
            if settings.temporaryChargeOverride != nil {
                settings.temporaryChargeOverride = nil
            }
        }
    }

    func setChargeLimitEnabled(_ enabled: Bool) {
        let savedOverrideLimit = settings.temporaryChargeOverride?.restoreLimitPercentage
        settings.temporaryChargeOverride = nil

        let target: Int
        if chargeLimitStatus.limitPercentage >= 80 && chargeLimitStatus.limitPercentage < 100 {
            target = chargeLimitStatus.limitPercentage
        } else if let savedOverrideLimit, (80..<100).contains(savedOverrideLimit) {
            target = savedOverrideLimit
        } else {
            target = lastActiveChargeLimit
        }

        chargeLimitStatus = chargeLimitService.setEnabled(enabled, targetLimit: target)
        if chargeLimitStatus.isEnabled, chargeLimitStatus.limitPercentage < 100 {
            lastActiveChargeLimit = chargeLimitStatus.limitPercentage
        }
    }

    func setChargeLimitPercentage(_ percentage: Int) {
        if percentage < 100 {
            lastActiveChargeLimit = percentage
            settings.temporaryChargeOverride = nil
        }
        chargeLimitStatus = chargeLimitService.setLimit(percentage)
        if chargeLimitStatus.isEnabled, chargeLimitStatus.limitPercentage < 100 {
            lastActiveChargeLimit = chargeLimitStatus.limitPercentage
        }
    }

    func activateTemporaryChargeOverride() {
        guard canActivateTemporaryChargeOverride else { return }
        let restoreLimit = (chargeLimitStatus.limitPercentage >= 80 && chargeLimitStatus.limitPercentage < 100)
            ? chargeLimitStatus.limitPercentage
            : lastActiveChargeLimit
        lastActiveChargeLimit = restoreLimit
        settings.temporaryChargeOverride = TemporaryChargeOverrideState(
            restoreLimitPercentage: restoreLimit,
            hasObservedPluggedIn: batteryInfo.isPluggedIn,
            activatedAt: Date()
        )
        chargeLimitStatus = chargeLimitService.setEnabled(false, targetLimit: restoreLimit)
        if chargeLimitStatus.isEnabled {
            settings.temporaryChargeOverride = nil
        }
        onMenuBarUpdate?()
    }

    func cancelTemporaryChargeOverride() {
        guard let overrideState = settings.temporaryChargeOverride else { return }
        settings.temporaryChargeOverride = nil
        let target = (80..<100).contains(overrideState.restoreLimitPercentage)
            ? overrideState.restoreLimitPercentage
            : lastActiveChargeLimit
        lastActiveChargeLimit = target
        chargeLimitStatus = chargeLimitService.setEnabled(true, targetLimit: target)
        if chargeLimitStatus.isEnabled, chargeLimitStatus.limitPercentage < 100 {
            lastActiveChargeLimit = chargeLimitStatus.limitPercentage
        }
        onMenuBarUpdate?()
    }

    private func evaluateTemporaryChargeOverride(for info: BatteryInfo) {
        guard var overrideState = settings.temporaryChargeOverride else { return }

        if info.isPluggedIn && !overrideState.hasObservedPluggedIn {
            overrideState.hasObservedPluggedIn = true
            settings.temporaryChargeOverride = overrideState
        }

        let shouldEnd: Bool
        switch settings.chargeLimitOverrideEndCondition {
        case .onUnplug:
            shouldEnd = overrideState.hasObservedPluggedIn && !info.isPluggedIn
        case .onFirstFullCharge:
            shouldEnd = info.percentage >= 100 || (info.isPluggedIn && info.isFullyCharged)
        }

        if shouldEnd {
            cancelTemporaryChargeOverride()
        }
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

    func setKeepAwakeEnabled(_ enabled: Bool, now: Date = Date()) {
        if enabled {
            let started = sleepPreventionService.beginPreventingSystemSleep(
                reason: "Powerman Keep Awake (Prevent Idle System Sleep)"
            )
            guard started else {
                isKeepAwakeActive = false
                keepAwakeEndDate = nil
                keepAwakeExpirationTimer?.invalidate()
                keepAwakeExpirationTimer = nil
                onMenuBarUpdate?()
                return
            }

            isKeepAwakeActive = true
            keepAwakeEndDate = settings.keepAwakeDuration.durationSeconds.map { now.addingTimeInterval($0) }
            scheduleKeepAwakeExpirationTimer(now: now)
            onMenuBarUpdate?()
        } else {
            keepAwakeExpirationTimer?.invalidate()
            keepAwakeExpirationTimer = nil
            sleepPreventionService.endPreventingSystemSleep()
            isKeepAwakeActive = false
            keepAwakeEndDate = nil
            onMenuBarUpdate?()
        }
    }

    func setKeepAwakeDuration(_ duration: KeepAwakeDuration, now: Date = Date()) {
        settings.keepAwakeDuration = duration
        guard isKeepAwakeActive else { return }
        keepAwakeEndDate = duration.durationSeconds.map { now.addingTimeInterval($0) }
        scheduleKeepAwakeExpirationTimer(now: now)
    }

    func expireKeepAwakeIfNeeded(now: Date = Date()) {
        guard isKeepAwakeActive, let endDate = keepAwakeEndDate, now >= endDate else { return }
        setKeepAwakeEnabled(false, now: now)
    }

    func keepAwakeRemainingSeconds(at now: Date = Date()) -> TimeInterval? {
        guard isKeepAwakeActive, let endDate = keepAwakeEndDate else { return nil }
        return max(0, endDate.timeIntervalSince(now))
    }

    private func scheduleKeepAwakeExpirationTimer(now: Date) {
        keepAwakeExpirationTimer?.invalidate()
        keepAwakeExpirationTimer = nil

        guard isKeepAwakeActive, let endDate = keepAwakeEndDate else { return }
        let delay = max(0.1, endDate.timeIntervalSince(now))
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleKeepAwakeTimerFired()
            }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        keepAwakeExpirationTimer = timer
    }

    private func handleKeepAwakeTimerFired(now: Date = Date()) {
        guard isKeepAwakeActive, let endDate = keepAwakeEndDate else { return }
        if now >= endDate {
            setKeepAwakeEnabled(false, now: now)
        } else {
            scheduleKeepAwakeExpirationTimer(now: now)
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

        let presentation = ActiveAlertPresentation.from(rule: rule, battery: previewBattery, locale: effectiveLocale)
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
        batteryInfo = info
        evaluateTemporaryChargeOverride(for: info)
        onMenuBarUpdate?()
        if historyStore.recordIfNeeded(from: info) {
            historySamples = historyStore.samples
        }
        let result = alertEngine.evaluate(
            battery: info,
            rules: settings.alertRules,
            powerSource: settings.powerSourceAlerts,
            notificationsEnabled: settings.notificationsEnabled,
            locale: effectiveLocale
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

    private func handleBluetoothUpdate(_ devices: [BluetoothDeviceBattery]) {
        bluetoothDevices = devices
        onMenuBarUpdate?()
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
                    subtitle: L10n.format("Device battery is below %d%%", locale: effectiveLocale, threshold),
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
