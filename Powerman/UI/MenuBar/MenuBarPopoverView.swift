import SwiftUI

struct MenuBarPopoverView: View {
    @Bindable var appState: AppState
    @State private var isBatteryInfoExpanded = false
    @State private var isEnergyAppsExpanded = false
    @State private var isDevicesExpanded = true

    private var battery: BatteryInfo { appState.batteryInfo }

    private var accentStatusColor: Color {
        if battery.isCharging || battery.isFullyCharged {
            return .green
        } else if battery.percentage <= 10 {
            return .red
        } else if battery.percentage <= 20 {
            return .orange
        } else {
            return .green
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        VStack(spacing: 10) {
            batteryHeaderCard

            expandableBatteryInfoCard
            expandableEnergyAppsCard
            connectedDevicesCard

            actionMenuCard
        }
        .padding(12)
        .frame(width: 312)
        .background(.regularMaterial)
    }

    private var batteryHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(battery.percentage)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(accentStatusColor)
                        .monospacedDigit()
                    Text("%")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(accentStatusColor.opacity(0.8))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(battery.isCharging ? "TIME TO FULL" : "TIME LEFT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(battery.formattedTimeRemaining)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            }

            HStack(spacing: 6) {
                Image(systemName: battery.isCharging ? "bolt.fill" : "battery.100")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentStatusColor)
                Text(battery.chargingState.displayLabel)
                    .font(.system(size: 13, weight: .medium))
            }

            SegmentedBatteryProgressBar(
                percentage: battery.percentage,
                tint: accentStatusColor
            )
        }
        .padding(12)
        .background(cardBackground)
    }

    private var expandableBatteryInfoCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isBatteryInfoExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Battery Information")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Image(systemName: isBatteryInfoExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if isBatteryInfoExpanded {
                Divider().padding(.horizontal, 12)
                VStack(spacing: 6) {
                    infoRow("Health", value: "\(battery.roundedHealthPercentage)% (\(battery.healthStatus.rawValue))")
                    infoRow("Capacity", value: "\(battery.maxCapacityMah) / \(battery.designCapacityMah) mAh")
                    infoRow("Cycle Count", value: "\(battery.cycleCount) / \(battery.ratedCycleCount)")
                    if let temp = battery.temperatureCelsius {
                        infoRow("Temperature", value: String(format: "%.1f°C (%@)", temp, battery.temperatureStatus.rawValue))
                    }
                    if let wattage = battery.wattage {
                        infoRow("Power Draw", value: String(format: "%.1f W", wattage))
                    }
                    if let adapterWatts = battery.adapterWatts {
                        infoRow("Adapter", value: "\(adapterWatts) W")
                    }
                }
                .padding(12)
            }
        }
        .background(cardBackground)
    }

    private var expandableEnergyAppsCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isEnergyAppsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.circle")
                        .foregroundStyle(.secondary)
                    Text("Apps Using Significant Energy")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Image(systemName: isEnergyAppsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if isEnergyAppsExpanded {
                Divider().padding(.horizontal, 12)
                Text("Energy consumer monitoring will be added in Phase 4.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        .background(cardBackground)
    }

    private var connectedDevicesCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "airpodspro")
                    .foregroundStyle(.secondary)
                Text("Connected Devices")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button {
                    appState.refreshBattery()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isDevicesExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isDevicesExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if isDevicesExpanded {
                Divider().padding(.horizontal, 12)
                Text("Bluetooth peripheral battery tracking coming in Phase 3.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        .background(cardBackground)
    }

    private var actionMenuCard: some View {
        VStack(spacing: 0) {
            actionRow(icon: "gearshape.fill", title: "Settings...", showChevron: true) {
                appState.openSettings(tab: .menuBar)
            }
            Divider().padding(.leading, 36)
            actionRow(icon: "battery.100", title: "Battery Settings...", showChevron: true) {
                appState.openSystemBatterySettings()
            }
            Divider().padding(.leading, 36)
            Button {
                appState.quit()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "power")
                        .foregroundStyle(.red)
                        .frame(width: 18)
                    Text("Quit Powerman")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("v\(appVersion)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
        }
        .background(cardBackground)
    }

    private func actionRow(
        icon: String,
        title: String,
        showChevron: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.primary.opacity(0.75))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

private struct SegmentedBatteryProgressBar: View {
    let percentage: Int
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.08))

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * CGFloat(percentage) / 100.0))

                HStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)).frame(width: 1)
                    Spacer()
                    Rectangle().fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)).frame(width: 1)
                    Spacer()
                    Rectangle().fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)).frame(width: 1)
                    Spacer()
                }
            }
        }
        .frame(height: 8)
    }
}
