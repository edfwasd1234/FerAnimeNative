import SwiftUI
import UIKit

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

struct LiquidGlass<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var glow: Color = Theme.cyan.opacity(0.20)
    @ViewBuilder var content: Content
    @State private var sheenOffset: CGFloat = -0.9

    var body: some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.28), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: max(proxy.size.width * 0.28, 72), height: proxy.size.height * 1.8)
                        .rotationEffect(.degrees(24))
                        .offset(x: proxy.size.width * sheenOffset, y: -proxy.size.height * 0.35)
                        .blendMode(.screen)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            }
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
            .onAppear {
                withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: false)) {
                    sheenOffset = 1.25
                }
            }
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.68), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { Haptics.impact() }
            }
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

struct FrostedHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subtitle.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Theme.cyan)
                    .tracking(1.4)
                Text(title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            LiquidGlass(cornerRadius: 19, glow: Theme.accent.opacity(0.22)) {
                Image(systemName: "sparkles.tv.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.aurora)
                    .frame(width: 46, height: 46)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }
}

struct PremiumBackdrop: View {
    @State private var shifted = false

    var body: some View {
        ZStack {
            Theme.background
            LinearGradient(
                colors: [
                    Theme.background,
                    Theme.violet.opacity(shifted ? 0.24 : 0.12),
                    Theme.background,
                    Theme.cyan.opacity(shifted ? 0.10 : 0.20),
                    Theme.background
                ],
                startPoint: shifted ? .topTrailing : .topLeading,
                endPoint: shifted ? .bottomLeading : .bottomTrailing
            )
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: shifted)
            .onAppear { shifted = true }

            LinearGradient(
                colors: [.white.opacity(0.045), .clear, .black.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
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
