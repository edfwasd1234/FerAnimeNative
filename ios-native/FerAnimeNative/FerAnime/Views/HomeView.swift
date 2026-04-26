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
                    VStack(alignment: .leading, spacing: 24) {
                        FrostedHeader(title: "Watch", subtitle: "Now streaming")
                            .glassAppear()
                        hero
                        AnimeRail(title: "Continue Watching", items: Array(recommended.prefix(6)), compact: true)
                            .glassAppear(delay: 0.08)
                        AnimeRail(title: "Trending", items: trending)
                            .glassAppear(delay: 0.12)
                        AnimeRail(title: "New Episodes", items: new)
                            .glassAppear(delay: 0.16)
                        AnimeRail(title: "Action", items: action)
                            .glassAppear(delay: 0.20)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 92)
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
            let heroHeight = min(max(proxy.size.height * 0.62, 300), 340)

            Group {
                if let anime = recommended.first ?? trending.first {
                    NavigationLink(value: anime) {
                        ZStack(alignment: .bottomLeading) {
                            PosterImage(url: URL(string: anime.banner ?? anime.cover ?? ""), cornerRadius: 28)
                                .frame(height: heroHeight)
                                .overlay {
                                    Rectangle()
                                        .fill(.black.opacity(0.24))
                                }

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Label(String(format: "%.1f", anime.score ?? 8.7), systemImage: "star.fill")
                                    Text(anime.year.map(String.init) ?? "Now")
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.86))

                                Text(anime.title)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .minimumScaleFactor(0.78)
                                    .foregroundStyle(.white)
                                    .lineLimit(3)

                                LiquidGlass(cornerRadius: 18, glow: Theme.appleBlue.opacity(0.18)) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "play.fill")
                                        Text("Play")
                                    }
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                }
                                .frame(maxWidth: 140)
                            }
                            .padding(18)
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
        .frame(height: 360)
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
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("See All")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.appleBlue)
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { anime in
                        NavigationLink(value: anime) {
                            AnimePosterCard(anime: anime, width: compact ? 198 : 132, height: compact ? 112 : 196)
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
            PosterImage(url: URL(string: anime.cover ?? anime.banner ?? ""), cornerRadius: 20)
                .frame(width: width, height: height)
                .overlay(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(.black.opacity(0.18))
                    Text(anime.subtitle ?? anime.sourceId ?? "")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(12)
                }

            Text(anime.title)
                .font(.footnote.weight(.semibold))
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
