import AVKit
import SwiftUI

struct NativeVideoPlayerView: View {
    let stream: EpisodeStream
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Theme.background

            if let player {
                VideoPlayer(player: player)
                    .onDisappear { player.pause() }
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
            player?.play()
        }
    }
}
