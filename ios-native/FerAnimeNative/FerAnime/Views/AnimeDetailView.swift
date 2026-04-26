import SwiftUI

struct AnimeDetailView: View {
    @EnvironmentObject private var appState: AppState
    let anime: Anime
    @State private var details: Anime?
    @State private var episodes: [Episode] = []
    @State private var expanded = false

    private var display: Anime { details ?? anime }
    private var sourceId: String { display.sourceId ?? anime.sourceId ?? "anizone" }

    var body: some View {
        ZStack {
            CinematicBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    synopsis
                    episodeList
                }
                .padding(.bottom, 110)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var hero: some View {
        GeometryReader { proxy in
            let heroHeight = min(max(proxy.size.height * 0.58, 390), 500)

            ZStack(alignment: .bottomLeading) {
                PosterImage(url: URL(string: display.banner ?? display.cover ?? ""), cornerRadius: 0)
                    .frame(height: heroHeight)
                    .clipped()
                    .overlay {
                        LinearGradient(colors: [.clear, Theme.background.opacity(0.20), Theme.background], startPoint: .top, endPoint: .bottom)
                    }

                VStack(alignment: .leading, spacing: 14) {
                    Text(display.title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
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
                            PlayerView(anime: display, episode: first)
                        } label: {
                            LiquidGlass(cornerRadius: 24, glow: Theme.accent.opacity(0.44)) {
                                HStack(spacing: 10) {
                                    Image(systemName: "play.fill")
                                    Text("Play")
                                }
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                            }
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(20)
            }
        }
        .frame(height: 520)
    }

    private var synopsis: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Story")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(display.synopsis?.isEmpty == false ? display.synopsis! : "No synopsis available from this source yet.")
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(Theme.secondary)
                .lineLimit(expanded ? nil : 4)

            Button(expanded ? "Show less" : "Read more") {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { expanded.toggle() }
            }
            .font(.callout.weight(.bold))
            .foregroundStyle(Theme.cyan)
        }
        .padding(.horizontal, 18)
    }

    private var episodeList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Episodes")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)

            ForEach(episodes) { episode in
                NavigationLink {
                    PlayerView(anime: display, episode: episode)
                } label: {
                    LiquidGlass(cornerRadius: 24, glow: Theme.violet.opacity(0.18)) {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.aurora.opacity(0.40))
                                .frame(width: 92, height: 58)
                                .overlay {
                                    Image(systemName: "play.fill")
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 5) {
                                Text("Episode \(Int(episode.number))")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.cyan)
                                Text(episode.title)
                                    .font(.headline.weight(.bold))
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
            }
        }
    }

    private func load() async {
        guard let sourceId = anime.sourceId else { return }
        details = try? await appState.client.details(sourceId: sourceId, animeId: anime.id)
        episodes = (try? await appState.client.episodes(sourceId: sourceId, animeId: anime.id)) ?? []
    }
}
