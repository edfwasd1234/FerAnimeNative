import SwiftUI

struct AnimeDetailView: View {
    @EnvironmentObject private var appState: AppState
    let anime: Anime
    @State private var details: Anime?
    @State private var episodes: [Episode] = []
    @State private var expanded = false
    @State private var resolvedAnime: Anime?

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

    private var episodeList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Episodes")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)

            ForEach(episodes) { episode in
                NavigationLink {
                    PlayerView(anime: playbackAnime, episode: episode)
                } label: {
                    LiquidGlass(cornerRadius: 20, glow: Theme.appleBlue.opacity(0.08)) {
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
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Theme.tertiary)
                        }
                        .padding(12)
                    }
                }
                .buttonStyle(PressScaleStyle())
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
            details = try? await appState.client.details(sourceId: sourceId, animeId: anime.id)
            episodes = (try? await appState.client.episodes(sourceId: sourceId, animeId: anime.id)) ?? []
            return
        }

        for source in ["anizone", "animeheaven", "hianime"] {
            guard let match = try? await appState.client.search(anime.title, sourceId: source).first else { continue }
            let sourceEpisodes = (try? await appState.client.episodes(sourceId: source, animeId: match.id)) ?? []
            if !sourceEpisodes.isEmpty {
                resolvedAnime = match
                episodes = sourceEpisodes
                return
            }
        }
    }
}
