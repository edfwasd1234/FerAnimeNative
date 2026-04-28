import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "play.tv.fill") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            MangaView()
                .tabItem { Label("Manga", systemImage: "books.vertical.fill") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "rectangle.stack.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.appleBlue)
    }
}
