import Darwin
import XCTest
@testable import Powerman

final class BatteryHistoryTests: XCTestCase {
    private func makeSample(
        minutesAgo: Double,
        percentage: Int,
        isCharging: Bool = false,
        isPluggedIn: Bool = false,
        temperature: Double? = 32.0,
        referenceDate: Date = Date()
    ) -> BatteryHistorySample {
        BatteryHistorySample(
            timestamp: referenceDate.addingTimeInterval(-minutesAgo * 60),
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            temperatureCelsius: temperature,
            cycleCount: 167,
            healthPercentage: 92,
            maxCapacityMah: 5719,
            wattage: 11.5
        )
    }

    func testTimeframeFilteringAndPruning() {
        let now = Date()
        let samples = [
            makeSample(minutesAgo: 15 * 24 * 60, percentage: 90, referenceDate: now), // 15 days ago -> pruned
            makeSample(minutesAgo: 8 * 24 * 60, percentage: 80, referenceDate: now),  // 8 days ago -> kept in 14d
            makeSample(minutesAgo: 120, percentage: 65, referenceDate: now),          // 2h ago -> kept in 6h
            makeSample(minutesAgo: 10, percentage: 60, referenceDate: now)            // 10m ago
        ]

        let pruned = BatteryHistoryAnalytics.pruneExpired(samples, referenceDate: now)
        XCTAssertEqual(pruned.count, 3)

        let sixHours = BatteryHistoryAnalytics.filter(pruned, timeframe: .sixHours, referenceDate: now)
        XCTAssertEqual(sixHours.map(\.percentage), [65, 60])

        let fourteenDays = BatteryHistoryAnalytics.filter(pruned, timeframe: .fourteenDays, referenceDate: now)
        XCTAssertEqual(fourteenDays.count, 3)
    }

    func testDailyUsageComputesDischargeAndIgnoresLargeSleepGaps() {
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

        let samples = [
            BatteryHistorySample(timestamp: noon.addingTimeInterval(-3600), percentage: 80, isCharging: false, isPluggedIn: false, temperatureCelsius: 30, cycleCount: 167, healthPercentage: 92, maxCapacityMah: 5719, wattage: 10),
            // 2 hours gap (> 15 min sleep gap) -> ignored
            BatteryHistorySample(timestamp: noon, percentage: 75, isCharging: false, isPluggedIn: false, temperatureCelsius: 32, cycleCount: 167, healthPercentage: 92, maxCapacityMah: 5719, wattage: 10),
            // 5 minutes later -> -4% discharge
            BatteryHistorySample(timestamp: noon.addingTimeInterval(300), percentage: 71, isCharging: false, isPluggedIn: false, temperatureCelsius: 34, cycleCount: 167, healthPercentage: 92, maxCapacityMah: 5719, wattage: 12),
            // 5 minutes later -> -3% discharge
            BatteryHistorySample(timestamp: noon.addingTimeInterval(600), percentage: 68, isCharging: false, isPluggedIn: false, temperatureCelsius: 34, cycleCount: 167, healthPercentage: 92, maxCapacityMah: 5719, wattage: 12)
        ]

        let daily = BatteryHistoryAnalytics.dailyUsage(from: samples, calendar: calendar)
        XCTAssertEqual(daily.count, 1)
        XCTAssertEqual(daily[0].dischargedPercent, 7)
        XCTAssertEqual(daily[0].activeOnBatteryMinutes, 10)
    }

    @MainActor
    func testJSONHistoryStorePersistsAndRespectsInterval() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("powerman_history_test_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let now = Date()
        let baseInfo = BatteryInfo(
            percentage: 70, isCharging: false, isPluggedIn: false, isFullyCharged: false,
            timeRemainingMinutes: 150, cycleCount: 167, ratedCycleCount: 1000,
            designCapacityMah: 6249, maxCapacityMah: 5719, currentCapacityMah: 4000,
            temperatureCelsius: 32.0, voltageMv: 11800, amperageMa: -1000, batteryPowerMw: nil,
            adapterWatts: nil, adapterName: nil, hasBattery: true, lastUpdated: now
        )

        let store = JSONBatteryHistoryStore(fileURL: tempURL)
        XCTAssertTrue(store.recordIfNeeded(from: baseInfo))
        // 5 seconds later, same state -> should skip
        let tooSoon = BatteryInfo(
            percentage: 70, isCharging: false, isPluggedIn: false, isFullyCharged: false,
            timeRemainingMinutes: 150, cycleCount: 167, ratedCycleCount: 1000,
            designCapacityMah: 6249, maxCapacityMah: 5719, currentCapacityMah: 4000,
            temperatureCelsius: 32.0, voltageMv: 11800, amperageMa: -1000, batteryPowerMw: nil,
            adapterWatts: nil, adapterName: nil, hasBattery: true, lastUpdated: now.addingTimeInterval(5)
        )
        XCTAssertFalse(store.recordIfNeeded(from: tooSoon))

        // Reload from disk
        let reloaded = JSONBatteryHistoryStore(fileURL: tempURL)
        reloaded.load()
        XCTAssertEqual(reloaded.samples.count, 1)
        XCTAssertEqual(reloaded.samples[0].percentage, 70)
    }

    func testEnergyConsumerRollsHelperProcessesUpToParentApp() {
        let t0 = Date()
        let t1 = t0.addingTimeInterval(1.0) // 1 second wall clock
        let timebase = mach_timebase_info_data_t(numer: 1, denom: 1) // 1 tick = 1 ns

        // Helper PID 200 uses 0.5s CPU -> 50% CPU, rolled into parent App PID 100
        let baseline: (Date, [pid_t: UInt64]) = (t0, [100: 1_000_000_000, 200: 1_000_000_000, 300: 1_000_000_000])
        let current: (Date, [pid_t: UInt64]) = (t1, [100: 1_050_000_000, 200: 1_500_000_000, 300: 1_100_000_000])

        let parents: [pid_t: pid_t] = [200: 100]
        let apps: [pid_t: (name: String, bundleID: String?)] = [
            100: ("Chrome", "com.google.Chrome"),
            300: ("Notes", "com.apple.Notes")
        ]

        let result = ProcessEnergyConsumerService.computeTopConsumers(
            from: baseline,
            to: current,
            parentByPID: parents,
            appPIDs: apps,
            machTimebase: timebase
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "Chrome")
        XCTAssertEqual(result[0].cpuPercent, 55.0, accuracy: 0.1)
        XCTAssertEqual(result[1].name, "Notes")
        XCTAssertEqual(result[1].cpuPercent, 10.0, accuracy: 0.1)
    }
}
