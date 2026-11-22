import Foundation

enum BatteryHealthStatus: String, Sendable, Equatable {
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case unknown = "Unknown"

    func localizedTitle(in locale: Locale) -> String {
        L10n.string(rawValue, locale: locale)
    }
}

enum TemperatureStatus: String, Sendable, Equatable {
    case normal = "Normal"
    case warm = "Warm"
    case hot = "Hot"
    case unknown = "Unknown"

    func localizedTitle(in locale: Locale) -> String {
        L10n.string(rawValue, locale: locale)
    }
}

enum ChargingState: Sendable, Equatable {
    case onBattery
    case charging
    case charged
    case pluggedNotCharging

    var displayLabel: String {
        displayLabel(in: Locale(identifier: "en"))
    }

    func displayLabel(in locale: Locale) -> String {
        switch self {
        case .onBattery:
            return L10n.string("On Battery", locale: locale)
        case .charging:
            return L10n.string("Charging", locale: locale)
        case .charged:
            return L10n.string("Fully Charged", locale: locale)
        case .pluggedNotCharging:
            return L10n.string("Plugged In (Not Charging)", locale: locale)
        }
    }
}

struct BatteryInfo: Sendable, Equatable {
    let percentage: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let isFullyCharged: Bool
    let timeRemainingMinutes: Int?
    let cycleCount: Int
    let ratedCycleCount: Int
    let designCapacityMah: Int
    let maxCapacityMah: Int
    let currentCapacityMah: Int
    let temperatureCelsius: Double?
    let voltageMv: Int?
    let amperageMa: Int?
    let batteryPowerMw: Int?
    let adapterWatts: Int?
    let adapterName: String?
    let hasBattery: Bool
    let lastUpdated: Date

    var chargingState: ChargingState {
        if isFullyCharged && isPluggedIn {
            return .charged
        } else if isCharging {
            return .charging
        } else if isPluggedIn {
            return .pluggedNotCharging
        } else {
            return .onBattery
        }
    }

    var healthPercentage: Double {
        guard designCapacityMah > 0, maxCapacityMah > 0 else { return 0 }
        let ratio = (Double(maxCapacityMah) / Double(designCapacityMah)) * 100.0
        return min(max(ratio, 0), 100)
    }

    var roundedHealthPercentage: Int {
        Int(healthPercentage.rounded())
    }

    var healthStatus: BatteryHealthStatus {
        guard designCapacityMah > 0, maxCapacityMah > 0 else { return .unknown }
        let health = healthPercentage
        if health >= 80 {
            return .good
        } else if health >= 60 {
            return .fair
        } else {
            return .poor
        }
    }

    var temperatureStatus: TemperatureStatus {
        guard let temp = temperatureCelsius else { return .unknown }
        if temp < 38.0 {
            return .normal
        } else if temp < 45.0 {
            return .warm
        } else {
            return .hot
        }
    }

    var wattage: Double? {
        if let voltageMv, let amperageMa {
            return (Double(voltageMv) * Double(abs(amperageMa))) / 1_000_000.0
        }
        if let batteryPowerMw {
            return Double(abs(batteryPowerMw)) / 1_000.0
        }
        return nil
    }

    var formattedTimeRemaining: String {
        formattedTimeRemaining(in: Locale(identifier: "en"))
    }

    func formattedTimeRemaining(in locale: Locale) -> String {
        guard let minutes = timeRemainingMinutes, minutes > 0 else {
            return isFullyCharged ? L10n.string("Full", locale: locale) : "--"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return L10n.format("%dh %dm", locale: locale, hours, mins)
        } else {
            return L10n.format("%dm", locale: locale, mins)
        }
    }

    /// Returns true when user-visible status bar fields (percentage, charging state, adapter, time) differ from `previous`.
    func hasVisualOrStatusChange(from previous: BatteryInfo) -> Bool {
        hasBattery != previous.hasBattery
            || percentage != previous.percentage
            || isCharging != previous.isCharging
            || isPluggedIn != previous.isPluggedIn
            || isFullyCharged != previous.isFullyCharged
            || adapterWatts != previous.adapterWatts
            || timeRemainingMinutes != previous.timeRemainingMinutes
    }

    /// Returns true when any hardware telemetry value differs from `previous` (ignoring `lastUpdated`).
    func hasTelemetryChange(from previous: BatteryInfo) -> Bool {
        hasVisualOrStatusChange(from: previous)
            || temperatureCelsius != previous.temperatureCelsius
            || cycleCount != previous.cycleCount
            || maxCapacityMah != previous.maxCapacityMah
            || currentCapacityMah != previous.currentCapacityMah
            || voltageMv != previous.voltageMv
            || amperageMa != previous.amperageMa
            || batteryPowerMw != previous.batteryPowerMw
            || adapterName != previous.adapterName
    }

    static let placeholder = BatteryInfo(
        percentage: 0,
        isCharging: false,
        isPluggedIn: false,
        isFullyCharged: false,
        timeRemainingMinutes: nil,
        cycleCount: 0,
        ratedCycleCount: 1000,
        designCapacityMah: 0,
        maxCapacityMah: 0,
        currentCapacityMah: 0,
        temperatureCelsius: nil,
        voltageMv: nil,
        amperageMa: nil,
        batteryPowerMw: nil,
        adapterWatts: nil,
        adapterName: nil,
        hasBattery: false,
        lastUpdated: Date()
    )
}

enum BatterySnapshotParser {
    /// Parses combined IOPS power source description, `AppleSmartBattery`, and `AppleSmartBatteryPack` IORegistry dictionaries into `BatteryInfo`.
    static func parse(
        iops: [String: Any]?,
        smartBattery: [String: Any]?,
        smartBatteryPack: [String: Any]? = nil,
        now: Date = Date()
    ) -> BatteryInfo {
        let hasBattery = (smartBattery != nil) || (smartBatteryPack != nil) || (iops != nil)
        guard hasBattery else { return .placeholder }

        let smartBatteryData = smartBattery?["BatteryData"] as? [String: Any]
        let chargerData = smartBattery?["ChargerData"] as? [String: Any]
        let packBatteryData = smartBatteryPack?["BatteryData"] as? [String: Any]
        let dictionaries: [[String: Any]?] = [smartBattery, smartBatteryData, packBatteryData, smartBatteryPack]

        let currentCapIOPS = intValue(iops?["Current Capacity"])
        let maxCapIOPS = intValue(iops?["Max Capacity"])
        let percentageFromIOPS: Int? = {
            guard let cur = currentCapIOPS, let maxVal = maxCapIOPS, maxVal > 0 else { return nil }
            return Int(((Double(cur) / Double(maxVal)) * 100.0).rounded())
        }()

        let currentCapRaw = firstInt(forKeys: ["AppleRawCurrentCapacity", "RemainingCapacity"], in: dictionaries)
            ?? validRawCapacityFallback(firstInt(forKeys: ["CurrentCapacity"], in: dictionaries))
            ?? 0

        let maxCapRaw = firstInt(forKeys: ["AppleRawMaxCapacity", "FullChargeCapacity", "NominalChargeCapacity"], in: dictionaries)
            ?? validRawCapacityFallback(firstInt(forKeys: ["MaxCapacity"], in: dictionaries))
            ?? 0

        let designCapRaw = firstInt(forKeys: ["DesignCapacity"], in: dictionaries) ?? 0

        let percentageFromSmartBattery: Int? = {
            if let pct = firstInt(forKeys: ["CurrentCapacity"], in: dictionaries), pct <= 100,
               firstInt(forKeys: ["MaxCapacity"], in: dictionaries) == 100 {
                return pct
            }
            if maxCapRaw > 0, currentCapRaw > 0 {
                return Int(((Double(currentCapRaw) / Double(maxCapRaw)) * 100.0).rounded())
            }
            return nil
        }()

        let percentage = min(max(percentageFromIOPS ?? percentageFromSmartBattery ?? 0, 0), 100)

        let powerSourceState = iops?["Power Source State"] as? String
        let isPluggedIn = boolValue(smartBattery?["ExternalConnected"])
            ?? (powerSourceState == "AC Power")

        // Prefer live kernel IORegistry flags over IOPS cache (powerd can lag behind AppleSmartBattery during transitions).
        let isCharging = boolValue(smartBattery?["IsCharging"])
            ?? boolValue(chargerData?["IsCharging"])
            ?? boolValue(iops?["Is Charging"])
            ?? false

        let isFullyCharged = boolValue(smartBattery?["FullyCharged"])
            ?? boolValue(smartBatteryData?["FullyCharged"])
            ?? boolValue(iops?["Is Charged"])
            ?? (isPluggedIn && !isCharging && percentage >= 100)

        let timeRemainingMinutes: Int? = {
            if isCharging {
                if let toFull = intValue(iops?["Time to Full Charge"]), toFull > 0, toFull < 10_000 {
                    return toFull
                }
                if let avgToFull = firstInt(forKeys: ["AvgTimeToFull"], in: dictionaries), avgToFull > 0, avgToFull < 10_000 {
                    return avgToFull
                }
            } else if !isPluggedIn {
                if let toEmpty = intValue(iops?["Time to Empty"]), toEmpty > 0, toEmpty < 10_000 {
                    return toEmpty
                }
                if let avgToEmpty = firstInt(forKeys: ["AvgTimeToEmpty"], in: dictionaries), avgToEmpty > 0, avgToEmpty < 10_000 {
                    return avgToEmpty
                }
            }
            return nil
        }()

        let cycleCount = firstInt(forKeys: ["CycleCount"], in: dictionaries) ?? 0
        let designCycleCount = firstInt(forKeys: ["DesignCycleCount9C"], in: dictionaries) ?? 1000

        let rawTemp = firstValue(forKeys: ["Temperature", "VirtualTemperature"], in: dictionaries)
        let temperatureCelsius = parseTemperatureCelsius(rawTemp)

        let voltageMv = firstInt(forKeys: ["Voltage", "AppleRawBatteryVoltage"], in: dictionaries)
        let amperageMa = firstInt(forKeys: ["InstantAmperage", "Amperage"], in: dictionaries)
        let batteryPowerMw = firstInt(forKeys: ["BatteryPower"], in: dictionaries)

        let adapterDict = smartBattery?["AdapterDetails"] as? [String: Any]
        let adapterWatts = intValue(adapterDict?["Watts"])
        let adapterName = (adapterDict?["Name"] as? String) ?? (adapterDict?["Description"] as? String)

        return BatteryInfo(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            isFullyCharged: isFullyCharged,
            timeRemainingMinutes: timeRemainingMinutes,
            cycleCount: cycleCount,
            ratedCycleCount: designCycleCount,
            designCapacityMah: designCapRaw,
            maxCapacityMah: maxCapRaw,
            currentCapacityMah: currentCapRaw,
            temperatureCelsius: temperatureCelsius,
            voltageMv: voltageMv,
            amperageMa: amperageMa,
            batteryPowerMw: batteryPowerMw,
            adapterWatts: adapterWatts,
            adapterName: adapterName,
            hasBattery: true,
            lastUpdated: now
        )
    }

    /// Converts AppleSmartBattery `Temperature` (centi-Kelvin > 10,000; centi-Celsius 1,500...9,999; deci-Celsius 150...1,499) to Celsius.
    static func parseTemperatureCelsius(_ value: Any?) -> Double? {
        guard let raw = intValue(value), raw > 0 else { return nil }
        let celsius: Double
        if raw > 10_000 {
            celsius = (Double(raw) / 100.0) - 273.15
        } else if raw >= 1_500 {
            celsius = Double(raw) / 100.0
        } else if raw >= 150 {
            celsius = Double(raw) / 10.0
        } else {
            celsius = Double(raw)
        }
        guard celsius > -20 && celsius < 120 else { return nil }
        return (celsius * 10.0).rounded() / 10.0
    }

    private static func firstInt(forKeys keys: [String], in dictionaries: [[String: Any]?]) -> Int? {
        for key in keys {
            for dict in dictionaries {
                if let val = intValue(dict?[key]) {
                    return val
                }
            }
        }
        return nil
    }

    private static func firstValue(forKeys keys: [String], in dictionaries: [[String: Any]?]) -> Any? {
        for key in keys {
            for dict in dictionaries {
                if let val = dict?[key] {
                    return val
                }
            }
        }
        return nil
    }

    private static func validRawCapacityFallback(_ num: Int?) -> Int? {
        guard let num, num > 200 else { return nil }
        return num
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let intVal = value as? Int {
            return intVal
        }
        if let num = value as? NSNumber {
            return Int(truncatingIfNeeded: num.int64Value)
        }
        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let boolVal = value as? Bool {
            return boolVal
        }
        if let num = value as? NSNumber {
            return num.boolValue
        }
        return nil
    }
}
