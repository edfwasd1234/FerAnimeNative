import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.hasCompletedLensOnboarding {
                mainTabs
            } else {
                LensOnboardingView()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var mainTabs: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            LensPickView()
                .tabItem { Label("Pick", systemImage: "sparkles") }

            DiscoverView()
                .tabItem { Label("Discover", systemImage: "safari.fill") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "rectangle.stack.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .tint(Theme.appleBlue)
    }
}
