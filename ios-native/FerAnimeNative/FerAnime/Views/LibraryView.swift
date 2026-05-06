import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = 0
    @State private var showingLogSheet = false

    private let tabs = ["Watchlist", "History", "Downloads", "Manga"]

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackdrop()

                VStack(spacing: 0) {
                    tabPicker

                    Divider()
                        .background(Theme.stroke)

                    ScrollView(showsIndicators: false) {
                        Group {
                            switch selectedTab {
                            case 0: watchlistContent
                            case 1: historyContent
                            case 2: downloadsContent
                            default: mangaContent
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLogSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.appleBlue)
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                ManualWatchLogView().environmentObject(appState)
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, name in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            selectedTab = index
                        }
                        Haptics.selection()
                    } label: {
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedTab == index ? .white : Theme.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                selectedTab == index ? Theme.appleBlue.opacity(0.22) : Color.white.opacity(0.07),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(
                                    selectedTab == index ? Theme.appleBlue.opacity(0.42) : Color.white.opacity(0.08),
                                    lineWidth: 0.75
                                )
                            )
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Watchlist

    @ViewBuilder
    private var watchlistContent: some View {
        if appState.lensWatchlist.isEmpty {
            emptyState(icon: "plus.rectangle.on.rectangle", title: "Nothing Saved",
                       body: "Save a Lens Pick or tracked title and it appears here.")
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 14)], spacing: 20) {
                ForEach(appState.lensWatchlist) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        PosterImage(url: URL(string: item.artwork ?? ""), cornerRadius: 16)
                            .frame(height: 186)

                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Label(item.kind.title, systemImage: item.kind.symbol)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - History

    @ViewBuilder
    private var historyContent: some View {
        if appState.watchLogs.isEmpty {
            emptyState(icon: "star.bubble", title: "No Watch Logs",
                       body: "Lens Pick can quick-log a title, or tap + to add one manually.")
        } else {
            LazyVStack(spacing: 12) {
                ForEach(appState.watchLogs) { log in
                    LiquidGlass(cornerRadius: 18) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.panel)
                                    .frame(width: 52, height: 68)
                                Image(systemName: log.media.kind.symbol)
                                    .font(.title3)
                                    .foregroundStyle(Theme.appleBlue)
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                Text(log.media.title)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                HStack(spacing: 8) {
                                    MetaBadge(systemImage: "star.fill", text: String(format: "%.1f", log.rating), color: .yellow)
                                    Text(log.mood)
                                        .font(.caption)
                                        .foregroundStyle(Theme.tertiary)
                                        .lineLimit(1)
                                }

                                if !log.reactions.isEmpty {
                                    Text(log.reactions.map(\.title).joined(separator: " · "))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(Theme.appleBlue)
                                }
                            }
                            Spacer()
                        }
                        .padding(14)
                    }
                }
            }
        }
    }

    // MARK: - Downloads

    @ViewBuilder
    private var downloadsContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !appState.continueWatching.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Continue Watching")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    LazyVStack(spacing: 10) {
                        ForEach(appState.continueWatching) { item in
                            NavigationLink {
                                PlayerView(anime: item.anime, episode: item.episode)
                            } label: {
                                LiquidGlass(cornerRadius: 18) {
                                    HStack(spacing: 14) {
                                        PosterImage(url: URL(string: item.image ?? ""), cornerRadius: 10)
                                            .frame(width: 58, height: 58)

                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(item.animeTitle)
                                                .font(.headline.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            Text("Episode \(Int(item.episodeNumber))")
                                                .font(.subheadline)
                                                .foregroundStyle(Theme.secondary)
                                            ProgressView(value: item.progress)
                                                .tint(Theme.appleBlue)
                                        }
                                    }
                                    .padding(14)
                                }
                            }
                            .buttonStyle(PressScaleStyle())
                        }
                    }
                }
            }

            if appState.downloads.isEmpty && appState.continueWatching.isEmpty {
                emptyState(icon: "arrow.down.circle", title: "No Downloads",
                           body: "Queue an anime or episode from the detail page.")
            } else if !appState.downloads.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Download Queue")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    LazyVStack(spacing: 10) {
                        ForEach(appState.downloads) { item in
                            LiquidGlass(cornerRadius: 18) {
                                HStack(spacing: 14) {
                                    PosterImage(url: URL(string: item.image ?? ""), cornerRadius: 10)
                                        .frame(width: 52, height: 52)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.animeTitle)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(item.episodeNumber.map { "Episode \(Int($0))" } ?? "Entire anime")
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.secondary)
                                    }
                                    Spacer()
                                    Text(item.status)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.appleBlue)
                                }
                                .padding(14)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Manga

    private var mangaContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink { MangaView() } label: {
                LiquidGlass(cornerRadius: 22, glow: Theme.appleBlue.opacity(0.10)) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(Theme.appleBlue.opacity(0.18)).frame(width: 52, height: 52)
                            Image(systemName: "books.vertical.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.appleBlue)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Open Manga Tracker")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Browse and read manga from MangaKatana")
                                .font(.callout)
                                .foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.tertiary)
                    }
                    .padding(18)
                }
            }
            .buttonStyle(PressScaleStyle())

            LiquidGlass(cornerRadius: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "link")
                        .foregroundStyle(Theme.tertiary)
                    Text("Anime-to-source sync is stored locally for V1.")
                        .font(.callout)
                        .foregroundStyle(Theme.secondary)
                }
                .padding(16)
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(Theme.tertiary)
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(body)
                    .font(.callout)
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

private extension WatchProgress {
    var anime: Anime {
        Anime(id: animeId, sourceId: sourceId, malId: nil, anidbId: nil,
              title: animeTitle, subtitle: sourceId, cover: image, banner: image,
              year: nil, score: nil, genres: [], status: nil, progress: nil, synopsis: nil)
    }
    var episode: Episode {
        Episode(id: episodeId, animeId: animeId, sourceId: sourceId,
                number: episodeNumber, title: episodeTitle, duration: nil, streamUrl: nil)
    }
}
