import SwiftUI

struct SeasonalCalendarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedYear: Int
    @State private var selectedSeason: String
    @State private var items: [Anime] = []
    @State private var loading = false

    private let jikan = JikanClient()
    private let seasons = ["winter", "spring", "summer", "fall"]
    private let seasonEmoji = ["winter": "❄️", "spring": "🌸", "summer": "☀️", "fall": "🍂"]
    private let currentYear = Calendar.current.component(.year, from: Date())

    private var years: [Int] {
        Array((currentYear - 3...currentYear).reversed())
    }

    init() {
        let month = Calendar.current.component(.month, from: Date())
        let season: String
        switch month {
        case 1...3:  season = "winter"
        case 4...6:  season = "spring"
        case 7...9:  season = "summer"
        default:     season = "fall"
        }
        _selectedSeason = State(initialValue: season)
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }

    var body: some View {
        ZStack {
            PremiumBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    seasonPicker
                        .glassAppear(delay: 0.04)

                    yearPicker
                        .glassAppear(delay: 0.08)

                    if loading {
                        loadingGrid
                    } else if items.isEmpty {
                        emptyState
                    } else {
                        animeGrid
                            .glassAppear(delay: 0.12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Seasonal Calendar")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task { await load() }
        .onChange(of: selectedSeason) { _, _ in Task { await load() } }
        .onChange(of: selectedYear)   { _, _ in Task { await load() } }
    }

    // MARK: - Season Picker

    private var seasonPicker: some View {
        HStack(spacing: 10) {
            ForEach(seasons, id: \.self) { season in
                Button {
                    selectedSeason = season
                    Haptics.selection()
                } label: {
                    VStack(spacing: 5) {
                        Text(seasonEmoji[season] ?? "")
                            .font(.title3)
                        Text(season.capitalized)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(selectedSeason == season ? .white : Theme.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedSeason == season ? Theme.appleBlue.opacity(0.22) : Color.white.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                selectedSeason == season ? Theme.appleBlue.opacity(0.45) : Color.white.opacity(0.09),
                                lineWidth: 0.75
                            )
                    )
                }
                .buttonStyle(PressScaleStyle())
            }
        }
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(years, id: \.self) { year in
                    Button {
                        selectedYear = year
                        Haptics.selection()
                    } label: {
                        Text(String(year))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedYear == year ? .white : Theme.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                selectedYear == year ? Theme.appleBlue.opacity(0.22) : Color.white.opacity(0.07),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(
                                    selectedYear == year ? Theme.appleBlue.opacity(0.42) : Color.white.opacity(0.09),
                                    lineWidth: 0.75
                                )
                            )
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
        }
    }

    // MARK: - Grid

    private var animeGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 140), spacing: 14)],
            spacing: 20
        ) {
            ForEach(items) { anime in
                NavigationLink(value: anime) {
                    AnimePosterCard(anime: anime, width: 140, height: 204)
                }
                .buttonStyle(PressScaleStyle())
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: items.map(\.id))
    }

    private var loadingGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 140), spacing: 14)],
            spacing: 20
        ) {
            ForEach(0..<12, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.panel)
                    .shimmer()
                    .frame(width: 140, height: 204)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Text(seasonEmoji[selectedSeason] ?? "📅")
                .font(.system(size: 52))
            Text("No Results")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text("No anime found for \(selectedSeason.capitalized) \(selectedYear).")
                .font(.callout)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Load

    private func load() async {
        loading = true
        items = []
        let isCurrentSeason = selectedYear == currentYear && isCurrentSeasonSelected
        if isCurrentSeason {
            items = await jikan.nowSeason()
        } else {
            items = await jikan.seasonal(year: selectedYear, season: selectedSeason)
        }
        loading = false
    }

    private var isCurrentSeasonSelected: Bool {
        let month = Calendar.current.component(.month, from: Date())
        switch selectedSeason {
        case "winter": return (1...3).contains(month)
        case "spring": return (4...6).contains(month)
        case "summer": return (7...9).contains(month)
        case "fall":   return (10...12).contains(month)
        default:       return false
        }
    }
}
