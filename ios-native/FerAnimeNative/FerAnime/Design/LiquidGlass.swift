import SwiftUI

struct LiquidGlass<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var glow: Color = Theme.cyan.opacity(0.20)
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.10), glow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: glow, radius: 24, x: 0, y: 16)
            .shadow(color: Color.black.opacity(0.35), radius: 30, x: 0, y: 20)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.07 : 0)
            .animation(.spring(response: 0.30, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct LiquidButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            LiquidGlass(cornerRadius: 24, glow: Theme.accent.opacity(0.35)) {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.headline)
                    Text(title)
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 15)
            }
        }
        .buttonStyle(PressScaleStyle())
    }
}

struct PosterImage: View {
    var url: URL?
    var cornerRadius: CGFloat = 24

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    Theme.aurora.opacity(0.35)
                    Image(systemName: "play.rectangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

