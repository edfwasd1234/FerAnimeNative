import Foundation

final class JikanClient {
    private let baseURL = URL(string: "https://api.jikan.moe/v4")!

    func homeCatalogs() async -> HomeCatalogs {
        async let recommended = top(filter: "favorite", title: "Most Loved")
        async let trending = top(filter: "airing", title: "Trending")
        async let new = currentSeason()
        async let action = top(genres: "1", title: "Action")

        return await HomeCatalogs(
            recommended: recommended,
            trending: trending,
            new: new,
            action: action
        )
    }

    private func top(filter: String? = nil, genres: String? = nil, title: String) async -> [Anime] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "type", value: "tv"),
            URLQueryItem(name: "sfw", value: "true"),
            URLQueryItem(name: "limit", value: "15")
        ]
        if let filter { query.append(URLQueryItem(name: "filter", value: filter)) }
        if let genres { query.append(URLQueryItem(name: "genres", value: genres)) }

        return (try? await request(path: "/top/anime", query: query)) ?? []
    }

    private func currentSeason() async -> [Anime] {
        let query = [
            URLQueryItem(name: "sfw", value: "true"),
            URLQueryItem(name: "limit", value: "15")
        ]
        return (try? await request(path: "/seasons/now", query: query)) ?? []
    }

    private func request(path: String, query: [URLQueryItem]) async throws -> [Anime] {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        var request = URLRequest(url: components.url!, timeoutInterval: 25)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ResolverError.badResponse(http.statusCode)
        }
        return try JSONDecoder().decode(JikanAnimeResponse.self, from: data).data.map(\.anime)
    }
}

struct HomeCatalogs: Codable {
    let recommended: [Anime]
    let trending: [Anime]
    let new: [Anime]
    let action: [Anime]
}

private struct JikanAnimeResponse: Decodable {
    let data: [JikanAnime]
}

private struct JikanAnime: Decodable {
    let malId: Int
    let title: String
    let titleEnglish: String?
    let synopsis: String?
    let year: Int?
    let score: Double?
    let status: String?
    let episodes: Int?
    let images: JikanImages
    let trailer: JikanTrailer?
    let genres: [JikanNamedValue]

    enum CodingKeys: String, CodingKey {
        case malId = "mal_id"
        case title
        case titleEnglish = "title_english"
        case synopsis
        case year
        case score
        case status
        case episodes
        case images
        case trailer
        case genres
    }

    var anime: Anime {
        Anime(
            id: String(malId),
            sourceId: "jikan",
            malId: malId,
            anidbId: nil,
            title: titleEnglish ?? title,
            subtitle: "Jikan",
            cover: images.jpg.largeImageUrl ?? images.webp.largeImageUrl ?? images.jpg.imageUrl,
            banner: trailer?.images?.maximumImageUrl ?? images.jpg.largeImageUrl ?? images.webp.largeImageUrl,
            year: year,
            score: score,
            genres: genres.map(\.name),
            status: status,
            progress: episodes.map { "0 / \($0)" },
            synopsis: synopsis
        )
    }
}

private struct JikanImages: Decodable {
    let jpg: JikanImageSet
    let webp: JikanImageSet
}

private struct JikanImageSet: Decodable {
    let imageUrl: String?
    let largeImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case imageUrl = "image_url"
        case largeImageUrl = "large_image_url"
    }
}

private struct JikanTrailer: Decodable {
    let images: JikanTrailerImages?
}

private struct JikanTrailerImages: Decodable {
    let maximumImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case maximumImageUrl = "maximum_image_url"
    }
}

private struct JikanNamedValue: Decodable {
    let name: String
}
