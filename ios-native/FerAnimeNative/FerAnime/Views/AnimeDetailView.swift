import SwiftUI

struct AnimeDetailView: View {
    @EnvironmentObject private var appState: AppState
    let anime: Anime
    @State private var details: Anime?
    @State private var episodes: [Episode] = []
    @State private var expanded = false
    @State private var resolvedAnime: Anime?
    @State private var sourceMatches: [Anime] = []
    @State private var isMatchingSources = false

    private var display: Anime { details ?? anime }
    private var playbackAnime: Anime { resolvedAnime ?? display }
    private var sourceId: String { playbackAnime.sourceId ?? display.sourceId ?? anime.sourceId ?? "jikan" }

    var body: some View {
        ZStack {
            CinematicBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                        .glassAppear()
                    synopsis
                        .glassAppear(delay: 0.06)
                    sourceSection
                        .glassAppear(delay: 0.08)
                    episodeList
                        .glassAppear(delay: 0.10)
                }
                .padding(.bottom, 92)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var hero: some View {
        GeometryReader { proxy in
            let heroHeight = min(max(proxy.size.height * 0.62, 320), 380)

            ZStack(alignment: .bottomLeading) {
                PosterImage(url: URL(string: display.banner ?? display.cover ?? ""), cornerRadius: 0)
                    .frame(height: heroHeight)
                    .clipped()
                    .overlay {
                        Rectangle()
                            .fill(.black.opacity(0.24))
                    }

                VStack(alignment: .leading, spacing: 14) {
                    Text(display.title)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(.white)
                        .lineLimit(4)

                    HStack(spacing: 10) {
                        if let score = display.score {
                            Label(String(format: "%.1f", score), systemImage: "star.fill")
                        }
                        if let year = display.year {
                            Text(String(year))
                        }
                        Text(sourceId)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))

                    if let first = episodes.first {
                        NavigationLink {
                            PlayerView(anime: playbackAnime, episode: first)
                        } label: {
                            SystemPlayLabel()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.impact(.medium) })
                    }
                }
                .padding(18)
            }
        }
        .frame(height: 400)
    }

    private var synopsis: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Story")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text(display.synopsis?.isEmpty == false ? display.synopsis! : "No synopsis available from this source yet.")
                .font(.callout)
                .lineSpacing(4)
                .foregroundStyle(Theme.secondary)
                .lineLimit(expanded ? nil : 4)

            Button(expanded ? "Show less" : "Read more") {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { expanded.toggle() }
            }
            .font(.callout.weight(.bold))
            .foregroundStyle(Theme.appleBlue)
        }
        .padding(.horizontal, 18)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Source")
                    .font(.headline.weight(.semibold))
                Spacer()
                if isMatchingSources {
                    ProgressView()
                }
            }
            .padding(.horizontal, 18)

            if sourceMatches.isEmpty {
                Text(isMatchingSources ? "Matching Jikan metadata to streaming sources..." : "No streaming source matched yet.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 18)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(sourceMatches) { match in
                            Button {
                                Task { await selectSource(match) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(match.sourceId ?? "source")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.appleBlue)
                                    Text(match.title)
                                        .font(.footnote.weight(.semibold))
                                        .lineLimit(1)
                                }
                                .frame(width: 170, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    private var episodeList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Episodes")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button {
                    appState.queueDownload(anime: playbackAnime, episode: nil)
                } label: {
                    Label("Download All", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(episodes.isEmpty)
            }
            .padding(.horizontal, 18)

            ForEach(episodes) { episode in
                LiquidGlass(cornerRadius: 20, glow: Theme.appleBlue.opacity(0.08)) {
                    HStack(spacing: 14) {
                        NavigationLink {
                            PlayerView(anime: playbackAnime, episode: episode)
                        } label: {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.secondary.opacity(0.18))
                                    .frame(width: 92, height: 58)
                                    .overlay {
                                        Image(systemName: "play.fill")
                                            .foregroundStyle(.white)
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Episode \(Int(episode.number))")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.appleBlue)
                                    Text(episode.title)
                                        .font(.callout.weight(.semibold))
                                        .lineLimit(2)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            appState.queueDownload(anime: playbackAnime, episode: episode)
                        } label: {
                            Image(systemName: "arrow.down.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(12)
                }
                .padding(.horizontal, 18)
                .scrollTransition(.interactive, axis: .vertical) { content, phase in
                    content
                        .scaleEffect(phase.isIdentity ? 1 : 0.96)
                        .opacity(phase.isIdentity ? 1 : 0.68)
                }
            }
        }
    }

    private func load() async {
        if let sourceId = anime.sourceId, sourceId != "jikan" {
            let detailKey = appState.cacheKey(sourceId, anime.id, "details")
            let episodesKey = appState.cacheKey(sourceId, anime.id, "episodes")
            if let cachedDetails = appState.cachedAnimeDetails[detailKey] {
                details = cachedDetails
            } else if let loadedDetails = try? await appState.client.details(sourceId: sourceId, animeId: anime.id) {
                details = loadedDetails
                appState.cachedAnimeDetails[detailKey] = loadedDetails
            }
            if let cachedEpisodes = appState.cachedEpisodes[episodesKey] {
                episodes = cachedEpisodes
            } else {
                let loadedEpisodes = (try? await appState.client.episodes(sourceId: sourceId, animeId: anime.id)) ?? []
                episodes = loadedEpisodes
                if !loadedEpisodes.isEmpty {
                    appState.cachedEpisodes[episodesKey] = loadedEpisodes
                }
            }
            return
        }

        let matchesKey = appState.cacheKey("jikan", anime.id, anime.title.lowercased(), "matches")
        if let cachedMatches = appState.cachedSourceMatches[matchesKey], !cachedMatches.isEmpty {
            sourceMatches = cachedMatches
            if let first = cachedMatches.first,
               let sourceId = first.sourceId,
               let cachedEpisodes = appState.cachedEpisodes[appState.cacheKey(sourceId, first.id, "episodes")] {
                resolvedAnime = first
                episodes = cachedEpisodes
                return
            }
        }

        isMatchingSources = true
        defer { isMatchingSources = false }
        if sourceMatches.isEmpty { sourceMatches = [] }
        for source in ["anizone", "animeheaven", "hianime"] {
            let match: Anime
            if let cachedMatch = sourceMatches.first(where: { $0.sourceId == source }) {
                match = cachedMatch
            } else {
                guard let loadedMatch = try? await appState.client.search(anime.title, sourceId: source).first else { continue }
                match = loadedMatch
                sourceMatches.append(loadedMatch)
            }
            let episodesKey = appState.cacheKey(source, match.id, "episodes")
            let sourceEpisodes: [Episode]
            if let cached = appState.cachedEpisodes[episodesKey] {
                sourceEpisodes = cached
            } else {
                let loaded = (try? await appState.client.episodes(sourceId: source, animeId: match.id)) ?? []
                sourceEpisodes = loaded
                if !loaded.isEmpty {
                    appState.cachedEpisodes[episodesKey] = loaded
                }
            }
            if resolvedAnime == nil, !sourceEpisodes.isEmpty {
                resolvedAnime = match
                episodes = sourceEpisodes
            }
        }
        if !sourceMatches.isEmpty {
            appState.cachedSourceMatches[matchesKey] = sourceMatches
        }
    }

    private func selectSource(_ match: Anime) async {
        guard let sourceId = match.sourceId else { return }
        isMatchingSources = true
        defer { isMatchingSources = false }
        resolvedAnime = match
        let episodesKey = appState.cacheKey(sourceId, match.id, "episodes")
        if let cached = appState.cachedEpisodes[episodesKey] {
            episodes = cached
        } else {
            let loaded = (try? await appState.client.episodes(sourceId: sourceId, animeId: match.id)) ?? []
            episodes = loaded
            if !loaded.isEmpty {
                appState.cachedEpisodes[episodesKey] = loaded
            }
        }
        Haptics.impact(.light)
    }
}
