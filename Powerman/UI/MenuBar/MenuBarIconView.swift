import SwiftUI

struct MenuBarIconView: View {
    let battery: BatteryInfo
    let style: MenuBarIconStyle
    let displayMode: MenuBarDisplayMode
    let colorMode: MenuBarColorMode
    let size: MenuBarSize
    let statusColorsEnabled: Bool
    var forceDarkForeground: Bool = false

    private var scaleFactor: CGFloat {
        size == .large ? 1.18 : 1.0
    }

    private var fillColor: Color {
        if colorMode == .monochrome && !statusColorsEnabled {
            return forceDarkForeground ? .white : .primary
        }

        if statusColorsEnabled {
            if battery.isCharging || battery.isFullyCharged {
                return .green
            } else if battery.percentage <= 10 {
                return .red
            } else if battery.percentage <= 20 {
                return .orange
            }
        } else if battery.percentage <= 10 {
            return .red
        }

        return forceDarkForeground ? .white : .primary
    }

    private var textColor: Color {
        forceDarkForeground ? .white : .primary
    }

    var body: some View {
        HStack(spacing: 4 * scaleFactor) {
            if displayMode != .percentage {
                iconGraphic
            }

            if displayMode == .iconAndPercentage || displayMode == .percentage {
                if style != .minimal || displayMode == .percentage {
                    Text("\(battery.percentage)%")
                        .font(.system(size: 11.5 * scaleFactor, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                }
            } else if displayMode == .timeRemaining {
                Text(battery.formattedTimeRemaining)
                    .font(.system(size: 11.5 * scaleFactor, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(textColor)
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
            minimalPillIndicator
        case .powermanLogo:
            Image(systemName: battery.isCharging ? "bolt.shield.fill" : "bolt.circle.fill")
                .font(.system(size: 13.5 * scaleFactor, weight: .semibold))
                .foregroundStyle(fillColor)
        }
    }

    private var richBatteryIndicator: some View {
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous)
                    .stroke(textColor.opacity(0.7), lineWidth: 1.2)
                    .frame(width: 24 * scaleFactor, height: 12.5 * scaleFactor)

                RoundedRectangle(cornerRadius: 2.2 * scaleFactor, style: .continuous)
                    .fill(fillColor)
                    .frame(
                        width: max(2, 20.5 * scaleFactor * CGFloat(battery.percentage) / 100.0),
                        height: 9 * scaleFactor
                    )
                    .padding(.leading, 1.8 * scaleFactor)

                if battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7.5 * scaleFactor, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 0.5)
                        .frame(width: 24 * scaleFactor, height: 12.5 * scaleFactor)
                }
            }

            RoundedRectangle(cornerRadius: 1)
                .fill(textColor.opacity(0.55))
                .frame(width: 1.8 * scaleFactor, height: 4.5 * scaleFactor)
        }
    }

    private var minimalPillIndicator: some View {
        HStack(spacing: 1.5) {
            ZStack {
                RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous)
                    .fill(textColor.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous)
                            .stroke(textColor.opacity(0.55), lineWidth: 0.9)
                    )
                    .frame(width: 24 * scaleFactor, height: 13 * scaleFactor)

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3 * scaleFactor, style: .continuous)
                        .fill(fillColor)
                        .frame(width: geo.size.width * CGFloat(battery.percentage) / 100.0)
                }
                .frame(width: 24 * scaleFactor, height: 13 * scaleFactor)
                .clipShape(RoundedRectangle(cornerRadius: 3.5 * scaleFactor, style: .continuous))

                HStack(spacing: 1) {
                    if battery.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7 * scaleFactor, weight: .bold))
                    }
                    Text("\(battery.percentage)")
                        .font(.system(size: 9 * scaleFactor, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(textColor)
            }

            RoundedRectangle(cornerRadius: 1)
                .fill(textColor.opacity(0.5))
                .frame(width: 1.5 * scaleFactor, height: 4.5 * scaleFactor)
        }
    }
}
