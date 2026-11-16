import Foundation

enum DeviceCategory: String, Codable, Sendable, CaseIterable {
    case earbuds
    case headphones
    case mouse
    case keyboard
    case trackpad
    case phone
    case tablet
    case gamepad
    case other

    var symbolName: String {
        switch self {
        case .earbuds: return "airpodspro"
        case .headphones: return "headphones"
        case .mouse: return "computermouse.fill"
        case .keyboard: return "keyboard.fill"
        case .trackpad: return "rectangle.and.hand.point.up.left.fill"
        case .phone: return "iphone"
        case .tablet: return "ipad"
        case .gamepad: return "gamecontroller.fill"
        case .other: return "wave.3.right"
        }
    }

    static func infer(fromMinorType minorType: String?, name: String) -> DeviceCategory {
        let lowerMinor = (minorType ?? "").lowercased()
        let lowerName = name.lowercased()

        if lowerName.contains("airpods") || lowerName.contains("buds") || lowerName.contains("beats") {
            return .earbuds
        }
        if lowerMinor.contains("headphone") || lowerMinor.contains("headset") || lowerName.contains("headphone") {
            return .headphones
        }
        if lowerMinor.contains("mouse") || lowerName.contains("mouse") {
            return .mouse
        }
        if lowerMinor.contains("keyboard") || lowerName.contains("keyboard") {
            return .keyboard
        }
        if lowerMinor.contains("trackpad") || lowerName.contains("trackpad") {
            return .trackpad
        }
        if lowerMinor.contains("phone") || lowerName.contains("iphone") {
            return .phone
        }
        if lowerName.contains("ipad") {
            return .tablet
        }
        if lowerMinor.contains("gamepad") || lowerMinor.contains("joystick") || lowerName.contains("controller") || lowerName.contains("dualsense") || lowerName.contains("xbox") {
            return .gamepad
        }
        return .other
    }
}

struct BluetoothDeviceBattery: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var category: DeviceCategory
    var batteryPercentage: Int?
    var leftBattery: Int?
    var rightBattery: Int?
    var caseBattery: Int?
    var isApproximate: Bool
    var isConnected: Bool
    var lastUpdated: Date

    var displayPercentage: Int? {
        if let batteryPercentage {
            return batteryPercentage
        }
        let buds = [leftBattery, rightBattery].compactMap { $0 }
        return buds.min()
    }

    var formattedPercentage: String {
        guard let pct = displayPercentage else { return "--" }
        return isApproximate ? "~\(pct)%" : "\(pct)%"
    }

    var subBatterySummary: String? {
        var parts: [String] = []
        if let leftBattery { parts.append("L \(leftBattery)%") }
        if let rightBattery { parts.append("R \(rightBattery)%") }
        if let caseBattery { parts.append("Case \(caseBattery)%") }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

struct DeviceUserPreference: Codable, Equatable, Sendable {
    var isPinnedToMenuBar: Bool = false
    var isHiddenFromDropdown: Bool = false
    var lowBatteryAlertThreshold: Int? = nil
    var pinOrder: Int = 0
}
