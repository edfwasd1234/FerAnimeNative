import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let anime: Anime
    let episode: Episode

    @StateObject private var resolver = StreamResolver()
    @State private var playback: ResolvedPlayback?
    @State private var selectedStream: EpisodeStream?
    @State private var selectedEmbed: EpisodeStream?

    private var sourceId: String { episode.sourceId ?? anime.sourceId ?? "anizone" }

    var body: some View {
        VStack(spacing: 0) {
            Theme.background.ignoresSafeArea()
                .frame(height: 0)

            if let stream = selectedStream {
                NativeVideoPlayerView(stream: stream)
            } else if let embed = selectedEmbed, let url = URL(string: embed.url) {
                WebEmbedPlayerView(url: url)
            } else {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(.white)
                    Text(resolver.message)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            }
        }
        .background(Theme.background)
        .navigationTitle("Episode \(Int(episode.number))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await resolve() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let playback {
                    Text(playback.sourceId)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
    }

    private func resolve() async {
        let result = await resolver.resolve(
            client: appState.client,
            preferredSourceId: sourceId,
            animeTitle: anime.title,
            animeId: anime.id,
            episodeId: episode.id,
            episodeNumber: episode.number
        )
        playback = result
        selectedStream = result?.direct.first
        selectedEmbed = result?.direct.first == nil ? result?.embeds.first : nil
    }
}
