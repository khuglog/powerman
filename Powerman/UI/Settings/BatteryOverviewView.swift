import Charts
import SwiftUI

struct BatteryOverviewView: View {
    @Bindable var appState: AppState
    @State private var selectedTimeframe: HistoryTimeframe = .twentyFourHours

    private var battery: BatteryInfo { appState.batteryInfo }

    private var filteredSamples: [BatteryHistorySample] {
        BatteryHistoryAnalytics.filter(appState.historySamples, timeframe: selectedTimeframe)
    }

    private var dailyUsageList: [DailyBatteryUsage] {
        BatteryHistoryAnalytics.dailyUsage(from: appState.historySamples)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                kpiCardsRow
                batteryLevelChartCard
                dailyUsageCard
                capacityDetailsCard
                cyclesAndTemperatureCard
                liveTelemetryCard
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.blue)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "battery.100percent")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    Text("Battery")
                        .font(.title2.bold())
                }

                Text("Daily usage, health, cycle, and temperature trends about your Mac over time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.refreshBattery()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    private var kpiCardsRow: some View {
        HStack(spacing: 12) {
            kpiCard(
                icon: "heart.fill",
                iconColor: .green,
                title: "HEALTH",
                value: battery.designCapacityMah > 0 ? "\(battery.roundedHealthPercentage)%" : "--",
                subtitle: battery.healthStatus.rawValue,
                subtitleColor: healthColor
            )

            kpiCard(
                icon: "thermometer.medium",
                iconColor: .green,
                title: "TEMPERATURE",
                value: battery.temperatureCelsius.map { String(format: "%.1f°C", $0) } ?? "--",
                subtitle: battery.temperatureStatus.rawValue,
                subtitleColor: temperatureColor
            )

            kpiCard(
                icon: "arrow.triangle.2.circlepath",
                iconColor: .blue,
                title: "CYCLES",
                value: "\(battery.cycleCount)",
                subtitle: "of \(battery.ratedCycleCount) rated",
                subtitleColor: .blue
            )
        }
    }

    private func kpiCard(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        subtitle: String,
        subtitleColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(subtitleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
    }

    private var batteryLevelChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Battery Level", systemImage: "battery.100percent")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    ForEach(HistoryTimeframe.allCases) { tf in
                        let isSelected = selectedTimeframe == tf
                        Button {
                            selectedTimeframe = tf
                        } label: {
                            Text(tf.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.green : Color.primary.opacity(0.07))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if filteredSamples.count < 2 {
                VStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Building your battery-level history — your charge timeline fills in as you use your Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("\(filteredSamples.count) sample collected in \(selectedTimeframe.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
            } else {
                Chart(filteredSamples) { sample in
                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Battery %", sample.percentage)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green.opacity(0.32), Color.green.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Battery %", sample.percentage)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 2.2))
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    timeXAxisMarks(desiredCount: 5)
                }
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        AxisValueLabel(anchor: .leading) {
                            if let intVal = value.as(Int.self) {
                                Text("\(intVal)%").font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 170)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var dailyUsageCard: some View {
        let days = Array(dailyUsageList.suffix(7))
        let totalTrackedDays = dailyUsageList.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text("DAILY USAGE")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                Text("• \(appState.historySamples.count) samples")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let today = days.last {
                    Text("Today: \(today.dischargedPercent)% used • \(today.activeHoursFormatted) on battery")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if days.isEmpty || days.allSatisfy({ $0.dischargedPercent == 0 && $0.activeOnBatteryMinutes == 0 }) {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("Building your daily usage")
                        .font(.subheadline.weight(.semibold))
                    Text("Powerman tracks battery discharge and active battery time across each day. Keep Powerman running to fill in your daily charts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                    Text("\(max(1, totalTrackedDays)) day(s) collected so far")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                Chart(days) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Discharged %", day.dischargedPercent)
                    )
                    .foregroundStyle(Color.green.gradient)
                    .cornerRadius(5)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(anchor: .top) {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.weekday(.abbreviated))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        AxisValueLabel(anchor: .leading) {
                            if let pct = value.as(Int.self) {
                                Text("\(pct)%").font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var capacityDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Battery Health", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if battery.designCapacityMah > 0 {
                    Text("\(battery.maxCapacityMah) / \(battery.designCapacityMah) mAh")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(battery.designCapacityMah > 0 ? "\(battery.roundedHealthPercentage)%" : "--")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(battery.healthStatus.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(healthColor)
            }

            ProgressView(value: Double(battery.roundedHealthPercentage), total: 100)
                .tint(healthColor)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var cyclesAndTemperatureCard: some View {
        let tempSamples = filteredSamples.filter { $0.temperatureCelsius != nil }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Battery Cycles & Temperature", systemImage: "thermometer.medium")
                    .font(.headline)
                Spacer()
                Text("\(battery.cycleCount) cycles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            ProgressView(value: Double(min(battery.cycleCount, battery.ratedCycleCount)), total: Double(max(1, battery.ratedCycleCount)))
                .tint(.blue)

            if tempSamples.count >= 2 {
                Chart(tempSamples) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Temp °C", sample.temperatureCelsius ?? 0)
                    )
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 20...55)
                .chartXAxis {
                    timeXAxisMarks(desiredCount: 4)
                }
                .chartYAxis {
                    AxisMarks(values: [20, 35, 50]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        AxisValueLabel(anchor: .leading) {
                            if let deg = value.as(Int.self) {
                                Text("\(deg)°C").font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 110)
                .padding(.top, 4)
            } else {
                Text("Temperature trend appears as more samples are collected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var liveTelemetryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Live Telemetry", systemImage: "waveform.path.ecg")
                .font(.headline)

            Divider()

            HStack(spacing: 24) {
                telemetryItem("Current Charge", "\(battery.percentage)% (\(battery.currentCapacityMah) mAh)")
                telemetryItem("Source", battery.chargingState.displayLabel)
                telemetryItem(
                    "Voltage",
                    battery.voltageMv.map { String(format: "%.2f V", Double($0) / 1000.0) } ?? "--"
                )
                telemetryItem(
                    "Power",
                    battery.wattage.map { String(format: "%.1f W", $0) } ?? "--"
                )
                telemetryItem(
                    "Adapter",
                    battery.adapterWatts.map { "\($0) W" } ?? (battery.isPluggedIn ? "Connected" : "Unplugged")
                )
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func telemetryItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }

    private var healthColor: Color {
        switch battery.healthStatus {
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .secondary
        }
    }

    private var temperatureColor: Color {
        switch battery.temperatureStatus {
        case .normal: return .green
        case .warm: return .orange
        case .hot: return .red
        case .unknown: return .secondary
        }
    }

    @AxisContentBuilder
    private func timeXAxisMarks(desiredCount: Int) -> some AxisContent {
        let format: Date.FormatStyle = selectedTimeframe.duration >= 7 * 86400
            ? .dateTime.month(.abbreviated).day()
            : .dateTime.hour().minute()
        AxisMarks(values: .automatic(desiredCount: desiredCount)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
            AxisValueLabel(anchor: .top) {
                if let date = value.as(Date.self) {
                    Text(date, format: format)
                        .font(.caption2)
                }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}
