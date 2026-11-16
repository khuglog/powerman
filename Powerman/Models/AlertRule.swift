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
        switch self {
        case .topOfScreen: return "Top of Screen"
        case .centerOfScreen: return "Center of Screen"
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
        switch self {
        case .none: return "None (Silent)"
        case .criticalAlarm: return "Critical Alarm (Urgent)"
        case .urgentBeep: return "Urgent Double Beep"
        case .lowWarning: return "Low Battery Warning"
        case .chargedChime: return "Charged Success Chime"
        case .powerConnect: return "Power Connect"
        case .powerDisconnect: return "Power Disconnect"
        case .radarPulse: return "Radar Pulse"
        case .softBell: return "Soft Bell"
        case .glass: return "macOS Glass"
        case .hero: return "macOS Hero"
        case .ping: return "macOS Ping"
        case .pop: return "macOS Pop"
        case .tink: return "macOS Tink"
        case .submarine: return "macOS Submarine"
        case .sosumi: return "macOS Sosumi"
        case .blow: return "macOS Blow"
        case .bottle: return "macOS Bottle"
        case .frog: return "macOS Frog"
        case .funk: return "macOS Funk"
        case .morse: return "macOS Morse"
        case .purr: return "macOS Purr"
        case .basso: return "macOS Basso"
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
        var parts: [String] = []
        if showPopup {
            parts.append(position.title)
        }
        if borderGlow {
            parts.append("Border Glow")
        }
        if sound != .none {
            parts.append(sound.title)
        }
        if persistent {
            parts.append("Persistent")
        }
        return parts.isEmpty ? "Silent" : parts.joined(separator: " • ")
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

    static func from(rule: AlertRule, battery: BatteryInfo) -> ActiveAlertPresentation {
        let title: String
        let subtitle: String
        switch rule.kind {
        case .lowBattery:
            title = "\(battery.percentage)% Remaining"
            if let mins = battery.timeRemainingMinutes, mins > 0 {
                subtitle = "\(mins)min until empty"
            } else {
                subtitle = "Low battery alert (\(rule.threshold)%)"
            }
        case .charged:
            title = "\(battery.percentage)% Charged"
            subtitle = "Battery reached \(rule.threshold)% target"
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

    static func powerSource(pluggedIn: Bool, battery: BatteryInfo, sound: AlertSoundOption) -> ActiveAlertPresentation {
        let title = pluggedIn ? "Power Connected" : "On Battery Power"
        let subtitle: String
        if pluggedIn {
            if let watts = battery.adapterWatts {
                subtitle = "\(watts)W Adapter • \(battery.percentage)%"
            } else if battery.isCharging {
                subtitle = "Charging at \(battery.percentage)%"
            } else {
                subtitle = "Negotiating USB-C Power • \(battery.percentage)%"
            }
        } else {
            subtitle = battery.timeRemainingMinutes != nil
                ? "\(battery.formattedTimeRemaining) remaining • \(battery.percentage)%"
                : "Battery at \(battery.percentage)%"
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
