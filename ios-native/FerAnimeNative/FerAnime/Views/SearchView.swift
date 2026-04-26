import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var sourceId = "anizone"
    @State private var results: [Anime] = []
    @State private var searching = false

    private let sources = [("anizone", "AniZone"), ("animeheaven", "AnimeHeaven"), ("hianime", "HiAnime"), ("animekai", "AnimeKai")]

    var body: some View {
        NavigationStack {
            ZStack {
                CinematicBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        FrostedHeader(title: "Search", subtitle: sourceId)
                        searchBar
                        sourcePicker
                        chips
                        resultsGrid
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 110)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: query) { _, _ in scheduleSearch() }
            .onChange(of: sourceId) { _, _ in scheduleSearch() }
            .navigationDestination(for: Anime.self) { AnimeDetailView(anime: $0) }
        }
    }

    private var searchBar: some View {
        LiquidGlass(cornerRadius: 24, glow: Theme.cyan.opacity(0.24)) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.secondary)
                TextField("Anime, episode, season", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .padding(18)
        }
    }

    private var sourcePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(sources, id: \.0) { source in
                    Button { sourceId = source.0 } label: {
                        Text(source.1)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(sourceId == source.0 ? .white : Theme.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(sourceId == source.0 ? Theme.panelStrong : Color.white.opacity(0.06), in: Capsule())
                            .overlay(Capsule().stroke(sourceId == source.0 ? Theme.strokeBright : Theme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
        }
    }

    private var chips: some View {
        FlowLayout(spacing: 10) {
            ForEach(["Naruto", "One Piece", "Jujutsu Kaisen", "Solo Leveling", "Bleach", "Demon Slayer"], id: \.self) { item in
                Button { query = item } label: {
                    Text(item)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(PressScaleStyle())
            }
        }
    }

    private var resultsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 20) {
            ForEach(results) { anime in
                NavigationLink(value: anime) {
                    AnimePosterCard(anime: anime, width: 150, height: 226)
                }
                .buttonStyle(PressScaleStyle())
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: results)
    }

    private func scheduleSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        Task {
            searching = true
            results = (try? await appState.client.search(trimmed, sourceId: sourceId)) ?? []
            searching = false
        }
    }
}
