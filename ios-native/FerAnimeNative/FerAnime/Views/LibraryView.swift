import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                CinematicBackground()
                VStack(spacing: 18) {
                    LiquidGlass(cornerRadius: 30, glow: Theme.cyan.opacity(0.18)) {
                        VStack(spacing: 12) {
                            Image(systemName: "rectangle.stack.badge.play.fill")
                                .font(.system(size: 46))
                                .foregroundStyle(Theme.aurora)
                            Text("Library")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                            Text("Your native watch history and saved shows will live here.")
                                .font(.callout)
                                .foregroundStyle(Theme.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(28)
                    }
                    .padding(.horizontal, 18)
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationTitle("Library")
        }
    }
}

