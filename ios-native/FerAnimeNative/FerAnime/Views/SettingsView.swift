import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var hostDraft = ""
    @State private var autoPlay = true
    @State private var preferDirect = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Windows PC IP address", text: $hostDraft)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        appState.resolverHost = hostDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        Haptics.impact(.medium)
                    } label: {
                        Label("Save Host", systemImage: "checkmark")
                    }
                } header: {
                    Text("Resolver")
                } footer: {
                    Text("Accepted formats: 192.168.1.209, 192.168.1.209:4517, or http://192.168.1.209:4517.")
                }

                Section("Playback") {
                    ToggleRow(title: "Prefer HLS / MP4", icon: "play.rectangle.on.rectangle.fill", isOn: $preferDirect)
                    ToggleRow(title: "Autoplay", icon: "play.circle.fill", isOn: $autoPlay)
                }

                Section("Notifications") {
                    HStack(spacing: 14) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(Theme.appleBlue)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Library Updates")
                                .font(.body.weight(.medium))
                            Text(appState.notificationsEnabled ? "Enabled" : "Ask before sending alerts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(appState.notificationsEnabled ? "On" : "Enable") {
                            appState.requestNotifications()
                            Haptics.impact(.medium)
                        }
                        .buttonStyle(.bordered)
                        .disabled(appState.notificationsEnabled)
                    }
                    .frame(minHeight: 56)
                }

                Section("About") {
                    LabeledContent("Build", value: "Native iOS")
                    LabeledContent("Playback", value: "AVPlayer + WebKit")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(PremiumBackdrop())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { hostDraft = appState.resolverHost }
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
                .foregroundStyle(Theme.appleBlue)
                .frame(width: 26)
            Text(title)
                .font(.body.weight(.medium))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.appleBlue)
                .onChange(of: isOn) { _, _ in Haptics.impact(.light) }
        }
        .frame(height: 52)
        .padding(.horizontal, 4)
    }
}
