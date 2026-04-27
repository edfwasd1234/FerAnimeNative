import AVKit
import SwiftUI

struct NativeVideoPlayerView: View {
    let stream: EpisodeStream
    var onProgress: (Double, Double) -> Void = { _, _ in }
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?

    var body: some View {
        ZStack {
            Theme.background

            if let player {
                VideoPlayer(player: player)
                    .onDisappear {
                        player.pause()
                        if let timeObserver {
                            player.removeTimeObserver(timeObserver)
                            self.timeObserver = nil
                        }
                    }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: stream.url) {
            guard let url = URL(string: stream.url) else { return }
            AudioSession.configureForPlayback()
            let options = stream.headers.map { ["AVURLAssetHTTPHeaderFieldsKey": $0] as [String: Any] }
            let asset = AVURLAsset(url: url, options: options)
            player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            player?.isMuted = false
            player?.volume = 1.0
            timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 600), queue: .main) { time in
                let duration = player?.currentItem?.duration.seconds ?? 0
                onProgress(time.seconds, duration)
            }
            player?.play()
        }
    }
}
