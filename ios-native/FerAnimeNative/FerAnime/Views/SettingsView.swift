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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        FrostedHeader(title: "Settings", subtitle: "iPhone")
                            .glassAppear()
                        resolverSection
                            .glassAppear(delay: 0.05)
                        togglesSection
                            .glassAppear(delay: 0.10)
                        aboutSection
                            .glassAppear(delay: 0.15)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 92)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { hostDraft = appState.resolverHost }
        }
    }

    private var resolverSection: some View {
        LiquidGlass(cornerRadius: 24, glow: Theme.appleBlue.opacity(0.14)) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Resolver", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                TextField("Windows PC IP address", text: $hostDraft)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }

                Button {
                    appState.resolverHost = hostDraft
                    Haptics.impact(.medium)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                        Text("Save Host")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Theme.appleBlue.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(16)
        }
    }

    private var togglesSection: some View {
        LiquidGlass(cornerRadius: 24, glow: Theme.violet.opacity(0.12)) {
            VStack(spacing: 4) {
                ToggleRow(title: "Prefer HLS / MP4", icon: "play.rectangle.on.rectangle.fill", isOn: $preferDirect)
                Divider().overlay(Color.white.opacity(0.12))
                ToggleRow(title: "Autoplay", icon: "play.circle.fill", isOn: $autoPlay)
            }
            .padding(14)
        }
    }

    private var aboutSection: some View {
        LiquidGlass(cornerRadius: 24, glow: Theme.cyan.opacity(0.10)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Native iOS Build")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("SwiftUI, AVPlayer, WebKit fallback, and the local resolver backend.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
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
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.accent)
                .onChange(of: isOn) { _, _ in Haptics.impact(.light) }
        }
        .frame(height: 52)
        .padding(.horizontal, 4)
    }
}
