import Foundation

struct MangaItem: Codable, Identifiable, Hashable {
    let id: String
    let image: String?
    let title: String
    let chapter: String?
    let view: String?
    let description: String?

    var detailId: String {
        if let range = id.range(of: "manga-") {
            return String(id[range.lowerBound...])
        }
        return id
    }
}

struct MangaListResponse: Codable {
    let mangaList: [MangaItem]
    let metaData: MangaMetaData?
}

struct MangaMetaData: Codable, Hashable {
    let totalStories: Int?
    let totalPages: Int?
    let type: [MangaFilter]?
    let state: [MangaFilter]?
    let category: [MangaFilter]?
}

struct MangaFilter: Codable, Hashable {
    let id: String
    let type: String
}

struct MangaDetail: Codable, Hashable {
    let imageUrl: String?
    let name: String
    let author: String?
    let status: String?
    let updated: String?
    let view: String?
    let genres: [String]
    let chapterList: [MangaChapter]

    enum CodingKeys: String, CodingKey {
        case imageUrl, name, author, status, updated, view, genres, chapterList
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        name = try container.decode(String.self, forKey: .name)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        updated = try container.decodeIfPresent(String.self, forKey: .updated)
        view = try container.decodeIfPresent(String.self, forKey: .view)
        genres = (try? container.decodeIfPresent([String].self, forKey: .genres)) ?? []
        chapterList = (try? container.decodeIfPresent([MangaChapter].self, forKey: .chapterList)) ?? []
    }
}

struct MangaChapter: Codable, Identifiable, Hashable {
    let id: String
    let path: String?
    let name: String
    let view: String?
    let createdAt: String?
}

struct MangaChapterDetail: Codable, Hashable {
    let title: String
    let currentChapter: String
    let chapterListIds: [MangaChapterLink]
    let images: [MangaPage]

    enum CodingKeys: String, CodingKey {
        case title, currentChapter, chapterListIds, images
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        currentChapter = (try? container.decode(String.self, forKey: .currentChapter)) ?? ""
        chapterListIds = (try? container.decodeIfPresent([MangaChapterLink].self, forKey: .chapterListIds)) ?? []
        images = (try? container.decodeIfPresent([MangaPage].self, forKey: .images)) ?? []
    }
}

struct MangaChapterLink: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct MangaPage: Codable, Identifiable, Hashable {
    var id: String { image }
    let title: String?
    let image: String
}
