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
    @Published var continueWatching: [WatchProgress] = []

    init() {
        let savedHost = UserDefaults.standard.string(forKey: "resolverHost") ?? "127.0.0.1"
        resolverHost = savedHost
        client = ResolverClient(host: savedHost)
    }
}

