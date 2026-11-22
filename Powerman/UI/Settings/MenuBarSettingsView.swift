import SwiftUI

struct MenuBarSettingsView: View {
    @Bindable var appState: AppState

    private var settings: AppSettings { appState.settings }
    private var locale: Locale { appState.effectiveLocale }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                menuBarIconSection
                deviceBatteriesSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.72, blue: 0.58))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "menubar.rectangle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                Text(L10n.string("Menu Bar", locale: locale))
                    .font(.title2.bold())
            }

            Text(L10n.string("Customize how Powerman appears in your menu bar", locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var menuBarIconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.string("Menu Bar Icon", locale: locale), systemImage: "menubar.dock.rectangle")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(MenuBarIconStyle.allCases.enumerated()), id: \.element.id) { index, style in
                    styleOptionRow(style)
                    if index < MenuBarIconStyle.allCases.count - 1 {
                        Divider().padding(.horizontal, 14)
                    }
                }

                Divider().padding(.horizontal, 14)
                pickerRow(
                    icon: "list.bullet.rectangle",
                    iconColor: .purple,
                    title: L10n.string("Display", locale: locale),
                    subtitle: L10n.string("Choose what to display in the menu bar icon", locale: locale)
                ) {
                    Picker("", selection: Binding(
                        get: { settings.menuBarDisplayMode },
                        set: { settings.menuBarDisplayMode = $0 }
                    )) {
                        ForEach(MenuBarDisplayMode.allCases) { mode in
                            Text(mode.title(in: locale)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                Divider().padding(.horizontal, 14)
                pickerRow(
                    icon: "circle.lefthalf.filled",
                    iconColor: .orange,
                    title: L10n.string("Color", locale: locale),
                    subtitle: L10n.string("Match your menu bar style", locale: locale)
                ) {
                    Picker("", selection: Binding(
                        get: { settings.menuBarColorMode },
                        set: { settings.menuBarColorMode = $0 }
                    )) {
                        ForEach(MenuBarColorMode.allCases) { mode in
                            Text(mode.title(in: locale)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                Divider().padding(.horizontal, 14)
                pickerRow(
                    icon: "textformat.size",
                    iconColor: .blue,
                    title: L10n.string("Size", locale: locale),
                    subtitle: L10n.string("Make the icon and its text larger and easier to read", locale: locale)
                ) {
                    Picker("", selection: Binding(
                        get: { settings.menuBarSize },
                        set: { settings.menuBarSize = $0 }
                    )) {
                        ForEach(MenuBarSize.allCases) { size in
                            Text(size.title(in: locale)).tag(size)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                Divider().padding(.horizontal, 14)
                HStack(spacing: 12) {
                    settingBadgeIcon("paintpalette.fill", color: .green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("Status colors", locale: locale))
                            .font(.system(size: 13, weight: .semibold))
                        Text(
                            settings.menuBarColorMode == .monochrome
                            ? L10n.string("Disabled while Color is set to Monochrome.", locale: locale)
                            : L10n.string("Green when charging, orange for low battery. Off keeps the icon neutral and only turns red when critical.", locale: locale)
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { settings.statusColorsEnabled },
                        set: { settings.statusColorsEnabled = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(settings.menuBarColorMode == .monochrome)
                }
                .opacity(settings.menuBarColorMode == .monochrome ? 0.6 : 1.0)
                .padding(14)

                Divider().padding(.horizontal, 14)
                previewSection
            }
            .background(settingsCardBackground)
        }
    }

    private func styleOptionRow(_ style: MenuBarIconStyle) -> some View {
        let isSelected = settings.menuBarIconStyle == style
        return Button {
            settings.menuBarIconStyle = style
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(style.title(in: locale))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(style.subtitle(in: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.green : Color.secondary.opacity(0.4))
            }
            .contentShape(Rectangle())
            .padding(14)
        }
        .buttonStyle(.plain)
    }

    private func pickerRow<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            settingBadgeIcon(icon, color: iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
        .padding(14)
    }

    private var previewSection: some View {
        let previewIsLightBar = (settings.menuBarColorMode == .black)
        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("Preview", locale: locale))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.04, green: 0.14, blue: 0.10),
                                Color(red: 0.02, green: 0.07, blue: 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 150)

                VStack {
                    HStack {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 11))
                            .foregroundStyle(previewIsLightBar ? Color.black.opacity(0.85) : Color.white.opacity(0.9))
                        Spacer()
                        MenuBarIconView(
                            battery: appState.batteryInfo,
                            pinnedDevices: appState.pinnedMenuBarDevices,
                            style: settings.menuBarIconStyle,
                            displayMode: settings.menuBarDisplayMode,
                            colorMode: settings.menuBarColorMode,
                            size: settings.menuBarSize,
                            statusColorsEnabled: settings.statusColorsEnabled,
                            isDarkMenuBar: !previewIsLightBar,
                            locale: locale
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(previewIsLightBar ? Color.black.opacity(0.08) : Color.white.opacity(0.12))
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(previewIsLightBar ? Color.white.opacity(0.85) : Color.black.opacity(0.35))

                    Spacer()

                    VStack(alignment: .leading, spacing: 6) {
                        Label(L10n.string("Control Powerman directly from the menu bar", locale: locale), systemImage: "1.circle")
                        Label(L10n.string("You can hide macOS default battery icon in System Settings", locale: locale), systemImage: "2.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(14)
    }

    private var deviceBatteriesSection: some View {
        let pinned = settings.orderedPinnedDevices(from: appState.bluetoothDevices)
        let availableToPin = appState.bluetoothDevices.filter { !settings.preference(for: $0.id).isPinnedToMenuBar }

        return VStack(alignment: .leading, spacing: 10) {
            Label(L10n.string("Device Batteries", locale: locale), systemImage: "keyboard")
                .font(.headline)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    settingBadgeIcon("computermouse.fill", color: .cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("Devices in the menu bar", locale: locale))
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.string("Show battery percentages for your keyboard, mouse, or AirPods right in the menu bar.", locale: locale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Menu(L10n.string("Add Device", locale: locale)) {
                        if availableToPin.isEmpty {
                            Text(L10n.string("No unpinned Bluetooth devices", locale: locale))
                        } else {
                            ForEach(availableToPin) { device in
                                Button {
                                    settings.togglePinDevice(device.id)
                                } label: {
                                    Label(
                                        "\(device.name) (\(device.formattedPercentage))",
                                        systemImage: device.category.symbolName
                                    )
                                }
                            }
                        }
                    }
                    .frame(width: 125)
                }
                .padding(14)

                if !pinned.isEmpty {
                    ForEach(Array(pinned.enumerated()), id: \.element.id) { index, device in
                        Divider().padding(.horizontal, 14)
                        HStack(spacing: 10) {
                            Image(systemName: device.category.symbolName)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(device.name)
                                .font(.system(size: 13, weight: .medium))
                            Text(device.isConnected ? device.formattedPercentage : L10n.string("Offline", locale: locale))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()

                            Button {
                                settings.movePinnedDevice(id: device.id, direction: -1, allDevices: appState.bluetoothDevices)
                            } label: {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)

                            Button {
                                settings.movePinnedDevice(id: device.id, direction: 1, allDevices: appState.bluetoothDevices)
                            } label: {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == pinned.count - 1)

                            Button {
                                settings.togglePinDevice(device.id)
                            } label: {
                                Image(systemName: "pin.slash.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help(L10n.string("Unpin from menu bar", locale: locale))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
            }
            .background(settingsCardBackground)
        }
    }

    private func settingBadgeIcon(_ systemName: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color.opacity(0.15))
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
    }

    private var settingsCardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}
