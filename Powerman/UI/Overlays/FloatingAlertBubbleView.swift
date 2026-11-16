import SwiftUI

struct FloatingAlertBubbleView: View {
    let alert: ActiveAlertPresentation
    var compact: Bool = false
    var onDismiss: () -> Void

    private var accentColor: Color { alert.color }

    var body: some View {
        HStack(spacing: compact ? 8 : 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: compact ? 24 : 38, height: compact ? 24 : 38)

                Image(systemName: alert.isChargingIcon ? "battery.100percent.bolt" : "battery.25")
                    .font(.system(size: compact ? 11 : 16, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                Text(alert.title)
                    .font(.system(size: compact ? 11 : 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(alert.subtitle)
                    .font(.system(size: compact ? 9 : 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer(minLength: compact ? 6 : 14)

            if !compact {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("Dismiss alert")
            }
        }
        .padding(.leading, compact ? 8 : 12)
        .padding(.trailing, compact ? 10 : 12)
        .padding(.vertical, compact ? 6 : 10)
        .frame(minWidth: compact ? 170 : 300, maxWidth: compact ? 220 : 380)
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
