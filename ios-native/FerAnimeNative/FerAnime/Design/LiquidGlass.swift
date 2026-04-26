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
    var cornerRadius: CGFloat = 22
    var glow: Color = Theme.appleBlue.opacity(0.12)
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.14), .clear, .white.opacity(0.035)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), Color.white.opacity(0.06), glow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: glow, radius: 18, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 12)
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

struct GlassAppear: ViewModifier {
    let delay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .blur(radius: visible ? 0 : 10)
            .offset(y: visible ? 0 : 16)
            .scaleEffect(visible ? 1 : 0.985)
            .onAppear {
                withAnimation(.spring(response: 0.56, dampingFraction: 0.86).delay(delay)) {
                    visible = true
                }
            }
    }
}

extension View {
    func glassAppear(delay: Double = 0) -> some View {
        modifier(GlassAppear(delay: delay))
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
            LiquidGlass(cornerRadius: 18, glow: Theme.appleBlue.opacity(0.12)) {
                Image(systemName: "sparkles.tv.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.aurora)
                    .frame(width: 42, height: 42)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
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
                    Theme.appleBlue.opacity(shifted ? 0.18 : 0.10),
                    Theme.violet.opacity(shifted ? 0.10 : 0.16),
                    Theme.cyan.opacity(shifted ? 0.08 : 0.14),
                    Theme.background,
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
