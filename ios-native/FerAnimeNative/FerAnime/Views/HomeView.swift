import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var recommended: [Anime] = []
    @State private var trending: [Anime] = []
    @State private var new: [Anime] = []
    @State private var action: [Anime] = []
    @State private var loading = true
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                CinematicBackground()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        FrostedHeader(title: "Watch", subtitle: "Now streaming")
                        hero
                        AnimeRail(title: "Continue Watching", items: Array(recommended.prefix(6)), compact: true)
                        AnimeRail(title: "Trending", items: trending)
                        AnimeRail(title: "New Episodes", items: new)
                        AnimeRail(title: "Action", items: action)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 110)
                }
                .refreshable { await load() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Anime.self) { AnimeDetailView(anime: $0) }
            .task {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                    appeared = true
                }
                await load()
            }
        }
    }

    private var hero: some View {
        GeometryReader { proxy in
            let heroHeight = min(max(proxy.size.height * 0.58, 360), 480)

            Group {
                if let anime = recommended.first ?? trending.first {
                    NavigationLink(value: anime) {
                        ZStack(alignment: .bottomLeading) {
                            PosterImage(url: URL(string: anime.banner ?? anime.cover ?? ""), cornerRadius: 30)
                                .frame(height: heroHeight)
                                .overlay {
                                    LinearGradient(colors: [.clear, Theme.background.opacity(0.25), Theme.background.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                                }

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Label(String(format: "%.1f", anime.score ?? 8.7), systemImage: "star.fill")
                                    Text(anime.year.map(String.init) ?? "Now")
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.86))

                                Text(anime.title)
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .minimumScaleFactor(0.78)
                                    .foregroundStyle(.white)
                                    .lineLimit(3)

                                LiquidGlass(cornerRadius: 24, glow: Theme.accent.opacity(0.35)) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "play.fill")
                                        Text("Play")
                                    }
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                }
                                .frame(maxWidth: 170)
                            }
                            .padding(22)
                        }
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(PressScaleStyle())
                } else {
                    LiquidGlass {
                        ProgressView("Loading anime")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 340)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .frame(height: 470)
        .offset(y: appeared ? 0 : 24)
        .opacity(appeared ? 1 : 0)
    }

    private func load() async {
        loading = true
        async let recommendedLoad = catalog("recommended")
        async let trendingLoad = catalog("trending")
        async let newLoad = catalog("new")
        async let actionLoad = catalog("action")
        recommended = await recommendedLoad
        trending = await trendingLoad
        new = await newLoad
        action = await actionLoad
        loading = false
    }

    private func catalog(_ section: String) async -> [Anime] {
        for source in ["anizone", "animeheaven", "hianime"] {
            if let items = try? await appState.client.catalog(section: section, sourceId: source), !items.isEmpty {
                return items
            }
        }
        return []
    }
}

struct AnimeRail: View {
    let title: String
    let items: [Anime]
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("See All")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.cyan)
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { anime in
                        NavigationLink(value: anime) {
                            AnimePosterCard(anime: anime, width: compact ? 210 : 144, height: compact ? 124 : 214)
                        }
                        .buttonStyle(PressScaleStyle())
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                .opacity(phase.isIdentity ? 1 : 0.72)
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

struct AnimePosterCard: View {
    let anime: Anime
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PosterImage(url: URL(string: anime.cover ?? anime.banner ?? ""), cornerRadius: 24)
                .frame(width: width, height: height)
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, .black.opacity(0.76)], startPoint: .top, endPoint: .bottom)
                    Text(anime.subtitle ?? anime.sourceId ?? "")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(12)
                }

            Text(anime.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)
        }
    }
}

struct CinematicBackground: View {
    var body: some View {
        ZStack {
            PremiumBackdrop()
        }
    }
}
