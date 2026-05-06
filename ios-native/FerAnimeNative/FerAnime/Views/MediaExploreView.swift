import SwiftUI

struct MediaExploreView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedKind: MediaKind = .movie
    @State private var trending: [MediaItem] = []
    @State private var popular: [MediaItem] = []
    @State private var topRated: [MediaItem] = []
    @State private var new: [MediaItem] = []
    @State private var query = ""
    @State private var searchResults: [MediaItem] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        FrostedHeader(title: "Movies & TV", subtitle: "TMDB metadata")
                        kindPicker
                        searchBox
                        if let errorMessage {
                            unavailableCard(errorMessage)
                        }
                        if !searchResults.isEmpty {
                            MediaRail(title: "Search Results", items: searchResults)
                        }
                        MediaRail(title: "Trending", items: trending)
                        MediaRail(title: "Popular", items: popular)
                        MediaRail(title: "Top Rated", items: topRated)
                        MediaRail(title: selectedKind == .movie ? "Now Playing" : "On The Air", items: new)
                    }
                    .padding(.bottom, 96)
                }
                .refreshable { await load(force: true) }
            }
            .navigationTitle("Movies & TV")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MediaItem.self) { item in
                MediaDetailView(item: item)
            }
            .task { await load(force: false) }
            .onChange(of: selectedKind) { _, _ in
                query = ""
                searchResults = []
                Task { await load(force: true) }
            }
        }
    }

    private var kindPicker: some View {
        HStack(spacing: 10) {
            mediaKindButton(.movie)
            mediaKindButton(.show)
        }
        .padding(.horizontal, 18)
    }

    private var searchBox: some View {
        LiquidGlass(cornerRadius: 24) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.appleBlue)
                TextField("Search \(selectedKind == .movie ? "movies" : "TV shows")", text: $query)
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(.white)
                    .onSubmit { Task { await search() } }
                if !query.isEmpty {
                    Button {
                        query = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.secondary)
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 18)
    }

    private func mediaKindButton(_ kind: MediaKind) -> some View {
        Button {
            selectedKind = kind
        } label: {
            Label(kind.title, systemImage: kind.symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(selectedKind == kind ? .white : Theme.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedKind == kind ? Theme.panelStrong : Color.white.opacity(0.06), in: Capsule())
        }
        .buttonStyle(PressScaleStyle())
    }

    private func unavailableCard(_ message: String) -> some View {
        LiquidGlass(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Label("TMDB needs your local key", systemImage: "key.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(Theme.secondary)
            }
            .padding(16)
        }
        .padding(.horizontal, 18)
    }

    private func load(force: Bool) async {
        guard force || trending.isEmpty || popular.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let trendingLoad = appState.client.mediaCatalog(kind: selectedKind, section: "trending")
            async let popularLoad = appState.client.mediaCatalog(kind: selectedKind, section: "popular")
            async let topLoad = appState.client.mediaCatalog(kind: selectedKind, section: "top_rated")
            async let newLoad = appState.client.mediaCatalog(kind: selectedKind, section: "new")
            trending = try await trendingLoad
            popular = try await popularLoad
            topRated = try await topLoad
            new = try await newLoad
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        do {
            searchResults = try await appState.client.mediaSearch(trimmed, kind: selectedKind)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MediaRail: View {
    let title: String
    let items: [MediaItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                MediaPosterCard(item: item)
                            }
                            .buttonStyle(PressScaleStyle())
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }
}

struct MediaPosterCard: View {
    let item: MediaItem
    var width: CGFloat = 132
    var height: CGFloat = 196

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PosterImage(url: URL(string: item.artwork ?? item.banner ?? ""), cornerRadius: 20)
                .frame(width: width, height: height)
            HStack(spacing: 6) {
                Image(systemName: item.kind.symbol)
                Text(item.year.map(String.init) ?? item.kind.title)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.tertiary)
            Text(item.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)
        }
    }
}

struct MediaDetailView: View {
    @EnvironmentObject private var appState: AppState
    let item: MediaItem
    @State private var details: MediaItem?
    @State private var errorMessage: String?

    private var display: MediaItem { details ?? item }

    var body: some View {
        ZStack {
            PremiumBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    synopsis
                    if let seasons = display.seasons, !seasons.isEmpty {
                        seasonsSection(seasons)
                    }
                    if let cast = display.cast, !cast.isEmpty {
                        castSection(cast)
                    }
                    if let similar = display.similar, !similar.isEmpty {
                        MediaRail(title: "Similar", items: similar)
                    }
                }
                .padding(.bottom, 92)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetails() }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            PosterImage(url: URL(string: display.banner ?? display.artwork ?? ""), cornerRadius: 0)
                .frame(height: 360)
                .overlay { Rectangle().fill(.black.opacity(0.30)) }
            VStack(alignment: .leading, spacing: 12) {
                Label(display.kind.title, systemImage: display.kind.symbol)
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.appleBlue)
                Text(display.title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 10) {
                    if let score = display.score {
                        Label(String(format: "%.1f", score), systemImage: "star.fill")
                    }
                    if let year = display.year {
                        Text(String(year))
                    }
                    if let status = display.status {
                        Text(status)
                    }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
                HStack(spacing: 10) {
                    Button {
                        appState.addToLensWatchlist(display)
                    } label: {
                        Label("Save", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        appState.quickLog(media: display, rating: 4.0, mood: "tracked from TMDB", reaction: .hiddenGem)
                    } label: {
                        Label("Log", systemImage: "star.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(18)
        }
    }

    private var synopsis: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text(display.synopsis?.isEmpty == false ? display.synopsis! : "No overview available yet.")
                .font(.callout)
                .foregroundStyle(Theme.secondary)
                .lineSpacing(4)
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .padding(.horizontal, 18)
    }

    private func seasonsSection(_ seasons: [MediaSeason]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Seasons")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
            ForEach(seasons) { season in
                LiquidGlass(cornerRadius: 20) {
                    HStack(spacing: 12) {
                        PosterImage(url: URL(string: season.artwork ?? ""), cornerRadius: 14)
                            .frame(width: 54, height: 76)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(season.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("\(season.episodes ?? 0) episodes")
                                .font(.caption)
                                .foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private func castSection(_ cast: [MediaCastMember]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cast")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cast) { person in
                        VStack(alignment: .leading, spacing: 8) {
                            PosterImage(url: URL(string: person.image ?? ""), cornerRadius: 18)
                                .frame(width: 92, height: 112)
                            Text(person.name)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(person.role)
                                .font(.caption2)
                                .foregroundStyle(Theme.tertiary)
                                .lineLimit(1)
                        }
                        .frame(width: 92, alignment: .leading)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private func loadDetails() async {
        do {
            details = try await appState.client.mediaDetails(kind: item.kind, id: item.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
