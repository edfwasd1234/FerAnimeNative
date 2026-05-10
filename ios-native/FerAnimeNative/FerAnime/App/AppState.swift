import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var resolverHost: String {
        didSet {
            UserDefaults.standard.set(resolverHost, forKey: "resolverHost")
            client = ResolverClient(host: resolverHost)
        }
    }

    @Published var client: ResolverClient
    @Published var continueWatching: [WatchProgress] = [] {
        didSet { save(continueWatching, key: "continueWatching") }
    }
    @Published var downloads: [DownloadItem] = [] {
        didSet { save(downloads, key: "downloads") }
    }
    @Published var cachedHomeCatalogs: HomeCatalogs? {
        didSet { save(cachedHomeCatalogs, key: "cachedHomeCatalogs") }
    }
    @Published var cachedMangaHome: MangaHomeCache? {
        didSet { save(cachedMangaHome, key: "cachedMangaHome") }
    }
    @Published var cachedAnimeDetails: [String: Anime] = [:] {
        didSet { save(cachedAnimeDetails, key: "cachedAnimeDetails") }
    }
    @Published var cachedEpisodes: [String: [Episode]] = [:] {
        didSet { save(cachedEpisodes, key: "cachedEpisodes") }
    }
    @Published var cachedSourceMatches: [String: [Anime]] = [:] {
        didSet { save(cachedSourceMatches, key: "cachedSourceMatches") }
    }
    @Published var cachedMangaDetails: [String: MangaDetail] = [:] {
        didSet { save(cachedMangaDetails, key: "cachedMangaDetails") }
    }
    // Chapter page data is in-memory only — it can be large and is fast to re-fetch
    @Published var cachedMangaChapters: [String: MangaChapterDetail] = [:]
    @Published var mangaProgress: [String: MangaReadingProgress] = [:] {
        didSet { save(mangaProgress, key: "mangaProgress") }
    }
    @Published var cachedMangaSearches: [String: [MangaItem]] = [:] {
        didSet { save(cachedMangaSearches, key: "cachedMangaSearches") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var hasCompletedLensOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedLensOnboarding, forKey: "hasCompletedLensOnboarding") }
    }
    @Published var tasteFingerprint: TasteFingerprint {
        didSet { save(tasteFingerprint, key: "tasteFingerprint") }
    }
    @Published var watchLogs: [WatchLog] = [] {
        didSet { save(watchLogs, key: "watchLogs") }
    }
    @Published var lensWatchlist: [MediaItem] = [] {
        didSet { save(lensWatchlist, key: "lensWatchlist") }
    }
    @Published var preferredServices: [String] = [] {
        didSet { save(preferredServices, key: "preferredServices") }
    }
    @Published var showLanguagePreferences: [String: String] = [:] {
        didSet { save(showLanguagePreferences, key: "showLanguagePreferences") }
    }

    init() {
        let savedHost = UserDefaults.standard.string(forKey: "resolverHost") ?? "127.0.0.1"
        resolverHost = savedHost
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        hasCompletedLensOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedLensOnboarding")
        client = ResolverClient(host: savedHost)
        continueWatching = Self.loadWatchProgress()
        downloads = Self.loadDownloads()
        cachedHomeCatalogs = Self.loadValue(key: "cachedHomeCatalogs")
        cachedMangaHome = Self.loadValue(key: "cachedMangaHome")
        cachedAnimeDetails = Self.loadValue(key: "cachedAnimeDetails") ?? [:]
        cachedEpisodes = Self.loadValue(key: "cachedEpisodes") ?? [:]
        cachedSourceMatches = Self.loadValue(key: "cachedSourceMatches") ?? [:]
        cachedMangaDetails = Self.loadValue(key: "cachedMangaDetails") ?? [:]
        cachedMangaChapters = [:]
        cachedMangaSearches = Self.loadValue(key: "cachedMangaSearches") ?? [:]
        mangaProgress = Self.loadValue(key: "mangaProgress") ?? [:]
        tasteFingerprint = Self.loadValue(key: "tasteFingerprint") ?? .neutral
        watchLogs = Self.loadArray(key: "watchLogs")
        lensWatchlist = Self.loadArray(key: "lensWatchlist")
        preferredServices = Self.loadArray(key: "preferredServices")
        showLanguagePreferences = Self.loadValue(key: "showLanguagePreferences") ?? [:]
    }

    func updateProgress(anime: Anime, episode: Episode, currentTime: Double, duration: Double) {
        guard currentTime.isFinite, duration.isFinite, duration > 0 else { return }
        let item = WatchProgress(
            episodeId: episode.id,
            animeId: anime.id,
            sourceId: episode.sourceId ?? anime.sourceId ?? "wcotv",
            animeTitle: anime.title,
            episodeTitle: episode.title,
            episodeNumber: episode.number,
            image: anime.cover ?? anime.banner,
            progress: min(max(currentTime / duration, 0), 1),
            duration: duration,
            updatedAt: Date()
        )
        continueWatching.removeAll { $0.episodeId == episode.id }
        continueWatching.insert(item, at: 0)
        continueWatching = Array(continueWatching.prefix(30))
    }

    func queueDownload(anime: Anime, episode: Episode?) {
        let item = DownloadItem(
            id: episode?.id ?? "\(anime.sourceId ?? "source")-\(anime.id)-all",
            animeId: anime.id,
            sourceId: episode?.sourceId ?? anime.sourceId ?? "wcotv",
            animeTitle: anime.title,
            episodeId: episode?.id,
            episodeTitle: episode?.title ?? "Entire anime",
            episodeNumber: episode?.number,
            image: anime.cover ?? anime.banner,
            status: "Queued",
            createdAt: Date()
        )
        downloads.removeAll { $0.id == item.id }
        downloads.insert(item, at: 0)
    }

    func completeOnboarding(answers: [TasteAxis: [Double]]) {
        var profile = TasteFingerprint.neutral
        for axis in TasteAxis.allCases {
            let values = answers[axis] ?? []
            guard !values.isEmpty else { continue }
            profile.axes[axis] = values.reduce(0, +) / Double(values.count)
            profile.animeAxes[axis] = profile.axes[axis]
        }
        tasteFingerprint = profile
        hasCompletedLensOnboarding = true
    }

    func addToLensWatchlist(_ item: MediaItem) {
        lensWatchlist.removeAll { $0.id == item.id && $0.kind == item.kind }
        lensWatchlist.insert(item, at: 0)
        lensWatchlist = Array(lensWatchlist.prefix(100))
    }

    func logWatch(_ log: WatchLog) {
        watchLogs.removeAll { $0.id == log.id }
        watchLogs.insert(log, at: 0)
        watchLogs = Array(watchLogs.prefix(500))
        updateFingerprint(from: log)
    }

    func quickLog(media: MediaItem, rating: Double, mood: String, reaction: ReactionTag, finished: Bool = true) {
        logWatch(
            WatchLog(
                id: UUID(),
                media: media,
                rating: rating,
                reactions: [reaction],
                watchedWith: "Alone",
                watchStyle: "One episode at a time",
                mood: mood,
                note: "",
                finished: finished,
                watchedAt: Date(),
                hours: media.kind == .anime ? 0.4 : 1.8
            )
        )
    }

    func stats() -> ViewingStats {
        guard !watchLogs.isEmpty else { return .empty }
        let totalHours = watchLogs.reduce(0) { $0 + $1.hours }
        let averageRating = watchLogs.reduce(0) { $0 + $1.rating } / Double(watchLogs.count)
        let bingeCount = watchLogs.filter { $0.watchStyle.lowercased().contains("bing") }.count
        let aloneCount = watchLogs.filter { $0.watchedWith.lowercased().contains("alone") }.count
        let reactions = watchLogs.flatMap(\.reactions)
        let topReaction = Dictionary(grouping: reactions, by: { $0 })
            .max { $0.value.count < $1.value.count }?
            .key
            .title ?? "None yet"
        return ViewingStats(
            totalHours: totalHours,
            logsCount: watchLogs.count,
            averageRating: averageRating,
            bingeRatio: Double(bingeCount) / Double(watchLogs.count),
            aloneRatio: Double(aloneCount) / Double(watchLogs.count),
            topReaction: topReaction
        )
    }

    func lensPick(for request: LensPickRequest, reshuffle: Int) -> LensPickResult {
        let pool = lensPickPool(kind: request.kind)
        let scored = pool.map { item in
            (item, score(item: item, request: request, reshuffle: reshuffle))
        }
        let selected = scored.sorted { $0.1 > $1.1 }.first?.0 ?? pool[0]
        return LensPickResult(
            media: selected,
            reason: pickReason(for: selected, request: request),
            confidence: scored.first(where: { $0.0.id == selected.id })?.1 ?? 0.72
        )
    }

    func updateMangaProgress(mangaId: String, mangaTitle: String, image: String?, chapter: MangaChapter, pageIndex: Int, totalPages: Int) {
        mangaProgress[mangaId] = MangaReadingProgress(
            mangaId: mangaId,
            mangaTitle: mangaTitle,
            image: image,
            chapterId: chapter.id,
            chapterName: chapter.name,
            pageIndex: pageIndex,
            totalPages: totalPages,
            updatedAt: Date()
        )
    }

    func setShowLanguagePreference(_ language: String, for animeId: String) {
        showLanguagePreferences[animeId] = language
    }

    func requestNotifications() {
        Task {
            let granted = await NotificationManager.requestAuthorization()
            notificationsEnabled = granted
            if granted {
                NotificationManager.scheduleLibraryReminder()
            }
        }
    }

    func scheduleUpdateNotification(title: String, body: String) {
        guard notificationsEnabled else { return }
        NotificationManager.schedule(title: title, body: body)
    }

    func notifyNewEpisodeIfNeeded(_ anime: Anime?) {
        guard notificationsEnabled, let anime else { return }
        let key = "latestEpisodeNotificationKey"
        let value = anime.id
        guard UserDefaults.standard.string(forKey: key) != value else { return }
        UserDefaults.standard.set(value, forKey: key)
        NotificationManager.schedule(
            title: "New episode row updated",
            body: "\(anime.title) is showing in your latest anime picks.",
            identifier: "latest-episode-\(anime.id)"
        )
    }

    func cacheKey(_ parts: String...) -> String {
        parts.joined(separator: "::")
    }

    private func updateFingerprint(from log: WatchLog) {
        let value = min(max(log.rating / 5.0, 0), 1)
        if log.reactions.contains(.wreckedMe) {
            tasteFingerprint.blend(axis: .emotionalIntensity, value: max(0.72, value), animeOnly: log.media.kind == .anime)
        }
        if log.reactions.contains(.comfortWatch) {
            tasteFingerprint.blend(axis: .comfortChallenge, value: 0.18, animeOnly: log.media.kind == .anime)
        }
        if log.watchStyle.lowercased().contains("bing") {
            tasteFingerprint.blend(axis: .pacing, value: 0.78, animeOnly: log.media.kind == .anime)
        }
        if log.media.kind == .anime {
            tasteFingerprint.blend(axis: .visualStyle, value: value, animeOnly: true)
        }
    }

    private func lensPickPool(kind: MediaKind) -> [MediaItem] {
        let local = (lensWatchlist + watchLogs.map(\.media)).filter { $0.kind == kind }
        if !local.isEmpty { return local }
        return Self.seedMedia.filter { $0.kind == kind }
    }

    private func score(item: MediaItem, request: LensPickRequest, reshuffle: Int) -> Double {
        var score = 0.55
        let mood = request.mood.lowercased()
        if mood.contains("cry") || mood.contains("sad") { score += (tasteFingerprint.axes[.emotionalIntensity] ?? 0.5) * 0.22 }
        if mood.contains("turn") || mood.contains("comfort") { score += (1 - (tasteFingerprint.axes[.narrativeComplexity] ?? 0.5)) * 0.18 }
        if request.availableTime.contains("45") && item.kind == .anime { score += 0.15 }
        if item.genres.contains(where: { mood.contains($0.lowercased()) }) { score += 0.2 }
        score -= Double(reshuffle) * 0.03
        score += Double(abs(item.id.hashValue % 13)) / 100.0
        return min(score, 0.98)
    }

    private func pickReason(for item: MediaItem, request: LensPickRequest) -> String {
        let service = request.services.first ?? "your saved services"
        return "\(item.title) fits \(request.mood.isEmpty ? "your current fingerprint" : request.mood), works for \(request.availableTime), and is available in your \(service) lane."
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadWatchProgress() -> [WatchProgress] {
        loadArray(key: "continueWatching")
    }

    private static func loadDownloads() -> [DownloadItem] {
        loadArray(key: "downloads")
    }

    private static func loadArray<T: Decodable>(key: String) -> [T] {
        loadValue(key: key) ?? []
    }

    private static func loadValue<T: Decodable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: data)
        else {
            return nil
        }
        return value
    }

    private static let seedMedia: [MediaItem] = [
        MediaItem(id: "seed-anime-1", kind: .anime, title: "Frieren: Beyond Journey's End", subtitle: "Reflective fantasy", artwork: nil, year: 2023, genres: ["Fantasy", "Adventure"], synopsis: "A gentle, thoughtful anime pick for quiet nights."),
        MediaItem(id: "seed-anime-2", kind: .anime, title: "Jujutsu Kaisen", subtitle: "High-impact shounen", artwork: nil, year: 2020, genres: ["Action", "Supernatural"], synopsis: "Fast, sharp, and stylish."),
        MediaItem(id: "seed-movie-1", kind: .movie, title: "Arrival", subtitle: "Movie shell", artwork: nil, year: 2016, genres: ["Sci-Fi", "Drama"], synopsis: "Movie tracking is local-only for now."),
        MediaItem(id: "seed-movie-2", kind: .movie, title: "The Grand Budapest Hotel", subtitle: "Movie shell", artwork: nil, year: 2014, genres: ["Comedy", "Drama"], synopsis: "A stylized shell pick for Lens tracking."),
        MediaItem(id: "seed-show-1", kind: .show, title: "Severance", subtitle: "Show shell", artwork: nil, year: 2022, genres: ["Mystery", "Drama"], synopsis: "Shows are tracked locally until TV APIs arrive."),
        MediaItem(id: "seed-show-2", kind: .show, title: "The Bear", subtitle: "Show shell", artwork: nil, year: 2022, genres: ["Drama", "Comedy"], synopsis: "A local Lens recommendation placeholder.")
    ]
}
