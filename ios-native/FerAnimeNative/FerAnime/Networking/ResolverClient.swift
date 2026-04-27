import Foundation

enum ResolverError: LocalizedError {
    case badURL
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .badURL: "The resolver URL is invalid."
        case .badResponse(let status): "Resolver returned HTTP \(status)."
        }
    }
}

final class ResolverClient: ObservableObject {
    let host: String
    let port: Int
    private let resolvedBaseURL: URL?

    init(host: String, port: Int = 4517) {
        let endpoint = ResolverEndpoint(rawValue: host, defaultPort: port)
        self.host = endpoint.host
        self.port = endpoint.port
        self.resolvedBaseURL = endpoint.url
    }

    private var baseURL: URL? { resolvedBaseURL }

    func catalog(section: String, sourceId: String = "anizone") async throws -> [Anime] {
        try await get("/api/anime/catalog", query: ["sourceId": sourceId, "section": section], as: CatalogResponse.self).items
    }

    func search(_ query: String, sourceId: String = "anizone") async throws -> [Anime] {
        try await get("/api/anime/search", query: ["sourceId": sourceId, "q": query], as: SearchResponse.self).items
    }

    func details(sourceId: String, animeId: String) async throws -> Anime {
        try await get("/api/anime/\(sourceId.pathEncoded)/\(animeId.pathEncoded)", as: Anime.self)
    }

    func episodes(sourceId: String, animeId: String) async throws -> [Episode] {
        try await get("/api/anime/\(sourceId.pathEncoded)/\(animeId.pathEncoded)/episodes", as: EpisodesResponse.self).items
    }

    func streams(sourceId: String, episodeId: String) async throws -> [EpisodeStream] {
        try await get("/api/episodes/\(sourceId.pathEncoded)/\(episodeId.pathEncoded)/streams", as: StreamsResponse.self).items
    }

    func sources() async throws -> [SourceInfo] {
        try await get("/api/sources", as: SourcesResponse.self).sources
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:], as type: T.Type) async throws -> T {
        guard let baseURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ResolverError.badURL
        }
        components.percentEncodedPath = path
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else { throw ResolverError.badURL }
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ResolverError.badResponse(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private extension String {
    var pathEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#[]@!$&'()*+,;="))) ?? self
    }
}

private struct ResolverEndpoint {
    let host: String
    let port: Int
    let url: URL?

    init(rawValue: String, defaultPort: Int) {
        let trimmed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let candidate = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        let components = URLComponents(string: candidate)
        let parsedHost = components?.host?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedPort = components?.port

        host = parsedHost?.isEmpty == false ? parsedHost! : trimmed
        port = parsedPort ?? defaultPort

        var normalized = URLComponents()
        normalized.scheme = components?.scheme ?? "http"
        normalized.host = host
        normalized.port = port
        url = normalized.url
    }
}
