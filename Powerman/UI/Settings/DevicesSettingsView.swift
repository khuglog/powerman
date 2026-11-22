import SwiftUI

struct DevicesSettingsView: View {
    @Bindable var appState: AppState

    private var settings: AppSettings { appState.settings }
    private var locale: Locale { appState.effectiveLocale }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection
                bluetoothToggleSection
                detectedDevicesSection
                tipsLegendSection
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
                        .fill(.cyan)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "airpodspro")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    Text(L10n.string("Devices", locale: locale))
                        .font(.title2.bold())
                }

                Text(L10n.string("Monitor battery levels of your AirPods, Beats, Magic Mouse, Keyboard, Trackpad, and other paired Bluetooth devices.", locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.refreshDevices()
            } label: {
                Label(L10n.string("Refresh", locale: locale), systemImage: "arrow.clockwise")
            }
        }
    }

    private var bluetoothToggleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.string("Bluetooth Devices", locale: locale), systemImage: "dot.radiowaves.left.and.right")
                .font(.headline)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.blue.opacity(0.14))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "airpodspro")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("Show Connected Devices", locale: locale))
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.string("Display battery levels for paired Bluetooth devices in the menu bar dropdown", locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { settings.showBluetoothDevices },
                    set: { settings.showBluetoothDevices = $0 }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private var detectedDevicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.string("Detected Devices", locale: locale), systemImage: "sensor.tag.radiowaves.forward")
                .font(.headline)

            if appState.bluetoothDevices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "wave.3.right.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(L10n.string("No Bluetooth devices detected yet", locale: locale))
                        .font(.subheadline.weight(.semibold))
                    Text(L10n.string("Pair your AirPods, Magic Mouse, Keyboard, or other Bluetooth accessories in System Settings → Bluetooth, then click Refresh.", locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(cardBackground)
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.bluetoothDevices) { device in
                        deviceCard(device)
                    }
                }
            }
        }
    }

    private func deviceCard(_ device: BluetoothDeviceBattery) -> some View {
        let pref = settings.preference(for: device.id)

        return HStack(spacing: 12) {
            Image(systemName: device.category.symbolName)
                .font(.system(size: 18))
                .foregroundStyle(device.isConnected ? Color.primary : Color.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.system(size: 13.5, weight: .semibold))

                    if !device.isConnected {
                        Text(L10n.string("Offline", locale: locale))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                    }
                }

                HStack(spacing: 8) {
                    Text(device.displayPercentage != nil ? device.formattedPercentage : L10n.string("Battery not reported", locale: locale))
                        .font(.caption.weight(.medium))
                        .foregroundStyle((device.displayPercentage ?? 100) <= 15 ? .red : .secondary)

                    if let sub = device.subBatterySummary {
                        Text("(\(sub))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let threshold = pref.lowBatteryAlertThreshold {
                        Text(L10n.format("• Alert < %d%%", locale: locale, threshold))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // Bell alert menu
            ZStack {
                Circle()
                    .fill(pref.lowBatteryAlertThreshold != nil ? Color.orange.opacity(0.14) : Color.primary.opacity(0.06))
                    .frame(width: 28, height: 28)

                Image(systemName: pref.lowBatteryAlertThreshold != nil ? "bell.fill" : "bell.slash")
                    .font(.system(size: 12))
                    .foregroundStyle(pref.lowBatteryAlertThreshold != nil ? Color.orange : Color.secondary)

                Menu {
                    Button(L10n.string("Off", locale: locale)) {
                        settings.setDeviceAlertThreshold(nil, for: device.id)
                    }
                    Divider()
                    ForEach([10, 15, 20, 30], id: \.self) { level in
                        Button(L10n.format("Alert below %d%%", locale: locale, level)) {
                            settings.setDeviceAlertThreshold(level, for: device.id)
                        }
                    }
                } label: {
                    Color.clear
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 28, height: 28)
                .accessibilityLabel(L10n.format("Set low battery alert for %@", locale: locale, device.name))
            }
            .help(L10n.string("Set low battery alert for this device", locale: locale))

            // Pin to menu bar
            Button {
                settings.togglePinDevice(device.id)
            } label: {
                Image(systemName: pref.isPinnedToMenuBar ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundStyle(pref.isPinnedToMenuBar ? Color.cyan : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(pref.isPinnedToMenuBar ? Color.cyan.opacity(0.16) : Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help(L10n.string("Pin battery percentage to the menu bar", locale: locale))

            // Hide from dropdown
            Button {
                settings.toggleHideDevice(device.id)
            } label: {
                Image(systemName: pref.isHiddenFromDropdown ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(pref.isHiddenFromDropdown ? Color.secondary : Color.primary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help(L10n.string(pref.isHiddenFromDropdown ? "Show in menu bar dropdown" : "Hide from menu bar dropdown", locale: locale))
        }
        .padding(14)
        .background(cardBackground)
    }

    private var tipsLegendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            tipRow(icon: "bell.fill", color: .orange, text: L10n.string("Tap the notification icon on any device to set low battery alerts.", locale: locale))
            HStack(spacing: 10) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.cyan.opacity(0.14)))
                HStack(spacing: 4) {
                    Text(L10n.string("Tap the pin icon to show a device's battery right in the menu bar. Arrange the order in", locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(L10n.string("Menu Bar settings.", locale: locale)) {
                        appState.selectedTab = .menuBar
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.cyan)
                }
            }
            tipRow(icon: "eye.fill", color: .blue, text: L10n.string("Tap the eye icon to hide a device from the dropdown.", locale: locale))
            tipRow(icon: "arrow.up.arrow.down", color: .secondary, text: L10n.string("Devices are ranked by battery level, lowest first, so the one that needs charging is always at the top.", locale: locale))
            tipRow(icon: "checkmark.seal.fill", color: .green, text: L10n.string("Most devices provide exact battery levels. Approximate values are prefixed with a tilde (~).", locale: locale))
        }
        .padding(.top, 4)
    }

    private func tipRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.14)))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
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
