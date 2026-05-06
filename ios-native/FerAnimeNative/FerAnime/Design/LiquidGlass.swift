import SwiftUI
import UIKit

// MARK: - Haptics

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred()
    }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Core Glass Container
// On iOS 26+, TabView and NavigationStack automatically receive Liquid Glass treatment.
// Custom surfaces use .regularMaterial which iOS 26 also renders as Liquid Glass.

struct LiquidGlass<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var glow: Color = Theme.appleBlue.opacity(0.08)
    var material: Material = .regularMaterial
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.10), .white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: glow, radius: 22, x: 0, y: 6)
            .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Button Styles

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { Haptics.impact(.soft) }
            }
    }
}

// MARK: - Appear Animation

struct GlassAppear: ViewModifier {
    let delay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .blur(radius: visible ? 0 : 6)
            .offset(y: visible ? 0 : 12)
            .scaleEffect(visible ? 1 : 0.98)
            .onAppear {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.88).delay(delay)) {
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

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { geo in
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.10), location: 0.35),
                        .init(color: .white.opacity(0.16), location: 0.5),
                        .init(color: .white.opacity(0.10), location: 0.65),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: geo.size.width * 2.5)
                .offset(x: geo.size.width * (phase + 1))
            }
            .allowsHitTesting(false)
            .clipped()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Poster Image

struct PosterImage: View {
    var url: URL?
    var cornerRadius: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                case .failure:
                    placeholder(proxy.size)
                default:
                    placeholder(proxy.size)
                        .shimmer()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func placeholder(_ size: CGSize) -> some View {
        ZStack {
            Color.white.opacity(0.07)
            Image(systemName: "photo")
                .font(.system(size: min(size.width, size.height) * 0.22))
                .foregroundStyle(.white.opacity(0.28))
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Section Headers

/// Large page-level header with eyebrow subtitle.
struct FrostedHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(subtitle.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Theme.appleBlue)
                    .tracking(1.4)
                Text(title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            LiquidGlass(cornerRadius: 18, glow: Theme.appleBlue.opacity(0.10)) {
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

/// Compact rail/section header with optional "See All" link.
struct SectionHeader: View {
    let title: String
    var seeAllAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            if let action = seeAllAction {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text("See All")
                            .font(.footnote.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Theme.appleBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Backdrop

struct PremiumBackdrop: View {
    var body: some View {
        Theme.background.ignoresSafeArea()
    }
}

// MARK: - Play Labels & Buttons

struct SystemPlayLabel: View {
    var title = "Play"

    var body: some View {
        Label(title, systemImage: "play.fill")
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity)
    }
}

struct LiquidButton: View {
    var title: String
    var systemImage: String
    var color: Color = Theme.appleBlue
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.headline)
                Text(title)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(color.opacity(0.20), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(color.opacity(0.38), lineWidth: 0.8)
            }
        }
        .buttonStyle(PressScaleStyle())
    }
}

// MARK: - Chips & Badges

struct GlassChip: View {
    let text: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    var color: Color = Theme.appleBlue
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { chipContent }.buttonStyle(PressScaleStyle())
            } else {
                chipContent
            }
        }
    }

    private var chipContent: some View {
        HStack(spacing: 5) {
            if let icon = systemImage {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(isSelected ? .white : Theme.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            isSelected ? color.opacity(0.22) : Color.white.opacity(0.07),
            in: Capsule()
        )
        .overlay(
            Capsule().stroke(
                isSelected ? color.opacity(0.42) : Color.white.opacity(0.10),
                lineWidth: 0.75
            )
        )
    }
}

struct MetaBadge: View {
    let systemImage: String
    let text: String
    var color: Color = .white.opacity(0.76)

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
    }
}

// MARK: - Stat Card

struct LensMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.tertiary)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
        )
    }
}
