import SwiftUI

struct MenuBarSettingsView: View {
    @Bindable var appState: AppState

    private var settings: AppSettings { appState.settings }

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

                Text("Menu Bar")
                    .font(.title2.bold())
            }

            Text("Customize how Powerman appears in your menu bar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var menuBarIconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Menu Bar Icon", systemImage: "menubar.dock.rectangle")
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
                    title: "Display",
                    subtitle: "Choose what to display in the menu bar icon"
                ) {
                    Picker("", selection: Binding(
                        get: { settings.menuBarDisplayMode },
                        set: { settings.menuBarDisplayMode = $0 }
                    )) {
                        ForEach(MenuBarDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                Divider().padding(.horizontal, 14)
                pickerRow(
                    icon: "circle.lefthalf.filled",
                    iconColor: .orange,
                    title: "Color",
                    subtitle: "Match your menu bar style"
                ) {
                    Picker("", selection: Binding(
                        get: { settings.menuBarColorMode },
                        set: { settings.menuBarColorMode = $0 }
                    )) {
                        ForEach(MenuBarColorMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                Divider().padding(.horizontal, 14)
                pickerRow(
                    icon: "textformat.size",
                    iconColor: .blue,
                    title: "Size",
                    subtitle: "Make the icon and its text larger and easier to read"
                ) {
                    Picker("", selection: Binding(
                        get: { settings.menuBarSize },
                        set: { settings.menuBarSize = $0 }
                    )) {
                        ForEach(MenuBarSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                Divider().padding(.horizontal, 14)
                HStack(spacing: 12) {
                    settingBadgeIcon("paintpalette.fill", color: .green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Status colors")
                            .font(.system(size: 13, weight: .semibold))
                        Text(
                            settings.menuBarColorMode == .monochrome
                            ? "Disabled while Color is set to Monochrome."
                            : "Green when charging, orange for low battery. Off keeps the icon neutral and only turns red when critical."
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
                    Text(style.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(style.subtitle)
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
            Text("Preview")
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
                            isStartingCharge: appState.isPluggedChargeTransitionActive && !appState.isPausedAtChargeLimit
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
                        Label("Control Powerman directly from the menu bar", systemImage: "1.circle")
                        Label("You can hide macOS default battery icon in System Settings", systemImage: "2.circle")
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
            Label("Device Batteries", systemImage: "keyboard")
                .font(.headline)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    settingBadgeIcon("computermouse.fill", color: .cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Devices in the menu bar")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Show battery percentages for your keyboard, mouse, or AirPods right in the menu bar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Menu("Add Device") {
                        if availableToPin.isEmpty {
                            Text("No unpinned Bluetooth devices")
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
                            Text(device.isConnected ? device.formattedPercentage : "Offline")
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
                            .help("Unpin from menu bar")
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
