import Foundation

struct Anime: Codable, Identifiable, Hashable {
    let id: String
    let sourceId: String?
    let malId: Int?
    let anidbId: String?
    let title: String
    let subtitle: String?
    let cover: String?
    let banner: String?
    let year: Int?
    let score: Double?
    let genres: [String]
    let status: String?
    let progress: String?
    let synopsis: String?

    enum CodingKeys: String, CodingKey {
        case id, sourceId, malId, anidbId, title, subtitle, cover, banner, year, score, genres, status, progress, synopsis
    }

    init(
        id: String,
        sourceId: String?,
        malId: Int?,
        anidbId: String?,
        title: String,
        subtitle: String?,
        cover: String?,
        banner: String?,
        year: Int?,
        score: Double?,
        genres: [String],
        status: String?,
        progress: String?,
        synopsis: String?
    ) {
        self.id = id
        self.sourceId = sourceId
        self.malId = malId
        self.anidbId = anidbId
        self.title = title
        self.subtitle = subtitle
        self.cover = cover
        self.banner = banner
        self.year = year
        self.score = score
        self.genres = genres
        self.status = status
        self.progress = progress
        self.synopsis = synopsis
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sourceId = try container.decodeIfPresent(String.self, forKey: .sourceId)
        malId = try container.decodeIfPresent(Int.self, forKey: .malId)
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: .anidbId) {
            anidbId = stringValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .anidbId) {
            anidbId = String(intValue)
        } else {
            anidbId = nil
        }
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        banner = try container.decodeIfPresent(String.self, forKey: .banner)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        score = try container.decodeIfPresent(Double.self, forKey: .score)
        genres = (try? container.decodeIfPresent([String].self, forKey: .genres)) ?? []
        status = try container.decodeIfPresent(String.self, forKey: .status)
        progress = try container.decodeIfPresent(String.self, forKey: .progress)
        synopsis = try container.decodeIfPresent(String.self, forKey: .synopsis)
    }
}

struct Episode: Codable, Identifiable, Hashable {
    let id: String
    let animeId: String?
    let sourceId: String?
    let number: Double
    let title: String
    let duration: String?
    let streamUrl: String?
}

struct EpisodeStream: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let quality: String
    let type: String
    let url: String
    let headers: [String: String]?

    var isDirect: Bool {
        type.lowercased().contains("hls") ||
        type.lowercased().contains("mp4") ||
        url.lowercased().contains(".m3u8") ||
        url.lowercased().contains(".mp4")
    }

    var isEmbed: Bool {
        !isDirect && (type.lowercased().contains("embed") || url.lowercased().hasPrefix("http"))
    }
}

struct SourceInfo: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let baseUrl: String?
}

struct WatchProgress: Identifiable, Hashable {
    var id: String { episodeId }
    let episodeId: String
    let animeTitle: String
    let episodeTitle: String
    let image: String?
    var progress: Double
}

struct SearchResponse: Codable {
    let items: [Anime]
    let hasNextPage: Bool?
}

struct CatalogResponse: Codable {
    let items: [Anime]
}

struct EpisodesResponse: Codable {
    let items: [Episode]
}

struct StreamsResponse: Codable {
    let items: [EpisodeStream]
    let warning: String?
}

struct SourcesResponse: Codable {
    let sources: [SourceInfo]
}
