import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Continue Watching") {
                    if appState.continueWatching.isEmpty {
                        ContentUnavailableView("No Watch History", systemImage: "play.rectangle", description: Text("Start an episode and it will appear here."))
                    } else {
                        ForEach(appState.continueWatching) { item in
                            NavigationLink {
                                PlayerView(anime: item.anime, episode: item.episode)
                            } label: {
                                HStack(spacing: 12) {
                                    PosterImage(url: URL(string: item.image ?? ""), cornerRadius: 12)
                                        .frame(width: 58, height: 58)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.animeTitle)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Text("Episode \(Int(item.episodeNumber))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        ProgressView(value: item.progress)
                                            .tint(Theme.appleBlue)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section("Downloads") {
                    if appState.downloads.isEmpty {
                        ContentUnavailableView("No Downloads", systemImage: "arrow.down.circle", description: Text("Queue an anime or episode from the detail page."))
                    } else {
                        ForEach(appState.downloads) { item in
                            HStack(spacing: 12) {
                                PosterImage(url: URL(string: item.image ?? ""), cornerRadius: 12)
                                    .frame(width: 52, height: 52)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.animeTitle)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text(item.episodeNumber.map { "Episode \(Int($0))" } ?? "Entire anime")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.status)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PremiumBackdrop())
            .navigationTitle("Library")
        }
    }
}

private extension WatchProgress {
    var anime: Anime {
        Anime(
            id: animeId,
            sourceId: sourceId,
            malId: nil,
            anidbId: nil,
            title: animeTitle,
            subtitle: sourceId,
            cover: image,
            banner: image,
            year: nil,
            score: nil,
            genres: [],
            status: nil,
            progress: nil,
            synopsis: nil
        )
    }

    var episode: Episode {
        Episode(
            id: episodeId,
            animeId: animeId,
            sourceId: sourceId,
            number: episodeNumber,
            title: episodeTitle,
            duration: nil,
            streamUrl: nil
        )
    }
}
