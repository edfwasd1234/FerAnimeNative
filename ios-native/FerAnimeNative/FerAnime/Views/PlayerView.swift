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
    @State private var controlsVisible = true

    private var sourceId: String { episode.sourceId ?? anime.sourceId ?? "anizone" }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let stream = selectedStream {
                NativeVideoPlayerView(stream: stream)
            } else if let embed = selectedEmbed, let url = URL(string: embed.url) {
                WebEmbedPlayerView(url: url)
                    .ignoresSafeArea()
            } else {
                ProgressView(resolver.message)
                    .tint(.white)
                    .foregroundStyle(.white)
            }

            if controlsVisible {
                controls
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                controlsVisible.toggle()
            }
        }
        .task { await resolve() }
    }

    private var controls: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    LiquidGlass(cornerRadius: 22, glow: Theme.cyan.opacity(0.16)) {
                        HStack(spacing: 12) {
                            Image(systemName: "chevron.left")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(anime.title)
                                    .font(.headline.weight(.bold))
                                    .lineLimit(1)
                                Text("Episode \(Int(episode.number))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                    }
                }
                .buttonStyle(PressScaleStyle())

                Spacer()

                if let playback {
                    LiquidGlass(cornerRadius: 20, glow: Theme.accent.opacity(0.18)) {
                        Text(playback.sourceId)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            LiquidGlass(cornerRadius: 30, glow: Theme.violet.opacity(0.26)) {
                VStack(spacing: 16) {
                    HStack(spacing: 18) {
                        Button { } label: { Image(systemName: "gobackward.10") }
                        Button { } label: {
                            Image(systemName: "play.fill")
                                .font(.largeTitle.weight(.bold))
                        }
                        Button { } label: { Image(systemName: "goforward.10") }
                    }
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        ForEach(playback?.direct ?? []) { stream in
                            Button {
                                selectedStream = stream
                                selectedEmbed = nil
                            } label: {
                                Text(stream.quality.isEmpty ? stream.label : stream.quality)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(selectedStream == stream ? .white : Theme.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedStream == stream ? Theme.panelStrong : Color.white.opacity(0.06), in: Capsule())
                            }
                        }

                        ForEach(playback?.embeds ?? []) { embed in
                            Button {
                                selectedEmbed = embed
                                selectedStream = nil
                            } label: {
                                Text("Embed")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(selectedEmbed == embed ? .white : Theme.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedEmbed == embed ? Theme.panelStrong : Color.white.opacity(0.06), in: Capsule())
                            }
                        }
                    }
                }
                .padding(18)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 26)
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
