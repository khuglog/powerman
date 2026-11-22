import AppKit
import Foundation
import SwiftUI

enum AlertKind: String, Codable, Sendable, CaseIterable {
    case lowBattery
    case charged
}

enum AlertPosition: String, Codable, Sendable, CaseIterable, Identifiable {
    case topOfScreen
    case centerOfScreen

    var id: String { rawValue }

    var title: String {
        title(in: Locale(identifier: "en"))
    }

    func title(in locale: Locale) -> String {
        switch self {
        case .topOfScreen: return L10n.string("Top of Screen", locale: locale)
        case .centerOfScreen: return L10n.string("Center of Screen", locale: locale)
        }
    }
}

enum AlertSoundOption: String, Codable, Sendable, CaseIterable, Identifiable {
    case none = "none"

    // Custom synthesized Powerman alert tones
    case criticalAlarm = "powerman.criticalAlarm"
    case urgentBeep = "powerman.urgentBeep"
    case lowWarning = "powerman.lowWarning"
    case chargedChime = "powerman.chargedChime"
    case powerConnect = "powerman.powerConnect"
    case powerDisconnect = "powerman.powerDisconnect"
    case radarPulse = "powerman.radarPulse"
    case softBell = "powerman.softBell"

    // Built-in macOS system sounds
    case glass = "Glass"
    case hero = "Hero"
    case ping = "Ping"
    case pop = "Pop"
    case tink = "Tink"
    case submarine = "Submarine"
    case sosumi = "Sosumi"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case morse = "Morse"
    case purr = "Purr"
    case basso = "Basso"

    var id: String { rawValue }

    static var customAlertSounds: [AlertSoundOption] {
        [
            .criticalAlarm,
            .urgentBeep,
            .lowWarning,
            .chargedChime,
            .powerConnect,
            .powerDisconnect,
            .radarPulse,
            .softBell
        ]
    }

    static var systemSounds: [AlertSoundOption] {
        [
            .glass, .hero, .ping, .pop, .tink, .submarine, .sosumi,
            .blow, .bottle, .frog, .funk, .morse, .purr, .basso
        ]
    }

    var isCustomSynthesized: Bool {
        Self.customAlertSounds.contains(self)
    }

    var title: String {
        title(in: Locale(identifier: "en"))
    }

    func title(in locale: Locale) -> String {
        switch self {
        case .none: return L10n.string("None (Silent)", locale: locale)
        case .criticalAlarm: return L10n.string("Critical Alarm (Urgent)", locale: locale)
        case .urgentBeep: return L10n.string("Urgent Double Beep", locale: locale)
        case .lowWarning: return L10n.string("Low Battery Warning", locale: locale)
        case .chargedChime: return L10n.string("Charged Success Chime", locale: locale)
        case .powerConnect: return L10n.string("Power Connect", locale: locale)
        case .powerDisconnect: return L10n.string("Power Disconnect", locale: locale)
        case .radarPulse: return L10n.string("Radar Pulse", locale: locale)
        case .softBell: return L10n.string("Soft Bell", locale: locale)
        case .glass: return L10n.string("macOS Glass", locale: locale)
        case .hero: return L10n.string("macOS Hero", locale: locale)
        case .ping: return L10n.string("macOS Ping", locale: locale)
        case .pop: return L10n.string("macOS Pop", locale: locale)
        case .tink: return L10n.string("macOS Tink", locale: locale)
        case .submarine: return L10n.string("macOS Submarine", locale: locale)
        case .sosumi: return L10n.string("macOS Sosumi", locale: locale)
        case .blow: return L10n.string("macOS Blow", locale: locale)
        case .bottle: return L10n.string("macOS Bottle", locale: locale)
        case .frog: return L10n.string("macOS Frog", locale: locale)
        case .funk: return L10n.string("macOS Funk", locale: locale)
        case .morse: return L10n.string("macOS Morse", locale: locale)
        case .purr: return L10n.string("macOS Purr", locale: locale)
        case .basso: return L10n.string("macOS Basso", locale: locale)
        }
    }

    var systemSoundName: String? {
        guard self != .none, !isCustomSynthesized else { return nil }
        return rawValue
    }
}

enum AlertColorPreset: String, CaseIterable, Identifiable {
    case red = "#FF3B30"
    case orange = "#FF9500"
    case yellow = "#FFCC00"
    case green = "#34C759"
    case blue = "#007AFF"
    case purple = "#AF52DE"

    var id: String { rawValue }

    var color: Color {
        Color(hex: rawValue) ?? .red
    }
}

struct AlertRule: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: AlertKind
    var threshold: Int
    var colorHex: String
    var showPopup: Bool
    var position: AlertPosition
    var sound: AlertSoundOption
    var borderGlow: Bool
    var persistent: Bool

    init(
        id: UUID = UUID(),
        kind: AlertKind,
        threshold: Int,
        colorHex: String,
        showPopup: Bool = true,
        position: AlertPosition = .topOfScreen,
        sound: AlertSoundOption = .lowWarning,
        borderGlow: Bool = false,
        persistent: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.threshold = threshold
        self.colorHex = colorHex
        self.showPopup = showPopup
        self.position = position
        self.sound = sound
        self.borderGlow = borderGlow
        self.persistent = persistent
    }

    var summaryText: String {
        summaryText(in: Locale(identifier: "en"))
    }

    func summaryText(in locale: Locale) -> String {
        var parts: [String] = []
        if showPopup {
            parts.append(position.title(in: locale))
        }
        if borderGlow {
            parts.append(L10n.string("Border Glow", locale: locale))
        }
        if sound != .none {
            parts.append(sound.title(in: locale))
        }
        if persistent {
            parts.append(L10n.string("Persistent", locale: locale))
        }
        return parts.isEmpty ? L10n.string("Silent", locale: locale) : parts.joined(separator: " • ")
    }

    var color: Color {
        Color(hex: colorHex) ?? (kind == .lowBattery ? .red : .green)
    }

    static let defaultRules: [AlertRule] = [
        AlertRule(
            kind: .lowBattery,
            threshold: 5,
            colorHex: AlertColorPreset.red.rawValue,
            showPopup: true,
            position: .centerOfScreen,
            sound: .criticalAlarm,
            borderGlow: true,
            persistent: true
        ),
        AlertRule(
            kind: .lowBattery,
            threshold: 10,
            colorHex: AlertColorPreset.red.rawValue,
            showPopup: true,
            position: .centerOfScreen,
            sound: .urgentBeep,
            borderGlow: true,
            persistent: false
        ),
        AlertRule(
            kind: .lowBattery,
            threshold: 20,
            colorHex: AlertColorPreset.yellow.rawValue,
            showPopup: true,
            position: .topOfScreen,
            sound: .lowWarning,
            borderGlow: false,
            persistent: false
        ),
        AlertRule(
            kind: .charged,
            threshold: 80,
            colorHex: AlertColorPreset.green.rawValue,
            showPopup: true,
            position: .topOfScreen,
            sound: .chargedChime,
            borderGlow: false,
            persistent: false
        )
    ]
}

struct PowerSourceAlertConfig: Codable, Equatable, Sendable {
    var pluggedInEnabled: Bool = true
    var pluggedInSound: AlertSoundOption = .powerConnect
    var unpluggedEnabled: Bool = true
    var unpluggedSound: AlertSoundOption = .powerDisconnect
}

struct ActiveAlertPresentation: Identifiable, Equatable, Sendable {
    let id: UUID
    let ruleID: UUID?
    let kind: AlertKind?
    let title: String
    let subtitle: String
    let percentage: Int
    let colorHex: String
    let showPopup: Bool
    let position: AlertPosition
    let sound: AlertSoundOption
    let borderGlow: Bool
    let persistent: Bool
    let isChargingIcon: Bool

    var color: Color {
        Color(hex: colorHex) ?? .orange
    }

    static func from(
        rule: AlertRule,
        battery: BatteryInfo,
        locale: Locale = Locale(identifier: "en")
    ) -> ActiveAlertPresentation {
        let title: String
        let subtitle: String
        switch rule.kind {
        case .lowBattery:
            title = L10n.format("%d%% Remaining", locale: locale, battery.percentage)
            if let mins = battery.timeRemainingMinutes, mins > 0 {
                subtitle = L10n.format("%dmin until empty", locale: locale, mins)
            } else {
                subtitle = L10n.format("Low battery alert (%d%%)", locale: locale, rule.threshold)
            }
        case .charged:
            title = L10n.format("%d%% Charged", locale: locale, battery.percentage)
            subtitle = L10n.format("Battery reached %d%% target", locale: locale, rule.threshold)
        }

        return ActiveAlertPresentation(
            id: UUID(),
            ruleID: rule.id,
            kind: rule.kind,
            title: title,
            subtitle: subtitle,
            percentage: battery.percentage,
            colorHex: rule.colorHex,
            showPopup: rule.showPopup,
            position: rule.position,
            sound: rule.sound,
            borderGlow: rule.borderGlow,
            persistent: rule.persistent,
            isChargingIcon: rule.kind == .charged || battery.isCharging
        )
    }

    static func powerSource(
        pluggedIn: Bool,
        battery: BatteryInfo,
        sound: AlertSoundOption,
        locale: Locale = Locale(identifier: "en")
    ) -> ActiveAlertPresentation {
        let title = pluggedIn
            ? L10n.string("Power Connected", locale: locale)
            : L10n.string("On Battery Power", locale: locale)
        let subtitle: String
        if pluggedIn {
            if let watts = battery.adapterWatts {
                subtitle = L10n.format("%dW Adapter • %d%%", locale: locale, watts, battery.percentage)
            } else {
                subtitle = L10n.format("Charging at %d%%", locale: locale, battery.percentage)
            }
        } else {
            subtitle = battery.timeRemainingMinutes != nil
                ? L10n.format("%@ remaining • %d%%", locale: locale, battery.formattedTimeRemaining(in: locale), battery.percentage)
                : L10n.format("Battery at %d%%", locale: locale, battery.percentage)
        }

        return ActiveAlertPresentation(
            id: UUID(),
            ruleID: nil,
            kind: nil,
            title: title,
            subtitle: subtitle,
            percentage: battery.percentage,
            colorHex: pluggedIn ? AlertColorPreset.green.rawValue : AlertColorPreset.orange.rawValue,
            showPopup: true,
            position: .topOfScreen,
            sound: sound,
            borderGlow: false,
            persistent: false,
            isChargingIcon: pluggedIn
        )
    }
}

extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let int = UInt64(cleaned, radix: 16) else {
            return nil
        }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }

    var hexString: String {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else {
            return "#FF3B30"
        }
        let r = Int((nsColor.redComponent * 255).rounded())
        let g = Int((nsColor.greenComponent * 255).rounded())
        let b = Int((nsColor.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
