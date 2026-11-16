import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var appState: AppState
    @State private var showGlowPreview = false

    private var settings: AppSettings { appState.settings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                languageSection
                appearanceSection
                systemIntegrationSection
                systemNotificationsSection
                lowPowerModeSection
                notificationAppearanceSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            appState.syncSystemIntegrationState()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 0.38, green: 0.78, blue: 0.22))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                Text("General")
                    .font(.title2.bold())
            }

            Text("Configure language, appearance, startup behavior, and alert styling.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var languageSection: some View {
        HStack(spacing: 12) {
            badgeIcon("globe", color: .blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("App Language")
                    .font(.system(size: 13, weight: .semibold))
                Text("Choose the language Powerman uses for date, time, and numbers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { settings.appLanguage },
                set: { settings.appLanguage = $0 }
            )) {
                ForEach(AppLanguageOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 155)
        }
        .padding(14)
        .background(cardBackground)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Appearance", systemImage: "circle.lefthalf.filled")
                .font(.headline)

            HStack(spacing: 12) {
                badgeIcon("circle.righthalf.filled", color: .indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Appearance")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Auto follows your Mac's system appearance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: Binding(
                    get: { settings.appAppearance },
                    set: { appState.applyAppAppearance($0) }
                )) {
                    ForEach(AppAppearanceOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private var systemIntegrationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("System Integration", systemImage: "power")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    badgeIcon("power", color: .green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Start Powerman automatically when you log in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.isLaunchAtLoginEnabled },
                        set: { appState.setLaunchAtLogin($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                if appState.launchAtLoginRequiresApproval {
                    Text("Approval required in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.leading, 40)
                } else if let err = appState.launchAtLoginError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.leading, 40)
                }
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private var systemNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("System Notifications", systemImage: "app.badge")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    badgeIcon("bell.slash.fill", color: .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dismiss macOS Battery Notifications")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Automatically closes system battery notification on the top right so you don't have to click it away.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { settings.dismissSystemBatteryNotifications },
                        set: { appState.setDismissSystemNotifications($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                Divider().padding(.leading, 40)

                HStack(spacing: 8) {
                    Image(systemName: appState.isAccessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(appState.isAccessibilityGranted ? .green : .orange)
                        .font(.caption)

                    Text(appState.isAccessibilityGranted ? "Accessibility permission granted" : "Accessibility permission required")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !appState.isAccessibilityGranted {
                        Button("Grant Access") {
                            appState.requestAccessibilityPermission()
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                .padding(.leading, 40)
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private var lowPowerModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Low Power Mode", systemImage: "leaf.fill")
                .font(.headline)

            HStack(spacing: 12) {
                badgeIcon("sun.max.fill", color: .yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Restore Brightness")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Brings back your previous brightness when you turn Low Power Mode off from Powerman's menu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { settings.restoreBrightnessOnLowPowerOff },
                    set: { settings.restoreBrightnessOnLowPowerOff = $0 }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private var notificationAppearanceSection: some View {
        let previewAlert = ActiveAlertPresentation(
            id: UUID(),
            ruleID: nil,
            kind: .lowBattery,
            title: "15% Remaining",
            subtitle: "9min until empty",
            percentage: 15,
            colorHex: AlertColorPreset.orange.rawValue,
            showPopup: true,
            position: .centerOfScreen,
            sound: .none,
            borderGlow: showGlowPreview,
            persistent: false,
            isChargingIcon: false
        )

        return VStack(alignment: .leading, spacing: 10) {
            Label("Notification Appearance", systemImage: "sparkles")
                .font(.headline)

            VStack(spacing: 0) {
                HStack {
                    Text("Alert Bubble Size")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settings.alertBubbleSize },
                        set: { settings.alertBubbleSize = $0 }
                    )) {
                        ForEach(AlertBubbleSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                HStack {
                    Text("Screen Edge Glow")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settings.screenEdgeGlowIntensity },
                        set: { settings.screenEdgeGlowIntensity = $0 }
                    )) {
                        ForEach(ScreenEdgeGlowIntensity.allCases) { intensity in
                            Text(intensity.title).tag(intensity)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Preview")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("Show Glow", isOn: $showGlowPreview)
                            .font(.caption)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.08))

                        if showGlowPreview {
                            ScreenBorderGlowView(
                                color: .orange,
                                persistent: false,
                                edgeThickness: settings.screenEdgeGlowIntensity.edgeThickness * 0.45,
                                opacityMultiplier: settings.screenEdgeGlowIntensity.opacityMultiplier,
                                cornerRadius: 10
                            )
                        }

                        FloatingAlertBubbleView(
                            alert: previewAlert,
                            bubbleSize: settings.alertBubbleSize,
                            compact: false,
                            onDismiss: {}
                        )
                        .scaleEffect(0.82)
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(14)
            }
            .background(cardBackground)
        }
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
