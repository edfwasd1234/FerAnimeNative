import SwiftUI

struct AnimeDetailView: View {
    @EnvironmentObject private var appState: AppState
    let anime: Anime
    @State private var details: Anime?
    @State private var expanded = false
    @State private var selectedSource = "wcotv"
    @State private var episodesBySource: [String: [Episode]] = [:]
    @State private var resolvedAnimeBySource: [String: Anime] = [:]
    @State private var loadingBySource: Set<String> = []
    @State private var preferredLanguage = "sub"

    private static let sources: [(id: String, label: String)] = [
        ("wcotv",   "Server 1"),
        ("animegg", "Server 2")
    ]

    private var display: Anime { details ?? anime }
    private var episodes: [Episode] { episodesBySource[selectedSource] ?? [] }
    private var playbackAnime: Anime { resolvedAnimeBySource[selectedSource] ?? display }
    private var isLoadingCurrent: Bool { loadingBySource.contains(selectedSource) }

    // animegg always has both sub/dub at stream level; wcotv has distinct episode rows
    private var hasDubVariants: Bool {
        selectedSource == "animegg" ||
        episodes.contains { ($0.duration ?? "").lowercased() == "dub" }
    }

    private var filteredEpisodes: [Episode] {
        // animegg: sub/dub is at the stream level — don't filter episode rows
        if selectedSource == "animegg" { return episodes }
        guard hasDubVariants else { return episodes }
        return episodes.filter { ($0.duration ?? "sub").lowercased() == preferredLanguage.lowercased() }
    }

    var body: some View {
        ZStack(alignment: .top) {
            PremiumBackdrop()

            AsyncImage(url: URL(string: display.banner ?? display.cover ?? "")) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 360)
                        .blur(radius: 52)
                        .opacity(0.26)
                        .clipped()
                        .ignoresSafeArea(edges: .top)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection
                        .glassAppear()
                    contentSection
                        .glassAppear(delay: 0.08)
                }
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await load() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 400, maxHeight: 400)
            .overlay {
                AsyncImage(url: URL(string: display.banner ?? display.cover ?? "")) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.white.opacity(0.08)
                    }
                }
            }
            .clipped()
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.18), location: 0.42),
                        .init(color: Theme.background.opacity(0.94), location: 0.88),
                        .init(color: Theme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(display.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                    HStack(spacing: 12) {
                        if let score = display.score {
                            MetaBadge(systemImage: "star.fill", text: String(format: "%.1f", score), color: .yellow)
                        }
                        if let year = display.year {
                            MetaBadge(systemImage: "calendar", text: String(year))
                        }
                        if let status = display.status {
                            MetaBadge(systemImage: "circle.fill", text: status)
                        }
                    }

                    if !display.genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(display.genres.prefix(6), id: \.self) { genre in
                                    GlassChip(text: genre)
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        if let first = filteredEpisodes.first ?? episodes.first {
                            NavigationLink {
                                PlayerView(anime: playbackAnime, episode: first, preferredLanguage: preferredLanguage)
                            } label: {
                                Label("Play", systemImage: "play.fill")
                                    .font(.headline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundStyle(.white)
                                    .background(Theme.appleBlue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(PressScaleStyle())
                            .simultaneousGesture(TapGesture().onEnded { Haptics.impact(.medium) })
                        }

                        Button {
                            appState.addToLensWatchlist(MediaItem(anime: playbackAnime))
                            Haptics.impact(.light)
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline.weight(.bold))
                                .frame(width: 52, height: 52)
                                .foregroundStyle(.white)
                                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Theme.strokeBright, lineWidth: 0.75)
                                )
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            }
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            synopsisSection
            episodeSection
        }
        .padding(.top, 20)
    }

    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Story")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)

            LiquidGlass(cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(display.synopsis?.isEmpty == false ? display.synopsis! : "No synopsis available from this source yet.")
                        .font(.callout)
                        .lineSpacing(5)
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(expanded ? nil : 4)

                    Button(expanded ? "Show less" : "Read more") {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { expanded.toggle() }
                    }
                    .font(.callout.weight(.bold))
                    .foregroundStyle(Theme.appleBlue)
                }
                .padding(18)
            }
            .padding(.horizontal, 20)
        }
    }

    private var episodeSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Server picker ────────────────────────────────────────────────
            HStack(spacing: 6) {
                ForEach(Self.sources, id: \.id) { src in
                    Button {
                        selectedSource = src.id
                        Haptics.selection()
                    } label: {
                        Text(src.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedSource == src.id ? .white : Theme.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedSource == src.id ? Theme.appleBlue.opacity(0.25) : Color.white.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        selectedSource == src.id ? Theme.appleBlue.opacity(0.40) : Color.white.opacity(0.08),
                                        lineWidth: 0.75
                                    )
                            )
                    }
                    .buttonStyle(PressScaleStyle())
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            // ── Episodes header: title + sub/dub + download ──────────────────
            HStack {
                Text("Episodes")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if isLoadingCurrent {
                    ProgressView().scaleEffect(0.8).padding(.leading, 4)
                }
                Spacer()
                if hasDubVariants {
                    HStack(spacing: 0) {
                        ForEach(["sub", "dub"], id: \.self) { lang in
                            Button {
                                preferredLanguage = lang
                                appState.setShowLanguagePreference(lang, for: anime.id)
                                Haptics.selection()
                            } label: {
                                Text(lang.uppercased())
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.6)
                                    .foregroundStyle(preferredLanguage == lang ? .white : Theme.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        preferredLanguage == lang ? Theme.appleBlue.opacity(0.30) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                            }
                            .buttonStyle(PressScaleStyle())
                        }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.75)
                    )
                }
                Button {
                    appState.queueDownload(anime: playbackAnime, episode: nil)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.headline)
                        .foregroundStyle(Theme.appleBlue)
                }
                .disabled(episodes.isEmpty)
                .padding(.leading, hasDubVariants ? 8 : 0)
            }
            .padding(.horizontal, 20)

            // ── Episode list ─────────────────────────────────────────────────
            if episodes.isEmpty {
                LiquidGlass(cornerRadius: 18) {
                    HStack {
                        if isLoadingCurrent {
                            ProgressView().scaleEffect(0.9)
                            Text("Loading episodes…")
                                .font(.callout)
                                .foregroundStyle(Theme.secondary)
                        } else {
                            Image(systemName: "film.stack")
                                .foregroundStyle(Theme.tertiary)
                            Text("No episodes found from this source.")
                                .font(.callout)
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .padding(18)
                }
                .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredEpisodes) { episode in
                        EpisodeRow(episode: episode, anime: playbackAnime, preferredLanguage: preferredLanguage)
                            .padding(.horizontal, 20)
                            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                    .opacity(phase.isIdentity ? 1 : 0.70)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Load

    private func load() async {
        if let saved = appState.showLanguagePreferences[anime.id] {
            preferredLanguage = saved
        }
        loadingBySource = ["wcotv", "animegg"]
        await loadSource("wcotv")
        await loadSource("animegg")
    }

    private func loadSource(_ source: String) async {
        defer { loadingBySource.remove(source) }

        if let sid = anime.sourceId, sid == source {
            let detailKey = appState.cacheKey(sid, anime.id, "details")
            let episodesKey = appState.cacheKey(sid, anime.id, "episodes")
            if let cached = appState.cachedAnimeDetails[detailKey] {
                details = cached
            } else if let loaded = try? await appState.client.details(sourceId: sid, animeId: anime.id) {
                details = loaded
                appState.cachedAnimeDetails[detailKey] = loaded
            }
            let eps: [Episode]
            if let cached = appState.cachedEpisodes[episodesKey] {
                eps = cached
            } else {
                eps = (try? await appState.client.episodes(sourceId: sid, animeId: anime.id)) ?? []
                if !eps.isEmpty { appState.cachedEpisodes[episodesKey] = eps }
            }
            episodesBySource[source] = eps
            return
        }

        guard let match = try? await appState.client.search(anime.title, sourceId: source).first else { return }
        resolvedAnimeBySource[source] = match
        let episodesKey = appState.cacheKey(source, match.id, "episodes")
        let eps: [Episode]
        if let cached = appState.cachedEpisodes[episodesKey] {
            eps = cached
        } else {
            eps = (try? await appState.client.episodes(sourceId: source, animeId: match.id)) ?? []
            if !eps.isEmpty { appState.cachedEpisodes[episodesKey] = eps }
        }
        episodesBySource[source] = eps
    }
}

// MARK: - Episode Row

private struct EpisodeRow: View {
    let episode: Episode
    let anime: Anime
    let preferredLanguage: String
    @EnvironmentObject private var appState: AppState

    var body: some View {
        LiquidGlass(cornerRadius: 18, glow: .clear) {
            HStack(spacing: 14) {
                NavigationLink {
                    PlayerView(anime: anime, episode: episode, preferredLanguage: preferredLanguage)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.panel)
                                .frame(width: 90, height: 56)
                            Image(systemName: "play.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.appleBlue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Episode \(Int(episode.number))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.appleBlue)
                            Text(episode.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button {
                    appState.queueDownload(anime: anime, episode: episode)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundStyle(Theme.tertiary)
                }
                .buttonStyle(.borderless)
            }
            .padding(12)
        }
    }
}
