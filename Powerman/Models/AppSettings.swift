import Foundation
import Observation

enum MenuBarIconStyle: String, CaseIterable, Identifiable, Codable {
    case batteryIndicator = "batteryIndicator"
    case minimal = "minimal"
    case powermanLogo = "powermanLogo"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .batteryIndicator:
            return "Battery Indicator"
        case .minimal:
            return "Minimal"
        case .powermanLogo:
            return "Powerman Logo"
        }
    }

    var subtitle: String {
        switch self {
        case .batteryIndicator:
            return "Shows battery level and charging status — Powerman's rich design"
        case .minimal:
            return "Minimalistic iPhone-style battery indicator"
        case .powermanLogo:
            return "Static Powerman logo icon"
        }
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Codable {
    case iconAndPercentage = "iconAndPercentage"
    case percentage = "percentage"
    case timeRemaining = "timeRemaining"
    case iconOnly = "iconOnly"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconAndPercentage:
            return "Icon & Percentage"
        case .percentage:
            return "Percentage"
        case .timeRemaining:
            return "Time Remaining"
        case .iconOnly:
            return "Icon Only"
        }
    }
}

enum MenuBarColorMode: String, CaseIterable, Identifiable, Codable {
    case auto = "auto"
    case monochrome = "monochrome"
    case white = "white"
    case black = "black"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .monochrome:
            return "Monochrome"
        case .white:
            return "White"
        case .black:
            return "Black"
        }
    }
}

enum MenuBarSize: String, CaseIterable, Identifiable, Codable {
    case `default` = "default"
    case large = "large"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default:
            return "Default"
        case .large:
            return "Large"
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case battery
    case charging
    case alerts
    case menuBar
    case devices
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery: return "Battery"
        case .charging: return "Charging"
        case .alerts: return "Alerts"
        case .menuBar: return "Menu Bar"
        case .devices: return "Devices"
        case .general: return "General"
        }
    }

    var systemImage: String {
        switch self {
        case .battery: return "battery.100percent"
        case .charging: return "bolt.heart.fill"
        case .alerts: return "bell.fill"
        case .menuBar: return "menubar.rectangle"
        case .devices: return "airpodspro"
        case .general: return "gearshape.fill"
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    private enum Keys {
        static let iconStyle = "menubar.iconStyle"
        static let displayMode = "menubar.displayMode"
        static let colorMode = "menubar.colorMode"
        static let size = "menubar.size"
        static let statusColorsEnabled = "menubar.statusColorsEnabled"
        static let notificationsEnabled = "alerts.notificationsEnabled"
        static let alertRules = "alerts.rules"
        static let powerSourceAlerts = "alerts.powerSource"
        static let soundDefaultsVersion = "alerts.soundDefaultsVersion"
        static let showBluetoothDevices = "devices.showBluetoothDevices"
        static let devicePreferences = "devices.preferences"
    }

    private let defaults: UserDefaults

    var menuBarIconStyle: MenuBarIconStyle {
        didSet { defaults.set(menuBarIconStyle.rawValue, forKey: Keys.iconStyle) }
    }

    var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.displayMode) }
    }

    var menuBarColorMode: MenuBarColorMode {
        didSet { defaults.set(menuBarColorMode.rawValue, forKey: Keys.colorMode) }
    }

    var menuBarSize: MenuBarSize {
        didSet { defaults.set(menuBarSize.rawValue, forKey: Keys.size) }
    }

    var statusColorsEnabled: Bool {
        didSet { defaults.set(statusColorsEnabled, forKey: Keys.statusColorsEnabled) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    var alertRules: [AlertRule] {
        didSet {
            if let data = try? JSONEncoder().encode(alertRules) {
                defaults.set(data, forKey: Keys.alertRules)
            }
        }
    }

    var powerSourceAlerts: PowerSourceAlertConfig {
        didSet {
            if let data = try? JSONEncoder().encode(powerSourceAlerts) {
                defaults.set(data, forKey: Keys.powerSourceAlerts)
            }
        }
    }

    var showBluetoothDevices: Bool {
        didSet { defaults.set(showBluetoothDevices, forKey: Keys.showBluetoothDevices) }
    }

    var devicePreferences: [String: DeviceUserPreference] {
        didSet {
            if let data = try? JSONEncoder().encode(devicePreferences) {
                defaults.set(data, forKey: Keys.devicePreferences)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let raw = defaults.string(forKey: Keys.iconStyle),
           let value = MenuBarIconStyle(rawValue: raw) {
            self.menuBarIconStyle = value
        } else {
            self.menuBarIconStyle = .minimal
        }

        if let raw = defaults.string(forKey: Keys.displayMode),
           let value = MenuBarDisplayMode(rawValue: raw) {
            self.menuBarDisplayMode = value
        } else {
            self.menuBarDisplayMode = .percentage
        }

        if let raw = defaults.string(forKey: Keys.colorMode),
           let value = MenuBarColorMode(rawValue: raw) {
            self.menuBarColorMode = value
        } else {
            self.menuBarColorMode = .auto
        }

        if let raw = defaults.string(forKey: Keys.size),
           let value = MenuBarSize(rawValue: raw) {
            self.menuBarSize = value
        } else {
            self.menuBarSize = .default
        }

        if defaults.object(forKey: Keys.statusColorsEnabled) != nil {
            self.statusColorsEnabled = defaults.bool(forKey: Keys.statusColorsEnabled)
        } else {
            self.statusColorsEnabled = true
        }

        if defaults.object(forKey: Keys.notificationsEnabled) != nil {
            self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        } else {
            self.notificationsEnabled = true
        }

        if let data = defaults.data(forKey: Keys.alertRules),
           let decoded = try? JSONDecoder().decode([AlertRule].self, from: data) {
            self.alertRules = decoded
        } else {
            self.alertRules = AlertRule.defaultRules
        }

        if let data = defaults.data(forKey: Keys.powerSourceAlerts),
           let decoded = try? JSONDecoder().decode(PowerSourceAlertConfig.self, from: data) {
            self.powerSourceAlerts = decoded
        } else {
            self.powerSourceAlerts = PowerSourceAlertConfig()
        }

        if defaults.object(forKey: Keys.showBluetoothDevices) != nil {
            self.showBluetoothDevices = defaults.bool(forKey: Keys.showBluetoothDevices)
        } else {
            self.showBluetoothDevices = true
        }

        if let data = defaults.data(forKey: Keys.devicePreferences),
           let decoded = try? JSONDecoder().decode([String: DeviceUserPreference].self, from: data) {
            self.devicePreferences = decoded
        } else {
            self.devicePreferences = [:]
        }

        migrateLegacySoundDefaultsIfNeeded()
    }

    private func migrateLegacySoundDefaultsIfNeeded() {
        let currentVersion = defaults.integer(forKey: Keys.soundDefaultsVersion)
        guard currentVersion < 2 else { return }
        defaults.set(2, forKey: Keys.soundDefaultsVersion)

        // Upgrade untouched Phase 2 initial sound defaults to semantic Powerman sounds.
        for index in alertRules.indices {
            let rule = alertRules[index]
            if rule.kind == .lowBattery && rule.threshold == 5 && rule.sound == .basso {
                alertRules[index].sound = .criticalAlarm
            } else if rule.kind == .lowBattery && rule.threshold == 10 && rule.sound == .glass {
                alertRules[index].sound = .urgentBeep
            } else if rule.kind == .lowBattery && rule.threshold == 20 && rule.sound == .ping {
                alertRules[index].sound = .lowWarning
            } else if rule.kind == .charged && rule.threshold == 80 && rule.sound == .hero {
                alertRules[index].sound = .chargedChime
            }
        }

        if powerSourceAlerts.pluggedInSound == .hero {
            powerSourceAlerts.pluggedInSound = .powerConnect
        }
        if powerSourceAlerts.unpluggedSound == .none {
            powerSourceAlerts.unpluggedSound = .powerDisconnect
        }
    }

    func resetAlertDefaults() {
        notificationsEnabled = true
        alertRules = AlertRule.defaultRules
        powerSourceAlerts = PowerSourceAlertConfig()
    }

    func lowBatteryRules() -> [AlertRule] {
        alertRules.filter { $0.kind == .lowBattery }.sorted { $0.threshold < $1.threshold }
    }

    func chargedRules() -> [AlertRule] {
        alertRules.filter { $0.kind == .charged }.sorted { $0.threshold < $1.threshold }
    }

    @discardableResult
    func addAlertRule(kind: AlertKind) -> AlertRule {
        let existing = alertRules.filter { $0.kind == kind }.map(\.threshold)
        let nextThreshold: Int
        let colorHex: String
        switch kind {
        case .lowBattery:
            let candidate = max(5, (existing.max() ?? 15) + 5)
            nextThreshold = min(95, candidate)
            colorHex = AlertColorPreset.orange.rawValue
        case .charged:
            let candidate = min(100, (existing.max() ?? 80) + 5)
            nextThreshold = max(50, candidate)
            colorHex = AlertColorPreset.green.rawValue
        }

        let newRule = AlertRule(
            kind: kind,
            threshold: nextThreshold,
            colorHex: colorHex,
            showPopup: true,
            position: .topOfScreen,
            sound: kind == .lowBattery ? (nextThreshold <= 10 ? .urgentBeep : .lowWarning) : .chargedChime,
            borderGlow: kind == .lowBattery,
            persistent: false
        )
        alertRules.append(newRule)
        return newRule
    }

    func removeAlertRule(id: UUID) {
        alertRules.removeAll { $0.id == id }
    }

    func preference(for deviceID: String) -> DeviceUserPreference {
        devicePreferences[deviceID] ?? DeviceUserPreference()
    }

    func togglePinDevice(_ deviceID: String) {
        var pref = preference(for: deviceID)
        pref.isPinnedToMenuBar.toggle()
        if pref.isPinnedToMenuBar {
            let maxOrder = devicePreferences.values.filter(\.isPinnedToMenuBar).map(\.pinOrder).max() ?? -1
            pref.pinOrder = maxOrder + 1
        }
        devicePreferences[deviceID] = pref
    }

    func toggleHideDevice(_ deviceID: String) {
        var pref = preference(for: deviceID)
        pref.isHiddenFromDropdown.toggle()
        devicePreferences[deviceID] = pref
    }

    func setDeviceAlertThreshold(_ threshold: Int?, for deviceID: String) {
        var pref = preference(for: deviceID)
        pref.lowBatteryAlertThreshold = threshold
        devicePreferences[deviceID] = pref
    }

    func movePinnedDevice(id: String, direction: Int, allDevices: [BluetoothDeviceBattery]) {
        let pinned = orderedPinnedDevices(from: allDevices)
        guard let index = pinned.firstIndex(where: { $0.id == id }) else { return }
        let targetIndex = index + direction
        guard pinned.indices.contains(targetIndex) else { return }

        var reordered = pinned.map(\.id)
        reordered.swapAt(index, targetIndex)
        for (order, devID) in reordered.enumerated() {
            var pref = preference(for: devID)
            pref.pinOrder = order
            devicePreferences[devID] = pref
        }
    }

    func orderedPinnedDevices(from devices: [BluetoothDeviceBattery]) -> [BluetoothDeviceBattery] {
        devices
            .filter { preference(for: $0.id).isPinnedToMenuBar }
            .sorted { lhs, rhs in
                let lOrder = preference(for: lhs.id).pinOrder
                let rOrder = preference(for: rhs.id).pinOrder
                if lOrder != rOrder {
                    return lOrder < rOrder
                }
                return lhs.name < rhs.name
            }
    }
}
