import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingLogSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("Lens Watchlist") {
                    if appState.lensWatchlist.isEmpty {
                        ContentUnavailableView("Nothing Saved", systemImage: "plus.rectangle.on.rectangle", description: Text("Save a Lens Pick or tracked title and it will appear here."))
                    } else {
                        ForEach(appState.lensWatchlist) { item in
                            HStack(spacing: 12) {
                                PosterImage(url: URL(string: item.artwork ?? ""), cornerRadius: 12)
                                    .frame(width: 52, height: 68)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Label(item.kind.title, systemImage: item.kind.symbol)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Watch Logs") {
                    if appState.watchLogs.isEmpty {
                        ContentUnavailableView("No Deep Logs", systemImage: "star.bubble", description: Text("Lens Pick can quick-log a title, and full logging comes next."))
                    } else {
                        ForEach(appState.watchLogs) { log in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(log.media.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(String(format: "%.1f", log.rating))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.appleBlue)
                                }
                                Text([log.mood, log.watchStyle, log.watchedWith].filter { !$0.isEmpty }.joined(separator: " | "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !log.reactions.isEmpty {
                                    Text(log.reactions.map(\.title).joined(separator: ", "))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

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

                Section("Manga And Source Sync") {
                    NavigationLink {
                        MangaView()
                    } label: {
                        Label("Open manga tracker", systemImage: "books.vertical.fill")
                    }
                    Label("Anime-to-source sync placeholders are stored locally for V1.", systemImage: "link")
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PremiumBackdrop())
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLogSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                ManualWatchLogView()
                    .environmentObject(appState)
            }
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
