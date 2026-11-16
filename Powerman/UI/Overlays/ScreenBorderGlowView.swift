import SwiftUI

struct ScreenBorderGlowView: View {
    let color: Color
    let persistent: Bool
    var edgeThickness: CGFloat = 34
    var cornerRadius: CGFloat = 12

    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Top edge glow
                LinearGradient(
                    colors: [color.opacity(0.72), color.opacity(0.18), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: edgeThickness)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Bottom edge glow
                LinearGradient(
                    colors: [color.opacity(0.72), color.opacity(0.18), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: edgeThickness)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                // Left edge glow
                LinearGradient(
                    colors: [color.opacity(0.72), color.opacity(0.18), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: edgeThickness)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                // Right edge glow
                LinearGradient(
                    colors: [color.opacity(0.72), color.opacity(0.18), .clear],
                    startPoint: .trailing,
                    endPoint: .leading
                )
                .frame(width: edgeThickness)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                // Crisp outer perimeter highlight
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color.opacity(0.92), lineWidth: 3)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .opacity(persistent ? (pulse ? 1.0 : 0.48) : 0.92)
            .onAppear {
                guard persistent else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
