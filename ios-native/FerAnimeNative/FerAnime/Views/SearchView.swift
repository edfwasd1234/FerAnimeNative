import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var results: [Anime] = []
    @State private var searching = false

    private let quickChips = [
        "Naruto", "One Piece", "Jujutsu Kaisen", "Solo Leveling",
        "Bleach", "Demon Slayer", "Frieren", "Chainsaw Man"
    ]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
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
            .navigationDestination(for: Anime.self) { AnimeDetailView(anime: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 36, height: 36)
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
                Text("Searching…")
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
            results = (try? await appState.client.search(trimmed, sourceId: "wcotv")) ?? []
            searching = false
        }
    }
}
