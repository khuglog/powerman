import SwiftUI

struct FloatingAlertBubbleView: View {
    let alert: ActiveAlertPresentation
    var bubbleSize: AlertBubbleSize = .default
    var compact: Bool = false
    var onDismiss: () -> Void

    private var accentColor: Color { alert.color }
    private var sizeScale: CGFloat { compact ? 1.0 : bubbleSize.scale }

    var body: some View {
        HStack(spacing: (compact ? 8 : 14) * sizeScale) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: (compact ? 24 : 38) * sizeScale, height: (compact ? 24 : 38) * sizeScale)

                Image(systemName: alert.isChargingIcon ? "battery.100percent.bolt" : "battery.25")
                    .font(.system(size: (compact ? 11 : 16) * sizeScale, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                Text(alert.title)
                    .font(.system(size: (compact ? 11 : 15) * sizeScale, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(alert.subtitle)
                    .font(.system(size: (compact ? 9 : 12) * sizeScale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer(minLength: (compact ? 6 : 14) * sizeScale)

            if !compact {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11 * sizeScale, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 26 * sizeScale, height: 26 * sizeScale)
                        .background(Circle().fill(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("Dismiss alert")
            }
        }
        .padding(.leading, (compact ? 8 : 12) * sizeScale)
        .padding(.trailing, (compact ? 10 : 12) * sizeScale)
        .padding(.vertical, (compact ? 6 : 10) * sizeScale)
        .frame(minWidth: (compact ? 170 : 300) * sizeScale, maxWidth: (compact ? 220 : 380) * sizeScale)
        .background {
            ZStack {
                Capsule(style: .continuous)
                    .fill(Color(red: 0.14, green: 0.15, blue: 0.17).opacity(0.94))

                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [accentColor.opacity(0.9), .white.opacity(0.22)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: compact ? 1.5 : 2
                    )
            }
        }
        .shadow(color: .black.opacity(0.42), radius: compact ? 8 : 18, y: compact ? 4 : 8)
    }
}
