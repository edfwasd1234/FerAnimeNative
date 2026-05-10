import AVFoundation
import AVKit
import SwiftUI

struct NativeVideoPlayerView: UIViewControllerRepresentable {
    let stream: EpisodeStream
    var onProgress: (Double, Double) -> Void = { _, _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onProgress: onProgress)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.allowsPictureInPicturePlayback = true
        vc.showsPlaybackControls = true
        context.coordinator.attach(to: vc, stream: stream)
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if context.coordinator.currentURL != stream.url {
            context.coordinator.attach(to: vc, stream: stream)
        }
    }

    final class Coordinator {
        let onProgress: (Double, Double) -> Void
        var currentURL: String?
        private var player: AVPlayer?
        private var timeObserver: Any?

        init(onProgress: @escaping (Double, Double) -> Void) {
            self.onProgress = onProgress
        }

        func attach(to vc: AVPlayerViewController, stream: EpisodeStream) {
            tearDown()
            currentURL = stream.url
            guard let url = URL(string: stream.url) else { return }

            AudioSession.configureForPlayback()

            var assetOptions: [String: Any] = [:]
            if let headers = stream.headers, !headers.isEmpty {
                assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = headers
            }
            let asset = AVURLAsset(url: url, options: assetOptions)
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            self.player = player

            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 1, preferredTimescale: 600),
                queue: .main
            ) { [weak self, weak player] time in
                let d = player?.currentItem?.duration.seconds ?? 0
                self?.onProgress(max(time.seconds, 0), d.isFinite ? d : 0)
            }

            vc.player = player
            player.play()
        }

        func tearDown() {
            if let obs = timeObserver { player?.removeTimeObserver(obs) }
            player?.pause()
            player = nil
            timeObserver = nil
        }

        deinit { tearDown() }
    }
}
