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
    @State private var showSearch = false
    @State private var showCalendar = false
    private let jikan = JikanClient()

    private var heroItems: [Anime] {
        let combined = recommended + trending
        var seen = Set<String>()
        return combined.filter { anime in
            guard !seen.contains(anime.id) else { return false }
            seen.insert(anime.id)
            return true
        }
        .prefix(6).map { $0 }
    }

    private var continueItems: [WatchProgress] {
        Array(appState.continueWatching.prefix(8))
    }

    private var becauseYouWatched: [Anime] {
        let watchedTitles = Set(appState.continueWatching.map { $0.animeTitle.lowercased() })
        let watchedGenres = Set((recommended + trending + new + action)
            .filter { watchedTitles.contains($0.title.lowercased()) }
            .flatMap(\.genres))
        let pool = trending + new + action + recommended
        var seen = Set<String>()
        let personalized = pool.filter { anime in
            guard !watchedTitles.contains(anime.title.lowercased()), !seen.contains(anime.id) else { return false }
            let hasMatch = !watchedGenres.isEmpty && anime.genres.contains { watchedGenres.contains($0) }
            if hasMatch { seen.insert(anime.id); return true }
            return false
        }
        if !personalized.isEmpty { return Array(personalized.prefix(12)) }
        return Array(pool.filter { seen.insert($0.id).inserted }.prefix(12))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackdrop()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        lensPickBanner
                            .glassAppear(delay: 0.04)

                        heroCarousel
                            .glassAppear(delay: 0.08)

                        if !continueItems.isEmpty {
                            continueWatchingRail
                                .glassAppear(delay: 0.12)
                        }

                        if !appState.lensWatchlist.isEmpty {
                            watchlistRail
                                .glassAppear(delay: 0.16)
                        }

                        if !becauseYouWatched.isEmpty {
                            AnimeRail(
                                title: appState.continueWatching.isEmpty ? "Recommended" : "Because You Watched",
                                items: becauseYouWatched
                            )
                            .glassAppear(delay: 0.18)
                        }

                        AnimeRail(title: "Trending Now", items: trending)
                            .glassAppear(delay: 0.20)

                        AnimeRail(title: "New Episodes", items: new)
                            .glassAppear(delay: 0.22)

                        AnimeRail(title: "Action", items: action)
                            .glassAppear(delay: 0.24)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
                .refreshable { await load(force: true) }
            }
            .navigationTitle("FerAnime")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("FerAnime")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button { showCalendar = true; Haptics.impact(.light) } label: {
                            Image(systemName: "calendar")
                                .font(.headline)
                                .foregroundStyle(Theme.appleBlue)
                                .frame(width: 36, height: 36)
                                .background(Theme.panel, in: Circle())
                        }
                        Button { showSearch = true; Haptics.impact(.light) } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.headline)
                                .foregroundStyle(Theme.appleBlue)
                                .frame(width: 36, height: 36)
                                .background(Theme.panel, in: Circle())
                        }
                    }
                }
            }
            .navigationDestination(for: Anime.self) { AnimeDetailView(anime: $0) }
            .navigationDestination(for: AnimeSectionRoute.self) { route in
                AnimeSectionView(title: route.title, items: route.items)
            }
            .navigationDestination(isPresented: $showCalendar) {
                SeasonalCalendarView()
            }
            .fullScreenCover(isPresented: $showSearch) {
                SearchView().environmentObject(appState)
            }
            .task {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { appeared = true }
                applyCachedCatalogs()
                if recommended.isEmpty && trending.isEmpty && new.isEmpty && action.isEmpty {
                    await load(force: false)
                }
            }
            .task(id: heroItems.count) { await autoAdvanceHero() }
        }
    }

    // MARK: - Lens Pick Banner

    private var lensPickBanner: some View {
        NavigationLink { LensPickView() } label: {
            LiquidGlass(cornerRadius: 28, glow: Theme.appleBlue.opacity(0.16)) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Find My Watch")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("One pick tuned to your mood, time & services.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Theme.appleBlue.opacity(0.18))
                            .frame(width: 56, height: 56)
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.appleBlue)
                    }
                }
                .padding(18)
            }
        }
        .buttonStyle(PressScaleStyle())
        .padding(.horizontal, 20)
    }

    // MARK: - Hero Carousel

    private var heroCarousel: some View {
        Group {
            if heroItems.isEmpty {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.panel)
                    .shimmer()
                    .frame(maxWidth: .infinity)
                    .frame(height: 330)
                    .padding(.horizontal, 20)
            } else {
                TabView(selection: $heroIndex) {
                    ForEach(Array(heroItems.enumerated()), id: \.element.id) { index, anime in
                        NavigationLink(value: anime) {
                            HeroCard(anime: anime)
                        }
                        .buttonStyle(.plain)
                        .tag(index)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.impact(.medium) })
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 350)
                .clipped()
            }
        }
    }

    // MARK: - Continue Watching

    private var continueWatchingRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Continue Watching")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(continueItems) { item in
                        NavigationLink {
                            PlayerView(anime: item.anime, episode: item.episode)
                        } label: {
                            ContinueCard(item: item)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Watchlist Rail

    private var watchlistRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "My Watchlist")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(appState.lensWatchlist.prefix(8))) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            PosterImage(url: URL(string: item.artwork ?? ""), cornerRadius: 18)
                                .frame(width: 120, height: 174)
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .frame(width: 120, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Load

    private func load(force: Bool) async {
        if !force, applyCachedCatalogs() { loading = false; return }
        loading = true
        let catalogs = await jikan.homeCatalogs()
        if !catalogs.recommended.isEmpty { recommended = catalogs.recommended }
        if !catalogs.trending.isEmpty { trending = catalogs.trending }
        if !catalogs.new.isEmpty { new = catalogs.new }
        if !catalogs.action.isEmpty { action = catalogs.action }
        if !recommended.isEmpty || !trending.isEmpty || !new.isEmpty || !action.isEmpty {
            appState.cachedHomeCatalogs = HomeCatalogs(recommended: recommended, trending: trending, new: new, action: action)
            appState.notifyNewEpisodeIfNeeded(new.first)
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

// MARK: - Hero Card

private struct HeroCard: View {
    let anime: Anime

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PosterImage(url: URL(string: anime.banner ?? anime.cover ?? ""), cornerRadius: 28)
                .frame(maxWidth: .infinity)
                .frame(height: 330)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.20), location: 0.45),
                    .init(color: .black.opacity(0.72), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if let score = anime.score {
                        MetaBadge(systemImage: "star.fill", text: String(format: "%.1f", score), color: .yellow)
                    }
                    MetaBadge(systemImage: "calendar", text: anime.year.map(String.init) ?? "Now")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.30), in: Capsule())

                Text(anime.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.76)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)

                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                    Text("Watch Now")
                        .font(.callout.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Theme.appleBlue, in: Capsule())
            }
            .padding(20)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Continue Card

private struct ContinueCard: View {
    let item: WatchProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                PosterImage(url: URL(string: item.image ?? ""), cornerRadius: 16)
                    .frame(width: 200, height: 114)

                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black.opacity(0.60)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 40)
                    ProgressView(value: item.progress)
                        .tint(Theme.appleBlue)
                        .frame(width: 200)
                        .padding(.bottom, 4)
                }
            }

            Text(item.animeTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 200, alignment: .leading)

            Text("Episode \(Int(item.episodeNumber))")
                .font(.caption)
                .foregroundStyle(Theme.tertiary)
        }
    }
}

// MARK: - Anime Rail

struct AnimeRail: View {
    let title: String
    let items: [Anime]
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { anime in
                        NavigationLink(value: anime) {
                            AnimePosterCard(anime: anime, width: compact ? 200 : 130, height: compact ? 114 : 192)
                        }
                        .buttonStyle(PressScaleStyle())
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.70)
                        }
                    }
                }
                .padding(.horizontal, 20)
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

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(items) { anime in
                    NavigationLink(value: anime) {
                        AnimePosterCard(anime: anime, width: 130, height: 192)
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            .padding(18)
            .padding(.bottom, 40)
        }
        .background(PremiumBackdrop())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct AnimePosterCard: View {
    let anime: Anime
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                PosterImage(url: URL(string: anime.cover ?? anime.banner ?? ""), cornerRadius: 18)
                    .frame(width: width, height: height)

                if let subtitle = anime.subtitle ?? anime.sourceId {
                    Text(subtitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.48), in: Capsule())
                        .padding(8)
                }
            }

            Text(anime.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)
        }
    }
}

struct CinematicBackground: View {
    var body: some View { PremiumBackdrop() }
}

struct LensFingerprintStrip: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        LiquidGlass(cornerRadius: 22) {
            HStack(spacing: 14) {
                RadarChart(values: appState.tasteFingerprint.axes)
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your taste fingerprint")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Every log nudges Lens closer to you.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
            }
            .padding(14)
        }
    }
}

private extension WatchProgress {
    var anime: Anime {
        Anime(id: animeId, sourceId: sourceId, malId: nil, anidbId: nil,
              title: animeTitle, subtitle: sourceId, cover: image, banner: image,
              year: nil, score: nil, genres: [], status: nil, progress: nil, synopsis: nil)
    }
    var episode: Episode {
        Episode(id: episodeId, animeId: animeId, sourceId: sourceId,
                number: episodeNumber, title: episodeTitle, duration: nil, streamUrl: nil)
    }
}
