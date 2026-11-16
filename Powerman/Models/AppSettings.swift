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
            sound: kind == .lowBattery ? .glass : .chime,
            borderGlow: kind == .lowBattery,
            persistent: false
        )
        alertRules.append(newRule)
        return newRule
    }

    func removeAlertRule(id: UUID) {
        alertRules.removeAll { $0.id == id }
    }
}
