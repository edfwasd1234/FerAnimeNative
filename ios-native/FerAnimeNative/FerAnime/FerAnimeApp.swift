import SwiftUI

@main
struct FerAnimeApp: App {
    @StateObject private var appState = AppState()

    init() {
        AudioSession.configureForPlayback()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
