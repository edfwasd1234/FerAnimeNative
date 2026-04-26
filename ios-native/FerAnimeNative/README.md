# FerAnime Native iOS

This folder is the SwiftUI rewrite of the app. It is a real native iOS app:

- SwiftUI screens and navigation
- Liquid glass visual system using iOS materials
- AVPlayer playback for HLS and MP4 streams
- WKWebView embed fallback with WebKit content rules
- Resolver API client for AnimeHeaven, HiAnime, AniZone, and AnimeKai
- Source fallback order: AniZone direct stream, AnimeHeaven embed/direct, HiAnime embed/direct

The existing Node resolver is still required:

```powershell
npm.cmd run resolver
```

On an iPhone, `127.0.0.1` points to the phone, not your PC. In the app Settings screen, set the resolver host to your Windows PC LAN IP, for example:

```text
192.168.1.202
```

Windows cannot compile or sign iOS apps locally. Move `ios-native/FerAnimeNative` to a Mac or cloud Mac, then generate/open the Xcode project:

```bash
brew install xcodegen
xcodegen generate
open FerAnimeNative.xcodeproj
```

Then choose your iPhone as the run target and press Run.
