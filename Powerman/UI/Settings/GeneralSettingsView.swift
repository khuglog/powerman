import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var appState: AppState
    @State private var showGlowPreview = false

    private var settings: AppSettings { appState.settings }
    private var locale: Locale { appState.effectiveLocale }

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
                aboutSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            appState.syncSystemIntegrationState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
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

                Text(L10n.string("General", locale: locale))
                    .font(.title2.bold())
            }

            Text(L10n.string("Configure language, appearance, startup behavior, and alert styling.", locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var languageSection: some View {
        HStack(spacing: 12) {
            badgeIcon("globe", color: .blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string("App Language", locale: locale))
                    .font(.system(size: 13, weight: .semibold))
                Text(L10n.string("Choose the language Powerman uses across the interface, dates, and numbers", locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { settings.appLanguage },
                set: { settings.appLanguage = $0 }
            )) {
                ForEach(AppLanguageOption.allCases) { option in
                    Text(option.title(in: locale)).tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 165)
        }
        .padding(14)
        .background(cardBackground)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.string("Appearance", locale: locale), systemImage: "circle.lefthalf.filled")
                .font(.headline)

            HStack(spacing: 12) {
                badgeIcon("circle.righthalf.filled", color: .indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("App Appearance", locale: locale))
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.string("Auto follows your Mac's system appearance", locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: Binding(
                    get: { settings.appAppearance },
                    set: { appState.applyAppAppearance($0) }
                )) {
                    ForEach(AppAppearanceOption.allCases) { option in
                        Text(option.title(in: locale)).tag(option)
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
            Label(L10n.string("System Integration", locale: locale), systemImage: "power")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    badgeIcon("power", color: .green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("Launch at Login", locale: locale))
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.string("Start Powerman automatically when you log in", locale: locale))
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
                    Text(L10n.string("Approval required in System Settings → General → Login Items.", locale: locale))
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
            Label(L10n.string("System Notifications", locale: locale), systemImage: "app.badge")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    badgeIcon("bell.slash.fill", color: .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("Dismiss macOS Battery Notifications", locale: locale))
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.string("Automatically closes system battery notification on the top right so you don't have to click it away.", locale: locale))
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

                    Text(L10n.string(appState.isAccessibilityGranted ? "Accessibility permission granted" : "Accessibility permission required", locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !appState.isAccessibilityGranted {
                        Button(L10n.string("Grant Access", locale: locale)) {
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
            Label(L10n.string("Low Power Mode", locale: locale), systemImage: "leaf.fill")
                .font(.headline)

            HStack(spacing: 12) {
                badgeIcon("sun.max.fill", color: .yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("Restore Brightness", locale: locale))
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.string("Brings back your previous brightness when you turn Low Power Mode off from Powerman's menu.", locale: locale))
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
            title: L10n.format("%d%% Remaining", locale: locale, 15),
            subtitle: L10n.format("%dmin until empty", locale: locale, 9),
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
            Label(L10n.string("Notification Appearance", locale: locale), systemImage: "sparkles")
                .font(.headline)

            VStack(spacing: 0) {
                HStack {
                    Text(L10n.string("Alert Bubble Size", locale: locale))
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settings.alertBubbleSize },
                        set: { settings.alertBubbleSize = $0 }
                    )) {
                        ForEach(AlertBubbleSize.allCases) { size in
                            Text(size.title(in: locale)).tag(size)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                HStack {
                    Text(L10n.string("Screen Edge Glow", locale: locale))
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settings.screenEdgeGlowIntensity },
                        set: { settings.screenEdgeGlowIntensity = $0 }
                    )) {
                        ForEach(ScreenEdgeGlowIntensity.allCases) { intensity in
                            Text(intensity.title(in: locale)).tag(intensity)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L10n.string("Preview", locale: locale))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle(L10n.string("Show Glow", locale: locale), isOn: $showGlowPreview)
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
                            locale: locale,
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

    private var aboutSection: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.2"

        return VStack(alignment: .leading, spacing: 10) {
            Label(L10n.string("About Powerman", locale: locale), systemImage: "info.circle.fill")
                .font(.headline)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    badgeIcon("bolt.batteryblock.fill", color: .teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Powerman")
                            .font(.system(size: 13.5, weight: .bold))
                        Text(L10n.format("macOS Battery Manager • Version %@", locale: locale, version))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let repoURL = URL(string: "https://github.com/khuglog/powerman") {
                        Link("GitHub", destination: repoURL)
                            .font(.caption.weight(.semibold))
                    }
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.string("Author", locale: locale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .leading)
                        Text("Hưng Nguyễn 719")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }

                    HStack {
                        Text(L10n.string("Email", locale: locale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .leading)
                        if let mailURL = URL(string: "mailto:hungnq719@gmail.com") {
                            Link("hungnq719@gmail.com", destination: mailURL)
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        Spacer()
                    }

                    HStack {
                        Text(L10n.string("Phone", locale: locale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .leading)
                        if let telURL = URL(string: "tel:+84793334555") {
                            Link("+84793334555", destination: telURL)
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        Spacer()
                    }
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
