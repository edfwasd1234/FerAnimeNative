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
    @State private var selectedEmbedIndex = 0
    @State private var playbackMessage = ""

    private var sourceId: String { episode.sourceId ?? anime.sourceId ?? "anizone" }

    var body: some View {
        VStack(spacing: 0) {
            Theme.background.ignoresSafeArea()
                .frame(height: 0)

            if let stream = selectedStream {
                NativeVideoPlayerView(stream: stream) { currentTime, duration in
                    appState.updateProgress(anime: anime, episode: episode, currentTime: currentTime, duration: duration)
                }
            } else if let embed = selectedEmbed, let url = URL(string: embed.url) {
                WebEmbedPlayerView(url: url) {
                    advanceToNextEmbed()
                }
            } else {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(.white)
                    Text(playbackMessage.isEmpty ? resolver.message : playbackMessage)
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
        .onAppear {
            appState.updateProgress(anime: anime, episode: episode, currentTime: 1, duration: 100)
        }
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
        playbackMessage = ""
        selectedEmbedIndex = 0
        if ["hianime", "anigo"].contains(result?.sourceId) {
            selectedStream = nil
            selectedEmbed = result?.embeds.first
        } else {
            selectedStream = result?.direct.first
            selectedEmbed = result?.direct.first == nil ? result?.embeds.first : nil
        }
    }

    private func advanceToNextEmbed() {
        guard let embeds = playback?.embeds, !embeds.isEmpty else {
            selectedEmbed = nil
            playbackMessage = "This embed is unavailable right now."
            return
        }

        let nextIndex = selectedEmbedIndex + 1
        guard embeds.indices.contains(nextIndex) else {
            selectedEmbed = nil
            playbackMessage = "All embed mirrors are unavailable right now."
            return
        }

        selectedEmbedIndex = nextIndex
        selectedEmbed = embeds[nextIndex]
        playbackMessage = "Trying another mirror..."
    }
}
