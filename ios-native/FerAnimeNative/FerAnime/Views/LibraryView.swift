import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                CinematicBackground()
                VStack(spacing: 18) {
                    FrostedHeader(title: "Library", subtitle: "Saved shows")
                        .glassAppear()
                    LiquidGlass(cornerRadius: 24, glow: Theme.appleBlue.opacity(0.12)) {
                        VStack(spacing: 12) {
                            Image(systemName: "rectangle.stack.badge.play.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(Theme.appleBlue)
                            Text("Library")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Your native watch history and saved shows will live here.")
                                .font(.footnote)
                                .foregroundStyle(Theme.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(22)
                    }
                    .padding(.horizontal, 16)
                    .glassAppear(delay: 0.06)
                    Spacer()
                }
                .padding(.top, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
