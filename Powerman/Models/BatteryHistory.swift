import Foundation

enum HistoryTimeframe: String, CaseIterable, Identifiable, Sendable {
    case sixHours = "6h"
    case twelveHours = "12h"
    case twentyFourHours = "24h"
    case sevenDays = "7d"
    case fourteenDays = "14d"

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .sixHours: return 6 * 3600
        case .twelveHours: return 12 * 3600
        case .twentyFourHours: return 24 * 3600
        case .sevenDays: return 7 * 24 * 3600
        case .fourteenDays: return 14 * 24 * 3600
        }
    }
}

struct BatteryHistorySample: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let percentage: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let temperatureCelsius: Double?
    let cycleCount: Int
    let healthPercentage: Double
    let maxCapacityMah: Int
    let wattage: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        percentage: Int,
        isCharging: Bool,
        isPluggedIn: Bool,
        temperatureCelsius: Double?,
        cycleCount: Int,
        healthPercentage: Double,
        maxCapacityMah: Int,
        wattage: Double?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.temperatureCelsius = temperatureCelsius
        self.cycleCount = cycleCount
        self.healthPercentage = healthPercentage
        self.maxCapacityMah = maxCapacityMah
        self.wattage = wattage
    }

    init(from info: BatteryInfo) {
        self.init(
            timestamp: info.lastUpdated,
            percentage: info.percentage,
            isCharging: info.isCharging,
            isPluggedIn: info.isPluggedIn,
            temperatureCelsius: info.temperatureCelsius,
            cycleCount: info.cycleCount,
            healthPercentage: info.healthPercentage,
            maxCapacityMah: info.maxCapacityMah,
            wattage: info.wattage
        )
    }
}

struct DailyBatteryUsage: Identifiable, Equatable, Sendable {
    let date: Date
    let dischargedPercent: Int
    let activeOnBatteryMinutes: Int
    let averageTemperature: Double?

    var id: Date { date }

    var activeHoursFormatted: String {
        let hours = activeOnBatteryMinutes / 60
        let mins = activeOnBatteryMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

enum BatteryHistoryAnalytics {
    static let maxRetentionDays: TimeInterval = 14 * 24 * 3600

    static func shouldRecord(
        newSample: BatteryHistorySample,
        lastSample: BatteryHistorySample?,
        minimumInterval: TimeInterval = 120
    ) -> Bool {
        guard let last = lastSample else { return true }
        if newSample.isPluggedIn != last.isPluggedIn || newSample.isCharging != last.isCharging {
            return true
        }
        let elapsed = newSample.timestamp.timeIntervalSince(last.timestamp)
        if elapsed >= minimumInterval {
            return true
        }
        if abs(newSample.percentage - last.percentage) >= 1 && elapsed >= 30 {
            return true
        }
        return false
    }

    static func filter(
        _ samples: [BatteryHistorySample],
        timeframe: HistoryTimeframe,
        referenceDate: Date = Date()
    ) -> [BatteryHistorySample] {
        let cutoff = referenceDate.addingTimeInterval(-timeframe.duration)
        return samples
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
    }

    static func pruneExpired(
        _ samples: [BatteryHistorySample],
        referenceDate: Date = Date()
    ) -> [BatteryHistorySample] {
        let cutoff = referenceDate.addingTimeInterval(-maxRetentionDays)
        return samples
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
    }

    static func dailyUsage(
        from samples: [BatteryHistorySample],
        calendar: Calendar = .current
    ) -> [DailyBatteryUsage] {
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty else { return [] }

        var dischargedByDay: [Date: Int] = [:]
        var activeSecondsByDay: [Date: TimeInterval] = [:]
        var tempsByDay: [Date: [Double]] = [:]

        for (index, sample) in sorted.enumerated() {
            let day = calendar.startOfDay(for: sample.timestamp)
            if let temp = sample.temperatureCelsius {
                tempsByDay[day, default: []].append(temp)
            }
            if dischargedByDay[day] == nil {
                dischargedByDay[day] = 0
                activeSecondsByDay[day] = 0
            }

            guard index > 0 else { continue }
            let previous = sorted[index - 1]
            let gap = sample.timestamp.timeIntervalSince(previous.timestamp)

            // Ignore large sleep gaps (> 15 min) when computing active usage and discharge deltas.
            guard gap > 0, gap <= 900 else { continue }

            if !sample.isPluggedIn && !previous.isPluggedIn {
                activeSecondsByDay[day, default: 0] += gap
            }

            if !sample.isCharging && sample.percentage < previous.percentage {
                dischargedByDay[day, default: 0] += (previous.percentage - sample.percentage)
            }
        }

        return dischargedByDay.keys.sorted().map { day in
            let temps = tempsByDay[day] ?? []
            let avgTemp: Double? = temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count)
            return DailyBatteryUsage(
                date: day,
                dischargedPercent: dischargedByDay[day] ?? 0,
                activeOnBatteryMinutes: Int(((activeSecondsByDay[day] ?? 0) / 60.0).rounded()),
                averageTemperature: avgTemp
            )
        }
    }
}
