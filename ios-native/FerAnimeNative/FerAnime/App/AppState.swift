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
    @Published var cachedMangaChapters: [String: MangaChapterDetail] = [:] {
        didSet { save(cachedMangaChapters, key: "cachedMangaChapters") }
    }
    @Published var cachedMangaSearches: [String: [MangaItem]] = [:] {
        didSet { save(cachedMangaSearches, key: "cachedMangaSearches") }
    }

    init() {
        let savedHost = UserDefaults.standard.string(forKey: "resolverHost") ?? "127.0.0.1"
        resolverHost = savedHost
        client = ResolverClient(host: savedHost)
        continueWatching = Self.loadWatchProgress()
        downloads = Self.loadDownloads()
        cachedHomeCatalogs = Self.loadValue(key: "cachedHomeCatalogs")
        cachedMangaHome = Self.loadValue(key: "cachedMangaHome")
        cachedAnimeDetails = Self.loadValue(key: "cachedAnimeDetails") ?? [:]
        cachedEpisodes = Self.loadValue(key: "cachedEpisodes") ?? [:]
        cachedSourceMatches = Self.loadValue(key: "cachedSourceMatches") ?? [:]
        cachedMangaDetails = Self.loadValue(key: "cachedMangaDetails") ?? [:]
        cachedMangaChapters = Self.loadValue(key: "cachedMangaChapters") ?? [:]
        cachedMangaSearches = Self.loadValue(key: "cachedMangaSearches") ?? [:]
    }

    func updateProgress(anime: Anime, episode: Episode, currentTime: Double, duration: Double) {
        guard currentTime.isFinite, duration.isFinite, duration > 0 else { return }
        let item = WatchProgress(
            episodeId: episode.id,
            animeId: anime.id,
            sourceId: episode.sourceId ?? anime.sourceId ?? "anizone",
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
            sourceId: episode?.sourceId ?? anime.sourceId ?? "anizone",
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

    func cacheKey(_ parts: String...) -> String {
        parts.joined(separator: "::")
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
}
