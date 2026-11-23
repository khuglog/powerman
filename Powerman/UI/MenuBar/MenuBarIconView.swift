import SwiftUI

struct MenuBarIconView: View {
    let battery: BatteryInfo
    var pinnedDevices: [BluetoothDeviceBattery] = []
    let style: MenuBarIconStyle
    let displayMode: MenuBarDisplayMode
    let colorMode: MenuBarColorMode
    let size: MenuBarSize
    let statusColorsEnabled: Bool
    var isKeepAwakeActive: Bool = false
    var isDarkMenuBar: Bool = false
    var isTemplateMode: Bool = false
    var locale: Locale = Locale(identifier: "en")

    private var isChargingOrConnected: Bool {
        battery.isCharging || battery.isPluggedIn
    }

    private var scaleFactor: CGFloat {
        size == .large ? 1.18 : 1.0
    }

    /// Foreground color used for text, outlines, and neutral fills.
    private var baseForeground: Color {
        switch colorMode {
        case .monochrome:
            return isTemplateMode ? .black : (isDarkMenuBar ? .white : .black)
        case .white:
            return .white
        case .black:
            return .black
        case .auto:
            return isDarkMenuBar ? .white : .black
        }
    }

    private var isStatusColored: Bool {
        guard colorMode != .monochrome, !isTemplateMode else { return false }
        if statusColorsEnabled {
            return isChargingOrConnected || battery.isFullyCharged || battery.percentage <= 20
        }
        return battery.percentage <= 10
    }

    private var fillColor: Color {
        if colorMode == .monochrome || isTemplateMode {
            return baseForeground
        }

        if statusColorsEnabled {
            if isChargingOrConnected || battery.isFullyCharged {
                return .green
            } else if battery.percentage <= 10 {
                return .red
            } else if battery.percentage <= 20 {
                return .orange
            }
        } else if battery.percentage <= 10 {
            return .red
        }

        return baseForeground
    }

    private var keepAwakeIconColor: Color {
        if colorMode == .monochrome || isTemplateMode {
            return baseForeground
        }
        return statusColorsEnabled ? .orange : baseForeground
    }

    var body: some View {
        HStack(spacing: 6 * scaleFactor) {
            if !pinnedDevices.isEmpty {
                HStack(spacing: 6 * scaleFactor) {
                    ForEach(pinnedDevices) { device in
                        HStack(spacing: 2.5 * scaleFactor) {
                            Image(systemName: device.category.symbolName)
                                .font(.system(size: 10.5 * scaleFactor, weight: .semibold))
                                .foregroundStyle(baseForeground.opacity(0.9))
                            Text(device.formattedPercentage)
                                .font(.system(size: 11 * scaleFactor, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(baseForeground)
                        }
                    }
                }
            }

            if isKeepAwakeActive {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 11 * scaleFactor, weight: .semibold))
                    .foregroundStyle(keepAwakeIconColor)
            }

            HStack(spacing: 4 * scaleFactor) {
                if displayMode != .percentage {
                    iconGraphic
                }

                if displayMode == .iconAndPercentage || displayMode == .percentage {
                    if style != .minimal || displayMode == .percentage {
                        Text("\(battery.percentage)%")
                            .font(.system(size: 11.5 * scaleFactor, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(baseForeground)
                    }
                } else if displayMode == .timeRemaining {
                    Text(battery.formattedTimeRemaining(in: locale))
                        .font(.system(size: 11.5 * scaleFactor, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(baseForeground)
                }
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var iconGraphic: some View {
        switch style {
        case .batteryIndicator:
            richBatteryIndicator
        case .minimal:
            minimalPillIndicator(showDigitsInside: displayMode != .iconOnly)
        case .powermanLogo:
            Image(systemName: isChargingOrConnected ? "bolt.shield.fill" : "bolt.circle.fill")
                .font(.system(size: 13.5 * scaleFactor, weight: .semibold))
                .foregroundStyle(fillColor)
        }
    }

    private var richBatteryIndicator: some View {
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous)
                    .stroke(baseForeground.opacity(0.75), lineWidth: 1.2)
                    .frame(width: 24 * scaleFactor, height: 12.5 * scaleFactor)

                RoundedRectangle(cornerRadius: 2.2 * scaleFactor, style: .continuous)
                    .fill(fillColor)
                    .frame(
                        width: max(2, 20.5 * scaleFactor * CGFloat(battery.percentage) / 100.0),
                        height: 9 * scaleFactor
                    )
                    .padding(.leading, 1.8 * scaleFactor)

                if isChargingOrConnected {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7.5 * scaleFactor, weight: .bold))
                        .foregroundStyle(isStatusColored ? .white : (isDarkMenuBar ? .black : .white))
                        .shadow(color: .black.opacity(0.35), radius: 0.5)
                        .frame(width: 24 * scaleFactor, height: 12.5 * scaleFactor)
                }
            }

            RoundedRectangle(cornerRadius: 1)
                .fill(baseForeground.opacity(0.6))
                .frame(width: 1.8 * scaleFactor, height: 4.5 * scaleFactor)
        }
    }

    private func minimalPillIndicator(showDigitsInside: Bool) -> some View {
        let pillWidth = 25 * scaleFactor
        let pillHeight = 13.5 * scaleFactor

        return HStack(spacing: 1.5) {
            ZStack {
                if isStatusColored {
                    // Dark track ensures crisp white digit contrast over both filled and unfilled regions.
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous)
                            .fill(Color.black.opacity(isDarkMenuBar ? 0.45 : 0.62))
                            .frame(width: pillWidth, height: pillHeight)

                        RoundedRectangle(cornerRadius: 3 * scaleFactor, style: .continuous)
                            .fill(fillColor)
                            .frame(width: pillWidth * CGFloat(battery.percentage) / 100.0, height: pillHeight)
                    }
                    .frame(width: pillWidth, height: pillHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous)
                            .stroke(baseForeground.opacity(0.45), lineWidth: 0.9)
                    )

                    if showDigitsInside {
                        pillLabel
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 0.6, x: 0, y: 0.5)
                    }
                } else if isTemplateMode {
                    // Punch out digits using destinationOut for monochrome NSImage template alpha masks.
                    ZStack {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous)
                                .fill(baseForeground.opacity(0.32))
                                .frame(width: pillWidth, height: pillHeight)

                            RoundedRectangle(cornerRadius: 3 * scaleFactor, style: .continuous)
                                .fill(baseForeground)
                                .frame(width: pillWidth * CGFloat(battery.percentage) / 100.0, height: pillHeight)
                        }
                        .frame(width: pillWidth, height: pillHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous)
                                .stroke(baseForeground.opacity(0.65), lineWidth: 0.9)
                        )

                        if showDigitsInside {
                            pillLabel
                                .foregroundStyle(.black)
                                .blendMode(.destinationOut)
                        }
                    }
                    .compositingGroup()
                } else {
                    let inverseForeground: Color = (colorMode == .white || (colorMode != .black && isDarkMenuBar)) ? .black : .white

                    ZStack {
                        RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous)
                            .fill(baseForeground.opacity(0.22))
                            .frame(width: pillWidth, height: pillHeight)

                        if showDigitsInside {
                            pillLabel
                                .foregroundStyle(baseForeground)
                        }

                        ZStack {
                            RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous)
                                .fill(baseForeground)
                                .frame(width: pillWidth, height: pillHeight)

                            if showDigitsInside {
                                pillLabel
                                    .foregroundStyle(inverseForeground)
                            }
                        }
                        .frame(width: pillWidth, height: pillHeight)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: pillWidth * CGFloat(battery.percentage) / 100.0, height: pillHeight)
                        }
                    }
                    .frame(width: pillWidth, height: pillHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous)
                            .stroke(baseForeground.opacity(0.75), lineWidth: 0.9)
                    )
                }
            }

            RoundedRectangle(cornerRadius: 1)
                .fill(baseForeground.opacity(0.55))
                .frame(width: 1.5 * scaleFactor, height: 4.5 * scaleFactor)
        }
    }

    private var pillLabel: some View {
        HStack(spacing: 1) {
            if isChargingOrConnected {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 6.5 * scaleFactor, weight: .bold))
            }
            Text("\(battery.percentage)")
                .font(.system(size: 9 * scaleFactor, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
    }
}
