import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "play.tv.fill") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "rectangle.stack.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.appleBlue)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(Theme.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
