import SwiftUI

struct BatteryOverviewView: View {
    @Bindable var appState: AppState

    private var battery: BatteryInfo { appState.batteryInfo }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                kpiCardsRow
                capacityDetailsCard
                liveTelemetryCard
                chartsPlaceholderCard
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSection: some View {
        HStack {
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

                Text("Real-time battery health, temperature, cycle count, and telemetry")
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

    private var chartsPlaceholderCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Battery Level & Daily Usage History")
                .font(.headline)
            Text("Historical timeline charts (6h, 12h, 24h, 7d, 14d) and daily discharge tracking will be added in Phase 4.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}
