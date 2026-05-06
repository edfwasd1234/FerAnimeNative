import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var sourceId = "anizone"
    @State private var results: [Anime] = []
    @State private var searching = false

    private let sources = [
        ("anizone", "AniZone"),
        ("animeheaven", "AnimeHeaven"),
        ("anigo", "AniGo"),
        ("animekai", "AnimeKai")
    ]

    private let quickChips = [
        "Naruto", "One Piece", "Jujutsu Kaisen", "Solo Leveling",
        "Bleach", "Demon Slayer", "Frieren", "Chainsaw Man"
    ]

    var body: some View {
        ZStack {
            PremiumBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    sourcePicker
                        .glassAppear(delay: 0.04)

                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        quickSection
                            .glassAppear(delay: 0.08)
                    }

                    if searching {
                        searchingIndicator
                    } else {
                        resultsGrid
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .searchable(text: $query, prompt: "Anime title, series, season…")
        .onChange(of: query) { _, _ in scheduleSearch() }
        .onChange(of: sourceId) { _, _ in scheduleSearch() }
    }

    // MARK: - Source Picker

    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Source")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.tertiary)
                .padding(.leading, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(sources, id: \.0) { id, name in
                        Button { sourceId = id; Haptics.selection() } label: {
                            Text(name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(sourceId == id ? .white : Theme.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    sourceId == id ? Theme.appleBlue.opacity(0.22) : Color.white.opacity(0.07),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule().stroke(
                                        sourceId == id ? Theme.appleBlue.opacity(0.42) : Color.white.opacity(0.09),
                                        lineWidth: 0.75
                                    )
                                )
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            }
        }
    }

    // MARK: - Quick Chips

    private var quickSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Search")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.tertiary)
                .padding(.leading, 2)

            FlowLayout(spacing: 10) {
                ForEach(quickChips, id: \.self) { chip in
                    Button { query = chip } label: {
                        Text(chip)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.75))
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
        }
    }

    // MARK: - States

    private var searchingIndicator: some View {
        HStack {
            Spacer()
            VStack(spacing: 14) {
                ProgressView().scaleEffect(1.2)
                Text("Searching \(sources.first { $0.0 == sourceId }?.1 ?? sourceId)…")
                    .font(.callout)
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.top, 60)
            Spacer()
        }
    }

    private var resultsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 140), spacing: 14)],
            spacing: 20
        ) {
            ForEach(results) { anime in
                NavigationLink(value: anime) {
                    AnimePosterCard(anime: anime, width: 140, height: 204)
                }
                .buttonStyle(PressScaleStyle())
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: results.map(\.id))
    }

    // MARK: - Search

    private func scheduleSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { results = []; return }
        Task {
            searching = true
            results = (try? await appState.client.search(trimmed, sourceId: sourceId)) ?? []
            searching = false
        }
    }
}
