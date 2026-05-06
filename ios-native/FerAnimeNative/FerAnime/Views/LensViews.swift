import SwiftUI

struct LensOnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var index = 0
    @State private var answers: [TasteAxis: [Double]] = [:]

    private var question: TasteQuestion { TasteQuestion.onboarding[index] }

    var body: some View {
        ZStack {
            PremiumBackdrop()
            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 24)

                Text("Lens")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("A streaming companion that learns the shape of your taste.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ProgressView(value: Double(index + 1), total: Double(TasteQuestion.onboarding.count))
                    .tint(Theme.appleBlue)

                LiquidGlass(cornerRadius: 30) {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(question.prompt)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 14) {
                            answerButton(question.left, value: question.leftValue)
                            answerButton(question.right, value: question.rightValue)
                        }
                    }
                    .padding(20)
                }

                Text("No genres. No setup chores. Just the emotional coordinates Lens needs to start feeling personal.")
                    .font(.callout)
                    .foregroundStyle(Theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(22)
        }
    }

    private func answerButton(_ title: String, value: Double) -> some View {
        Button {
            answers[question.axis, default: []].append(value)
            if index < TasteQuestion.onboarding.count - 1 {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    index += 1
                }
            } else {
                appState.completeOnboarding(answers: answers)
            }
        } label: {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.strokeBright, lineWidth: 1)
                }
        }
        .buttonStyle(PressScaleStyle())
    }
}

struct LensPickView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mood = "rainy Sunday"
    @State private var time = "1.5 hrs"
    @State private var company = "Alone"
    @State private var kind: MediaKind = .anime
    @State private var services = ["AniGo"]
    @State private var reshuffles = 0
    @State private var result: LensPickResult?

    private let times = ["45 min", "1.5 hrs", "3+ hrs"]
    private let companies = ["Alone", "With someone"]
    private let serviceOptions = ["AniGo", "AnimeHeaven", "Netflix", "Hulu", "Crunchyroll"]

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        FrostedHeader(title: "Find My Watch", subtitle: "Lens Pick")
                        moodCard
                        pickControls
                        resultCard
                    }
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("Pick")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !appState.preferredServices.isEmpty {
                    services = appState.preferredServices
                }
                makePick(reset: true)
            }
        }
    }

    private var moodCard: some View {
        LiquidGlass(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("What should tonight feel like?")
                    .font(.headline)
                    .foregroundStyle(.white)
                TextField("rainy Sunday, need to cry, turn my brain off", text: $mood)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onSubmit { makePick(reset: true) }
            }
            .padding(18)
        }
        .padding(.horizontal, 18)
    }

    private var pickControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            segmented("Time", values: times, selection: $time)
            segmented("Company", values: companies, selection: $company)
            mediaKindPicker
            servicePicker
        }
        .padding(.horizontal, 18)
    }

    private var mediaKindPicker: some View {
        HStack(spacing: 10) {
            ForEach(MediaKind.allCases) { item in
                Button {
                    kind = item
                    makePick(reset: true)
                } label: {
                    Label(item.title, systemImage: item.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(kind == item ? .white : Theme.secondary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(kind == item ? Theme.panelStrong : Color.white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(PressScaleStyle())
            }
        }
    }

    private var servicePicker: some View {
        FlowLayout(spacing: 10) {
            ForEach(serviceOptions, id: \.self) { service in
                Button {
                    if services.contains(service) {
                        services.removeAll { $0 == service }
                    } else {
                        services.append(service)
                    }
                    appState.preferredServices = services
                    makePick(reset: true)
                } label: {
                    Text(service)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(services.contains(service) ? .white : Theme.secondary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(services.contains(service) ? Theme.panelStrong : Color.white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(PressScaleStyle())
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let result {
                LiquidGlass(cornerRadius: 32, glow: Theme.appleBlue.opacity(0.18)) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label(result.media.kind.title, systemImage: result.media.kind.symbol)
                                .font(.caption.weight(.black))
                                .foregroundStyle(Theme.appleBlue)
                            Spacer()
                            Text("\(Int(result.confidence * 100))% match")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.secondary)
                        }
                        PosterImage(url: URL(string: result.media.artwork ?? ""), cornerRadius: 26)
                            .frame(height: 280)
                        Text(result.media.title)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(result.reason)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Theme.secondary)
                        HStack(spacing: 12) {
                            Button {
                                appState.addToLensWatchlist(result.media)
                            } label: {
                                Label("Save", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                appState.quickLog(media: result.media, rating: 4.0, mood: mood, reaction: .hiddenGem)
                            } label: {
                                Label("Log", systemImage: "star.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                guard reshuffles < 3 else { return }
                                reshuffles += 1
                                makePick(reset: false)
                            } label: {
                                Label("Reshuffle \(3 - reshuffles)", systemImage: "shuffle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(reshuffles >= 3)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .padding(.horizontal, 18)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: result?.id)
    }

    private func segmented(_ title: String, values: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.tertiary)
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Button {
                        selection.wrappedValue = value
                        makePick(reset: true)
                    } label: {
                        Text(value)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(selection.wrappedValue == value ? .white : Theme.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selection.wrappedValue == value ? Theme.panelStrong : Color.white.opacity(0.06),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
        }
    }

    private func makePick(reset: Bool) {
        if reset { reshuffles = 0 }
        let request = LensPickRequest(mood: mood, availableTime: time, company: company, services: services, kind: kind)
        result = appState.lensPick(for: request, reshuffle: reshuffles)
    }
}

struct DiscoverView: View {
    @EnvironmentObject private var appState: AppState
    private let modes = ["Hidden Gem", "Taste Twin Pick", "Director Rabbit Hole", "Mood Match", "Not On My Radar"]

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        FrostedHeader(title: "Discover", subtitle: "Taste routes")

                        NavigationLink {
                            MediaExploreView()
                        } label: {
                            LiquidGlass(cornerRadius: 26) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Movies & TV")
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(.white)
                                        Text("Browse TMDB movies and shows in a separate tracking section.")
                                            .font(.callout)
                                            .foregroundStyle(Theme.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "film.stack.fill")
                                        .font(.title2)
                                        .foregroundStyle(Theme.appleBlue)
                                }
                                .padding(18)
                            }
                        }
                        .buttonStyle(PressScaleStyle())
                        .padding(.horizontal, 18)

                        NavigationLink {
                            SearchView()
                        } label: {
                            LiquidGlass(cornerRadius: 26) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Anime Search")
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(.white)
                                        Text("Search AniGo, AnimeHeaven, AnimeKai, and AniZone.")
                                            .font(.callout)
                                            .foregroundStyle(Theme.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "magnifyingglass")
                                        .font(.title2)
                                        .foregroundStyle(Theme.appleBlue)
                                }
                                .padding(18)
                            }
                        }
                        .buttonStyle(PressScaleStyle())
                        .padding(.horizontal, 18)

                        ForEach(modes, id: \.self) { mode in
                            DiscoveryModeCard(title: mode)
                                .padding(.horizontal, 18)
                        }
                    }
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DiscoveryModeCard: View {
    let title: String

    var body: some View {
        LiquidGlass(cornerRadius: 24) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.appleBlue)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.08), in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private var icon: String {
        switch title {
        case "Hidden Gem": "diamond.fill"
        case "Taste Twin Pick": "person.2.fill"
        case "Director Rabbit Hole": "camera.aperture"
        case "Mood Match": "cloud.moon.fill"
        default: "eye.slash.fill"
        }
    }

    private var subtitle: String {
        switch title {
        case "Hidden Gem": "Low-noise picks that match your fingerprint."
        case "Taste Twin Pick": "A social-ready placeholder for your closest match."
        case "Director Rabbit Hole": "Follow creators and studios across their arc."
        case "Mood Match": "Built from the moods you log over time."
        default: "Titles that have not appeared in your usual feeds."
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        FrostedHeader(title: "Taste Profile", subtitle: "Lens")
                        fingerprintCard
                        statsCard
                        animeToolsCard
                        wrappedCard
                        settingsCard
                    }
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var fingerprintCard: some View {
        LiquidGlass(cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Taste Fingerprint")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                RadarChart(values: appState.tasteFingerprint.axes)
                    .frame(height: 240)
                axisChips(values: appState.tasteFingerprint.axes)
                Text("Anime fingerprint is tracked separately as you log anime watches.")
                    .font(.footnote)
                    .foregroundStyle(Theme.tertiary)
            }
            .padding(18)
        }
        .padding(.horizontal, 18)
    }

    private var statsCard: some View {
        let stats = appState.stats()
        return LiquidGlass(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Viewing Stats")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                HStack {
                    LensMetric(title: "Hours", value: String(format: "%.1f", stats.totalHours))
                    LensMetric(title: "Logs", value: "\(stats.logsCount)")
                    LensMetric(title: "Avg", value: stats.averageRating == 0 ? "--" : String(format: "%.1f", stats.averageRating))
                }
                HStack {
                    LensMetric(title: "Binge", value: "\(Int(stats.bingeRatio * 100))%")
                    LensMetric(title: "Alone", value: "\(Int(stats.aloneRatio * 100))%")
                    LensMetric(title: "Top tag", value: stats.topReaction)
                }
            }
            .padding(18)
        }
        .padding(.horizontal, 18)
    }

    private var animeToolsCard: some View {
        LiquidGlass(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Anime Tools")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                toolRow("Skip filler", "Per-show filler guide placeholder", "forward.end.fill")
                toolRow("Manga sync", "Track where anime meets the source", "books.vertical.fill")
                toolRow("Seasonal calendar", "New episodes grouped by day", "calendar")
                toolRow("Sub/Dub memory", "Saved per show as you choose episodes", "captions.bubble.fill")
            }
            .padding(18)
        }
        .padding(.horizontal, 18)
    }

    private var wrappedCard: some View {
        LiquidGlass(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Lens Wrapped")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("Your recap card will become shareable once you have enough watch logs.")
                    .foregroundStyle(Theme.secondary)
            }
            .padding(18)
        }
        .padding(.horizontal, 18)
    }

    private var settingsCard: some View {
        NavigationLink {
            SettingsView()
        } label: {
            LiquidGlass(cornerRadius: 28) {
                HStack(spacing: 14) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.appleBlue)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.08), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Settings")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Resolver host, notifications, cache, and playback controls.")
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
        .padding(.horizontal, 18)
    }

    private func axisChips(values: [TasteAxis: Double]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(TasteAxis.allCases) { axis in
                Text("\(axis.title) \(Int((values[axis] ?? 0.5) * 100))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
        }
    }

    private func toolRow(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.appleBlue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
        }
    }
}

struct ManualWatchLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var title = ""
    @State private var kind: MediaKind = .anime
    @State private var rating = 4.0
    @State private var mood = "focused"
    @State private var watchedWith = "Alone"
    @State private var watchStyle = "One episode at a time"
    @State private var reaction: ReactionTag = .comfortWatch
    @State private var note = ""
    @State private var finished = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("What did you watch?", text: $title)
                    Picker("Kind", selection: $kind) {
                        ForEach(MediaKind.allCases) { item in
                            Label(item.title, systemImage: item.symbol).tag(item)
                        }
                    }
                }

                Section("Rating") {
                    Stepper(value: $rating, in: 0.5...5.0, step: 0.5) {
                        Text(String(format: "%.1f stars", rating))
                    }
                    Toggle("Finished", isOn: $finished)
                }

                Section("Reaction") {
                    Picker("Reaction", selection: $reaction) {
                        ForEach(ReactionTag.allCases) { tag in
                            Text(tag.title).tag(tag)
                        }
                    }
                    TextField("Mood", text: $mood)
                    TextField("Watched with", text: $watchedWith)
                    Picker("How", selection: $watchStyle) {
                        Text("Binged").tag("Binged")
                        Text("One episode at a time").tag("One episode at a time")
                        Text("Background noise").tag("Background noise")
                    }
                }

                Section("Private Note") {
                    TextField("One line only", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Log Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let media = MediaItem(
            id: "manual-\(kind.rawValue)-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))",
            kind: kind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: "Manual log",
            genres: []
        )
        appState.logWatch(
            WatchLog(
                id: UUID(),
                media: media,
                rating: rating,
                reactions: [reaction],
                watchedWith: watchedWith,
                watchStyle: watchStyle,
                mood: mood,
                note: note,
                finished: finished,
                watchedAt: Date(),
                hours: kind == .anime ? 0.4 : 1.8
            )
        )
        dismiss()
    }
}

struct LensMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.tertiary)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct RadarChart: View {
    let values: [TasteAxis: Double]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size * 0.38
            RadarChartContent(values: values, center: center, radius: radius)
        }
    }
}

private struct RadarChartContent: View {
    let values: [TasteAxis: Double]
    let center: CGPoint
    let radius: CGFloat

    var body: some View {
        ZStack {
            RadarGrid(center: center, radius: radius)
            RadarPolygon(values: values, radius: radius, center: center)
                .fill(Theme.appleBlue.opacity(0.28))
            RadarPolygon(values: values, radius: radius, center: center)
                .stroke(Theme.appleBlue, lineWidth: 2)
            ForEach(Array(TasteAxis.allCases.enumerated()), id: \.element.id) { index, axis in
                RadarAxisLabel(axis: axis, index: index, center: center, radius: radius)
            }
        }
    }
}

private struct RadarGrid: View {
    let center: CGPoint
    let radius: CGFloat

    var body: some View {
        ForEach(1...4, id: \.self) { step in
            RadarLevelPolygon(level: Double(step) / 4.0, radius: radius, center: center)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct RadarAxisLabel: View {
    let axis: TasteAxis
    let index: Int
    let center: CGPoint
    let radius: CGFloat

    var body: some View {
        Text(axis.title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.secondary)
            .position(labelPoint)
    }

    private var labelPoint: CGPoint {
        let count = CGFloat(TasteAxis.allCases.count)
        let angle = (CGFloat(index) / count) * CGFloat.pi * 2 - CGFloat.pi / 2
        return CGPoint(
            x: center.x + cos(angle) * radius * 1.22,
            y: center.y + sin(angle) * radius * 1.22
        )
    }
}

private struct RadarLevelPolygon: Shape {
    let level: Double
    let radius: CGFloat
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        let values = Dictionary(uniqueKeysWithValues: TasteAxis.allCases.map { ($0, level) })
        return RadarPolygon(values: values, radius: radius, center: center).path(in: rect)
    }
}

struct RadarPolygon: Shape {
    let values: [TasteAxis: Double]
    let radius: CGFloat
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let axes = TasteAxis.allCases
        for (index, axis) in axes.enumerated() {
            let angle = (CGFloat(index) / CGFloat(axes.count)) * CGFloat.pi * 2 - CGFloat.pi / 2
            let value = CGFloat(min(max(values[axis] ?? 0.5, 0), 1))
            let point = CGPoint(
                x: center.x + cos(angle) * radius * value,
                y: center.y + sin(angle) * radius * value
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
