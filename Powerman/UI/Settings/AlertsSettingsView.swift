import SwiftUI

struct AlertsSettingsView: View {
    @Bindable var appState: AppState
    @State private var expandedRuleID: UUID?

    private var settings: AppSettings { appState.settings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection
                generalSection
                lowBatterySection
                chargedSection
                powerSourceSection
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
                        .fill(.green)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    Text("Alerts")
                        .font(.title2.bold())
                }

                Text("Configure battery notifications and visual effects")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Reset Defaults") {
                appState.stopTestAlert()
                settings.resetAlertDefaults()
                expandedRuleID = nil
            }
            .font(.caption.weight(.medium))
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("General", systemImage: "gearshape")
                .font(.headline)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.blue.opacity(0.14))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Notifications")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Show battery alerts and notifications")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { settings.notificationsEnabled = $0 }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private var lowBatterySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Low Battery Alerts", systemImage: "battery.25")
                .font(.headline)
                .foregroundStyle(.primary)

            Label("Notify when battery goes below percentage", systemImage: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(settings.lowBatteryRules()) { rule in
                    if let binding = bindingForRule(id: rule.id) {
                        AlertRuleCard(
                            rule: binding,
                            isExpanded: expandedRuleID == rule.id,
                            isTesting: appState.activeTestRuleID == rule.id,
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedRuleID = (expandedRuleID == rule.id) ? nil : rule.id
                                }
                            },
                            onDelete: {
                                if appState.activeTestRuleID == rule.id {
                                    appState.stopTestAlert()
                                }
                                settings.removeAlertRule(id: rule.id)
                            },
                            onTest: {
                                appState.testAlert(rule: binding.wrappedValue)
                            },
                            onPreviewSound: { sound in
                                appState.previewSound(sound)
                            }
                        )
                    }
                }
            }

            Button {
                let added = settings.addAlertRule(kind: .lowBattery)
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedRuleID = added.id
                }
            } label: {
                Label("Add Low Battery Alert", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
        }
        .opacity(settings.notificationsEnabled ? 1.0 : 0.55)
    }

    private var chargedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Charged Alerts", systemImage: "battery.100percent.bolt")
                .font(.headline)

            Label("Notify when battery reaches percentage", systemImage: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(settings.chargedRules()) { rule in
                    if let binding = bindingForRule(id: rule.id) {
                        AlertRuleCard(
                            rule: binding,
                            isExpanded: expandedRuleID == rule.id,
                            isTesting: appState.activeTestRuleID == rule.id,
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedRuleID = (expandedRuleID == rule.id) ? nil : rule.id
                                }
                            },
                            onDelete: {
                                if appState.activeTestRuleID == rule.id {
                                    appState.stopTestAlert()
                                }
                                settings.removeAlertRule(id: rule.id)
                            },
                            onTest: {
                                appState.testAlert(rule: binding.wrappedValue)
                            },
                            onPreviewSound: { sound in
                                appState.previewSound(sound)
                            }
                        )
                    }
                }
            }

            Button {
                let added = settings.addAlertRule(kind: .charged)
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedRuleID = added.id
                }
            } label: {
                Label("Add Charged Alert", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
        }
        .opacity(settings.notificationsEnabled ? 1.0 : 0.55)
    }

    private var powerSourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Power Source Alerts", systemImage: "powerplug.fill")
                .font(.headline)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        badgeIcon("bolt.fill", color: .yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Plugged In")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Notify when power adapter is connected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings.powerSourceAlerts.pluggedInEnabled },
                            set: { settings.powerSourceAlerts.pluggedInEnabled = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }

                    if settings.powerSourceAlerts.pluggedInEnabled {
                        HStack(spacing: 8) {
                            Text("Sound")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            AlertSoundPicker(
                                selection: Binding(
                                    get: { settings.powerSourceAlerts.pluggedInSound },
                                    set: { settings.powerSourceAlerts.pluggedInSound = $0 }
                                ),
                                onPreview: { appState.previewSound($0) }
                            )
                            Spacer()
                        }
                        .padding(.leading, 40)
                    }
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        badgeIcon("bolt.slash.fill", color: .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unplugged")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Notify when power adapter is disconnected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings.powerSourceAlerts.unpluggedEnabled },
                            set: { settings.powerSourceAlerts.unpluggedEnabled = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }

                    if settings.powerSourceAlerts.unpluggedEnabled {
                        HStack(spacing: 8) {
                            Text("Sound")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            AlertSoundPicker(
                                selection: Binding(
                                    get: { settings.powerSourceAlerts.unpluggedSound },
                                    set: { settings.powerSourceAlerts.unpluggedSound = $0 }
                                ),
                                onPreview: { appState.previewSound($0) }
                            )
                            Spacer()
                        }
                        .padding(.leading, 40)
                    }
                }
                .padding(14)
            }
            .background(cardBackground)
        }
        .opacity(settings.notificationsEnabled ? 1.0 : 0.55)
    }

    private func bindingForRule(id: UUID) -> Binding<AlertRule>? {
        guard let index = settings.alertRules.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: { settings.alertRules[index] },
            set: { updated in
                if let currentIndex = settings.alertRules.firstIndex(where: { $0.id == id }) {
                    settings.alertRules[currentIndex] = updated
                }
            }
        )
    }

    private func badgeIcon(_ systemName: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color.opacity(0.15))
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
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

private struct AlertSoundPicker: View {
    @Binding var selection: AlertSoundOption
    let onPreview: (AlertSoundOption) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Picker("", selection: $selection) {
                Text(AlertSoundOption.none.title).tag(AlertSoundOption.none)

                Section("Powerman Alerts") {
                    ForEach(AlertSoundOption.customAlertSounds) { option in
                        Text(option.title).tag(option)
                    }
                }

                Section("macOS System Sounds") {
                    ForEach(AlertSoundOption.systemSounds) { option in
                        Text(option.title).tag(option)
                    }
                }
            }
            .labelsHidden()
            .frame(width: 205)

            Button {
                onPreview(selection)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selection == .none ? Color.secondary.opacity(0.4) : Color.accentColor)
                    .frame(width: 26, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .disabled(selection == .none)
            .help("Preview sound")
        }
    }
}

private struct AlertRuleCard: View {
    @Binding var rule: AlertRule
    let isExpanded: Bool
    let isTesting: Bool
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onTest: () -> Void
    let onPreviewSound: (AlertSoundOption) -> Void

    private var thresholdRange: ClosedRange<Double> {
        rule.kind == .lowBattery ? 1...95 : 50...100
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: rule.kind == .charged ? "battery.100percent.bolt" : "battery.25")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(rule.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(rule.threshold)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(rule.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(rule.color.opacity(0.14))
                        )

                    Text(rule.summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.red.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            if isExpanded {
                Divider().padding(.horizontal, 14)
                expandedEditor
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var expandedEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Battery Percentage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(rule.threshold)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                Slider(
                    value: Binding(
                        get: { Double(rule.threshold) },
                        set: { rule.threshold = Int($0.rounded()) }
                    ),
                    in: thresholdRange,
                    step: 1
                )
                .tint(rule.color)
            }

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Color")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(AlertColorPreset.allCases) { preset in
                            Button {
                                rule.colorHex = preset.rawValue
                            } label: {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        if rule.colorHex.caseInsensitiveCompare(preset.rawValue) == .orderedSame {
                                            Circle().stroke(.white, lineWidth: 2).padding(2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }

                        ColorPicker("", selection: Binding(
                            get: { rule.color },
                            set: { rule.colorHex = $0.hexString }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Position")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        positionButton(.topOfScreen, icon: "dock.rectangle")
                        positionButton(.centerOfScreen, icon: "macwindow")
                    }
                    .opacity(rule.showPopup ? 1.0 : 0.45)
                    .disabled(!rule.showPopup)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sound")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    AlertSoundPicker(selection: $rule.sound, onPreview: onPreviewSound)
                }
            }

            HStack(spacing: 24) {
                toggleColumn(title: "Floating Popup", isOn: $rule.showPopup)
                toggleColumn(title: "Border Glow", isOn: $rule.borderGlow)
                toggleColumn(title: "Persistent", isOn: $rule.persistent)
                Spacer()
            }

            previewBox
        }
        .padding(14)
    }

    private func toggleColumn(title: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private func positionButton(_ pos: AlertPosition, icon: String) -> some View {
        let selected = rule.position == pos
        return Button {
            rule.position = pos
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? .white : .primary)
                .frame(width: 30, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? Color.indigo : Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .help(pos.title)
    }

    private var previewBox: some View {
        let previewPresentation = ActiveAlertPresentation.from(
            rule: rule,
            battery: BatteryInfo(
                percentage: rule.threshold,
                isCharging: rule.kind == .charged,
                isPluggedIn: rule.kind == .charged,
                isFullyCharged: rule.threshold >= 100,
                timeRemainingMinutes: rule.kind == .lowBattery ? max(3, rule.threshold / 2) : nil,
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
                hasBattery: true,
                lastUpdated: Date()
            )
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Alert Preview", systemImage: "eye")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: onTest) {
                    Label(isTesting ? "Stop" : "Test", systemImage: isTesting ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(isTesting ? Color.gray : rule.color)
                        )
                }
                .buttonStyle(.plain)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.08, green: 0.09, blue: 0.13), Color(red: 0.05, green: 0.05, blue: 0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if rule.borderGlow {
                    ScreenBorderGlowView(
                        color: rule.color,
                        persistent: rule.persistent,
                        edgeThickness: 12,
                        cornerRadius: 10
                    )
                }

                VStack {
                    if rule.position == .centerOfScreen {
                        Spacer()
                    }
                    if rule.showPopup {
                        FloatingAlertBubbleView(alert: previewPresentation, compact: true, onDismiss: {})
                            .padding(.top, rule.position == .topOfScreen ? 12 : 0)
                    } else if !rule.borderGlow {
                        Text("Sound-only alert")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
