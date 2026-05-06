import Foundation

struct MediaCatalogResponse: Codable {
    let kind: MediaKind
    let section: String?
    let items: [MediaItem]
    let page: Int?
    let totalPages: Int?
}

struct MediaSearchResponse: Codable {
    let kind: MediaKind
    let items: [MediaItem]
    let page: Int?
    let totalPages: Int?
}

struct MediaSeason: Codable, Identifiable, Hashable {
    let id: String
    let number: Int?
    let title: String
    let episodes: Int?
    let artwork: String?
    let year: Int?
}

struct MediaCastMember: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let image: String?
}
