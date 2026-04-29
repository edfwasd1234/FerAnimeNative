import AVFoundation
import SwiftUI
import UIKit

struct NativeVideoPlayerView: View {
    let stream: EpisodeStream
    var onProgress: (Double, Double) -> Void = { _, _ in }

    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var isPlaying = true
    @State private var showControls = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeeking = false

    var body: some View {
        ZStack {
            Theme.background

            if let player {
                PlayerLayerView(player: player)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            showControls.toggle()
                        }
                        scheduleAutoHide()
                    }

                if showControls {
                    controls(player: player)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: stream.url) {
            setupPlayer()
        }
        .onDisappear {
            tearDownPlayer()
        }
    }

    private func controls(player: AVPlayer) -> some View {
        VStack {
            HStack {
                Label(stream.quality, systemImage: stream.type.lowercased().contains("hls") ? "dot.radiowaves.left.and.right" : "film.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            Spacer()

            Button {
                togglePlayback(player)
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(PressScaleStyle())

            Spacer()

            VStack(spacing: 14) {
                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: { value in
                            isSeeking = true
                            currentTime = value
                        }
                    ),
                    in: 0...max(duration, 1),
                    onEditingChanged: { editing in
                        if !editing {
                            player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                            isSeeking = false
                            scheduleAutoHide()
                        }
                    }
                )
                .tint(Theme.appleBlue)

                HStack {
                    Text(formatTime(currentTime))
                    Spacer()
                    HStack(spacing: 18) {
                        Button { skip(player, seconds: -10) } label: {
                            Image(systemName: "gobackward.10")
                        }
                        Button { togglePlayback(player) } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        }
                        Button { skip(player, seconds: 10) } label: {
                            Image(systemName: "goforward.10")
                        }
                    }
                    .font(.title3.weight(.semibold))
                    Spacer()
                    Text(formatTime(duration))
                }
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .foregroundStyle(.white)
    }

    private func setupPlayer() {
        guard let url = URL(string: stream.url) else { return }
        tearDownPlayer()
        AudioSession.configureForPlayback()
        let options = stream.headers.map { ["AVURLAssetHTTPHeaderFieldsKey": $0] as [String: Any] }
        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.isMuted = false
        player.volume = 1.0
        self.player = player
        isPlaying = true

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { time in
            guard !isSeeking else { return }
            currentTime = max(time.seconds, 0)
            let itemDuration = player.currentItem?.duration.seconds ?? 0
            duration = itemDuration.isFinite ? itemDuration : 0
            onProgress(currentTime, duration)
        }
        player.play()
        scheduleAutoHide()
    }

    private func tearDownPlayer() {
        player?.pause()
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
    }

    private func togglePlayback(_ player: AVPlayer) {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        Haptics.impact(.medium)
        scheduleAutoHide()
    }

    private func skip(_ player: AVPlayer, seconds: Double) {
        let target = min(max(currentTime + seconds, 0), max(duration, 0))
        currentTime = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        Haptics.impact(.light)
        scheduleAutoHide()
    }

    private func scheduleAutoHide() {
        guard isPlaying else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                guard isPlaying else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    showControls = false
                }
            }
        }
    }

    private func formatTime(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "0:00" }
        let total = Int(value)
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerContainerView, context: Context) {
        view.playerLayer.player = player
    }
}

private final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
