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
                    .fill(.white.opacity(0.035))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
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
            LiquidGlass(cornerRadius: 20, glow: Theme.appleBlue.opacity(0.12)) {
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

struct SystemPlayLabel: View {
    var title = "Play"

    var body: some View {
        Label(title, systemImage: "play.fill")
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity)
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
                    .foregroundStyle(Theme.appleBlue)
                    .tracking(1.4)
                Text(title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            LiquidGlass(cornerRadius: 18, glow: Theme.appleBlue.opacity(0.12)) {
                Image(systemName: "sparkles.tv.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.appleBlue)
                    .frame(width: 42, height: 42)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }
}

struct PremiumBackdrop: View {
    var body: some View {
        ZStack {
            Theme.background
            Color.white.opacity(0.018)
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
                    Color.secondary.opacity(0.18)
                    Image(systemName: "play.rectangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
