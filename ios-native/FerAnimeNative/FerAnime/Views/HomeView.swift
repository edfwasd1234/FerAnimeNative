import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var recommended: [Anime] = []
    @State private var trending: [Anime] = []
    @State private var new: [Anime] = []
    @State private var action: [Anime] = []
    @State private var loading = true
    @State private var appeared = false
    @State private var heroIndex = 0
    private let jikan = JikanClient()

    private var heroItems: [Anime] {
        let combined = recommended + trending
        var seen = Set<String>()
        return combined.filter { anime in
            if seen.contains(anime.id) { return false }
            seen.insert(anime.id)
            return true
        }
        .prefix(6)
        .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CinematicBackground()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        hero
                        AnimeRail(title: "Continue Watching", items: Array(recommended.prefix(6)), compact: true)
                        AnimeRail(title: "Trending", items: trending)
                        AnimeRail(title: "New Episodes", items: new)
                        AnimeRail(title: "Action", items: action)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 92)
                }
                .refreshable { await load(force: true) }
            }
            .navigationTitle("Watch")
            .navigationDestination(for: Anime.self) { AnimeDetailView(anime: $0) }
            .navigationDestination(for: AnimeSectionRoute.self) { route in
                AnimeSectionView(title: route.title, items: route.items)
            }
            .task {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                    appeared = true
                }
                applyCachedCatalogs()
                if recommended.isEmpty && trending.isEmpty && new.isEmpty && action.isEmpty {
                    await load(force: false)
                }
            }
            .task(id: heroItems.count) {
                await autoAdvanceHero()
            }
        }
    }

    private var hero: some View {
        Group {
            if heroItems.isEmpty {
                ProgressView("Loading anime")
                    .frame(maxWidth: .infinity, minHeight: 318)
                    .padding(.horizontal, 16)
            } else {
                TabView(selection: $heroIndex) {
                    ForEach(Array(heroItems.enumerated()), id: \.element.id) { index, anime in
                        NavigationLink(value: anime) {
                            ZStack(alignment: .bottomLeading) {
                                PosterImage(url: URL(string: anime.banner ?? anime.cover ?? ""), cornerRadius: 28)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 318)
                                    .overlay {
                                        Rectangle()
                                            .fill(.black.opacity(0.24))
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

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

                                    SystemPlayLabel()
                                        .frame(maxWidth: 140)
                                }
                                .padding(18)
                            }
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        .tag(index)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.impact(.medium) })
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 338)
                .clipped()
            }
        }
        .frame(height: 338)
        .offset(y: appeared ? 0 : 24)
        .opacity(appeared ? 1 : 0)
    }

    private func load(force: Bool) async {
        if !force, applyCachedCatalogs() {
            loading = false
            return
        }
        loading = true
        let catalogs = await jikan.homeCatalogs()
        if !catalogs.recommended.isEmpty { recommended = catalogs.recommended }
        if !catalogs.trending.isEmpty { trending = catalogs.trending }
        if !catalogs.new.isEmpty { new = catalogs.new }
        if !catalogs.action.isEmpty { action = catalogs.action }
        if !recommended.isEmpty || !trending.isEmpty || !new.isEmpty || !action.isEmpty {
            appState.cachedHomeCatalogs = HomeCatalogs(recommended: recommended, trending: trending, new: new, action: action)
        }
        loading = false
        heroIndex = min(heroIndex, max(heroItems.count - 1, 0))
    }

    @discardableResult
    private func applyCachedCatalogs() -> Bool {
        guard let catalogs = appState.cachedHomeCatalogs else { return false }
        if recommended.isEmpty { recommended = catalogs.recommended }
        if trending.isEmpty { trending = catalogs.trending }
        if new.isEmpty { new = catalogs.new }
        if action.isEmpty { action = catalogs.action }
        heroIndex = min(heroIndex, max(heroItems.count - 1, 0))
        return !recommended.isEmpty || !trending.isEmpty || !new.isEmpty || !action.isEmpty
    }

    private func autoAdvanceHero() async {
        guard heroItems.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, heroItems.count > 1 else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                    heroIndex = (heroIndex + 1) % heroItems.count
                }
            }
        }
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
                NavigationLink(value: AnimeSectionRoute(title: title, items: items)) {
                    Text("See All")
                        .font(.footnote.weight(.semibold))
                }
                .disabled(items.isEmpty)
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

struct AnimeSectionRoute: Hashable {
    let title: String
    let items: [Anime]
}

struct AnimeSectionView: View {
    let title: String
    let items: [Anime]

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(items) { anime in
                    NavigationLink(value: anime) {
                        AnimePosterCard(anime: anime, width: 132, height: 196)
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            .padding(18)
            .padding(.bottom, 40)
        }
        .background(PremiumBackdrop())
        .navigationTitle(title)
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
