import Foundation

struct MangaKatanaClient {
    private let baseURL: URL
    private let decoder = JSONDecoder()

    init(resolverBaseURL: URL?) {
        self.baseURL = resolverBaseURL?.appendingPathComponent("api") ?? URL(string: "http://127.0.0.1:4517/api")!
    }

    func list(page: Int = 1, type: String = "topview", category: String = "all", state: String = "all") async throws -> MangaListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("mangaList"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "category", value: category),
            URLQueryItem(name: "state", value: state)
        ]
        return try await request(components.url!)
    }

    func search(_ query: String, page: Int = 1) async throws -> MangaListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("search").appendingPathComponent(query), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "page", value: String(page))]
        return try await request(components.url!)
    }

    func detail(id: String) async throws -> MangaDetail {
        try await request(baseURL.appendingPathComponent("manga").appendingPathComponent(id))
    }

    func chapter(mangaId: String, chapterId: String) async throws -> MangaChapterDetail {
        try await request(baseURL.appendingPathComponent("manga").appendingPathComponent(mangaId).appendingPathComponent(chapterId))
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(T.self, from: data)
    }
}
