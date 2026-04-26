import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var hostDraft = ""
    @State private var autoPlay = true
    @State private var preferDirect = true

    var body: some View {
        NavigationStack {
            ZStack {
                CinematicBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        FrostedHeader(title: "Settings", subtitle: "Native control")
                        resolverSection
                        togglesSection
                        aboutSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 110)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { hostDraft = appState.resolverHost }
        }
    }

    private var resolverSection: some View {
        LiquidGlass(cornerRadius: 28, glow: Theme.cyan.opacity(0.18)) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Resolver", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                TextField("Windows PC IP address", text: $hostDraft)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                LiquidButton(title: "Save Host", systemImage: "checkmark") {
                    appState.resolverHost = hostDraft
                }
            }
            .padding(18)
        }
    }

    private var togglesSection: some View {
        LiquidGlass(cornerRadius: 28, glow: Theme.violet.opacity(0.18)) {
            VStack(spacing: 4) {
                ToggleRow(title: "Prefer HLS / MP4", icon: "play.rectangle.on.rectangle.fill", isOn: $preferDirect)
                Divider().overlay(Color.white.opacity(0.12))
                ToggleRow(title: "Autoplay", icon: "play.circle.fill", isOn: $autoPlay)
            }
            .padding(14)
        }
    }

    private var aboutSection: some View {
        LiquidGlass(cornerRadius: 28, glow: Theme.accent.opacity(0.16)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Native iOS Build")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("SwiftUI, AVPlayer, WebKit fallback, and the local resolver backend.")
                    .font(.callout)
                    .foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
    }
}

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Theme.cyan)
                .frame(width: 26)
            Text(title)
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.accent)
                .onChange(of: isOn) { _, _ in Haptics.impact(.light) }
        }
        .padding(10)
    }
}
