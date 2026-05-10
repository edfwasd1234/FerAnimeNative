import SwiftUI

struct AnimeDetailView: View {
    @EnvironmentObject private var appState: AppState
    let anime: Anime
    @State private var details: Anime?
    @State private var episodes: [Episode] = []
    @State private var expanded = false
    @State private var resolvedAnime: Anime?
    @State private var preferredLanguage = "sub"

    private var display: Anime { details ?? anime }
    private var playbackAnime: Anime { resolvedAnime ?? display }
    private var sourceId: String { playbackAnime.sourceId ?? display.sourceId ?? anime.sourceId ?? "jikan" }

    // True when the source returns distinct sub and dub episode rows (AniGo pattern)
    private var hasDubVariants: Bool {
        episodes.contains { $0.duration?.lowercased() == "dub" }
    }

    private var filteredEpisodes: [Episode] {
        guard hasDubVariants else { return episodes }
        return episodes.filter { ep in
            let lang = (ep.duration ?? "sub").lowercased()
            return lang == preferredLanguage.lowercased()
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            PremiumBackdrop()

            // Blurred ambient banner behind everything
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
                        MetaBadge(systemImage: "tv", text: sourceId)
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
                                PlayerView(anime: playbackAnime, episode: first)
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
            HStack {
                Text("Episodes")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                // Sub/Dub toggle — only shown when the source returns distinct sub+dub rows
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

            if episodes.isEmpty {
                LiquidGlass(cornerRadius: 18) {
                    HStack {
                        Image(systemName: "film.stack")
                            .foregroundStyle(Theme.tertiary)
                        Text("No episodes found from this source.")
                            .font(.callout)
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(18)
                }
                .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredEpisodes) { episode in
                        EpisodeRow(episode: episode, anime: playbackAnime)
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

        for source in ["wcotv", "animegg"] {
            if let sid = anime.sourceId, sid == source {
                let detailKey = appState.cacheKey(sid, anime.id, "details")
                let episodesKey = appState.cacheKey(sid, anime.id, "episodes")
                if let cached = appState.cachedAnimeDetails[detailKey] {
                    details = cached
                } else if let loaded = try? await appState.client.details(sourceId: sid, animeId: anime.id) {
                    details = loaded
                    appState.cachedAnimeDetails[detailKey] = loaded
                }
                if let cached = appState.cachedEpisodes[episodesKey] {
                    episodes = cached
                } else {
                    let loaded = (try? await appState.client.episodes(sourceId: sid, animeId: anime.id)) ?? []
                    episodes = loaded
                    if !loaded.isEmpty { appState.cachedEpisodes[episodesKey] = loaded }
                }
                return
            }

            guard let match = try? await appState.client.search(anime.title, sourceId: source).first else { continue }
            let matchEpsKey = appState.cacheKey(source, match.id, "episodes")
            let loaded: [Episode]
            if let cached = appState.cachedEpisodes[matchEpsKey] {
                loaded = cached
            } else {
                loaded = (try? await appState.client.episodes(sourceId: source, animeId: match.id)) ?? []
                if !loaded.isEmpty { appState.cachedEpisodes[matchEpsKey] = loaded }
            }
            if !loaded.isEmpty {
                resolvedAnime = match
                episodes = loaded
                return
            }
        }
    }
}

// MARK: - Episode Row

private struct EpisodeRow: View {
    let episode: Episode
    let anime: Anime
    @EnvironmentObject private var appState: AppState

    var body: some View {
        LiquidGlass(cornerRadius: 18, glow: .clear) {
            HStack(spacing: 14) {
                NavigationLink {
                    PlayerView(anime: anime, episode: episode)
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
