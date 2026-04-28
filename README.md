# FerAnimeNative

FerAnimeNative is a personal-use native iOS anime watching app built with SwiftUI. It pairs a clean Apple-style iPhone interface with a Node resolver backend for source lookup, episode discovery, and stream resolution.

The project currently includes two app layers:

- `ios-native/FerAnimeNative`: the native SwiftUI iOS app.
- `backend`: the Node resolver used by the iOS app.

The older Expo prototype is still in the repository for reference, but active development is focused on the native iOS app.

## Features

- Native SwiftUI app shell with Apple system navigation, `TabView`, `NavigationStack`, `Form`, `List`, and `.searchable`.
- Real anime metadata on the home screen through Jikan.
- Jikan-to-streaming source matching on anime detail pages.
- Source matching across AniZone, AnimeHeaven, HiAnime, and AnimeKai resolver modules.
- Native `AVPlayer` playback for HLS and MP4 streams.
- `WKWebView` embed fallback when a source only exposes an embed.
- Native audio session setup for video playback.
- Continue Watching progress saved locally.
- Library screen with watch history and download queue.
- Download queue controls for a full anime or individual episodes.
- GitHub Actions workflow that builds an unsigned iOS IPA artifact.
- Build-time verification that the final app bundle contains the launch-screen metadata needed for full-screen iPhone display.

## Current Limitations

- The IPA produced by GitHub Actions is unsigned. You must sign it before installing it on an iPhone.
- Real Apple Liquid Glass depends on building with an Apple SDK that supports it. This app uses system SwiftUI controls so Apple owns the tab bar, navigation, buttons, forms, and search surfaces.
- Offline downloads are currently a queue/status feature, not full file downloading yet.
- The resolver backend must be running on your computer or server while using the app.
- Some sources may return embeds instead of direct HLS/MP4 streams.

## Repository Layout

```text
.
|-- backend/                         # Node resolver server and source modules
|-- extensions/                      # Extension experiments
|-- ios-native/FerAnimeNative/       # Native SwiftUI iOS app
|-- .github/workflows/               # GitHub Actions iOS build workflow
|-- app/, src/                       # Expo prototype/reference implementation
`-- package.json                     # Resolver scripts and Expo prototype dependencies
```

## Running the Resolver Backend

Install dependencies:

```powershell
npm.cmd install
```

Start the resolver:

```powershell
npm.cmd run resolver
```

Check health:

```text
http://127.0.0.1:4517/health
```

Expected response:

```json
{
  "ok": true,
  "service": "feranime-resolver",
  "sources": ["animeheaven", "hianime", "animekai", "anizone"]
}
```

## Deploy the Resolver Backend

You can run the resolver on your PC, or host it so your iPhone can reach it through a public HTTPS URL. After deploying, put the deployed URL into the app Settings screen.

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/edfwasd1234/FerAnimeNative)
[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fedfwasd1234%2FFerAnimeNative)
[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/edfwasd1234/FerAnimeNative)
[![Deploy on Railway](https://img.shields.io/badge/Deploy%20on-Railway-7B61FF?style=for-the-badge&logo=railway&logoColor=white)](https://railway.com/new)

Supported hosting files:

- `render.yaml` for Render Blueprint deploys.
- `railway.json` for Railway Nixpacks deploy settings.
- `Procfile` and top-level Heroku metadata in `app.json`.
- `vercel.json` and `api/index.js` for Vercel serverless routing.

Default start command:

```text
npm run resolver
```

Health check path:

```text
/health
```

Hosted URL examples:

```text
https://feranime-resolver.onrender.com
https://your-project.up.railway.app
https://your-project.vercel.app
```

Notes:

- Render, Railway, and Heroku run the backend as a normal Node web service.
- Vercel is serverless, so it uses `api/index.js` to route requests into the resolver.
- Free tiers may sleep after inactivity, so the first request can be slow.
- Some streaming sources may block datacenter IP addresses. If that happens, run the resolver locally on your Windows PC instead.
- Keep hosted resolver URLs private for personal use.

## iPhone Resolver Host

On your Windows PC, `127.0.0.1` means the PC. On your iPhone, `127.0.0.1` means the iPhone.

Use your PC LAN IP in the iOS app Settings screen.

Example:

```text
192.168.1.209
```

Full backend URL:

```text
http://192.168.1.209:4517
```

If you deploy the resolver, use the HTTPS URL instead:

```text
https://your-resolver-host.example.com
```

Your iPhone and PC must be on the same Wi-Fi network for local hosting, and Windows Firewall must allow the resolver port if needed.

## Building the Native iOS App

Windows cannot compile or sign native iOS apps locally. Use one of these options:

- A Mac with Xcode.
- A cloud Mac.
- GitHub Actions for unsigned build artifacts.

### Build on macOS

From `ios-native/FerAnimeNative`:

```bash
brew install xcodegen
xcodegen generate
open FerAnimeNative.xcodeproj
```

Then in Xcode:

1. Select the `FerAnimeNative` target.
2. Configure Signing & Capabilities with your Apple ID/team.
3. Select your iPhone.
4. Press Run.

### Build with GitHub Actions

The repo includes:

```text
.github/workflows/build-ios-unsigned.yml
```

This workflow:

- Generates the Xcode project with XcodeGen.
- Builds the app for iPhone.
- Verifies `UILaunchStoryboardName=LaunchScreen` exists in the final app bundle.
- Verifies `LaunchScreen.storyboardc` is bundled.
- Packages an unsigned IPA artifact.

Open:

```text
https://github.com/edfwasd1234/FerAnimeNative/actions
```

Download the artifact named:

```text
FerAnimeNative-unsigned-ipa
```

## Signing and Sideloading

The GitHub artifact is unsigned, so it cannot be installed directly on an iPhone.

To sideload, you need signing:

- Apple Developer account and provisioning profile, or
- Xcode development signing on a Mac, or
- another signing workflow you personally control.

Recommended path:

1. Build or download the unsigned IPA.
2. Sign it with your Apple certificate and provisioning profile.
3. Install it on your registered iPhone.

For the simplest development flow, use Xcode on a Mac and press Run.

## Development Notes

The native app uses:

- SwiftUI for UI.
- AVKit / AVPlayer for direct HLS and MP4 playback.
- WebKit for embed fallback.
- URLSession for Jikan and resolver API calls.
- UserDefaults for lightweight local progress/download queue storage.

The resolver uses:

- Node HTTP server.
- Per-source resolver modules in `backend/`.
- Metadata helpers in `backend/metadata.js`.

## Roadmap

- Real offline downloading for direct streams where allowed.
- Better source matching confirmations and manual source selection.
- More resilient playback error diagnostics.
- Signed IPA workflow with user-provided Apple secrets.
- Native iOS 26 Liquid Glass APIs when GitHub/macOS runners support the required Xcode SDK.
- Better Library filters for watching, queued downloads, and completed shows.

## Acknowledgements

Thanks to the maintainers and contributors of the anime CLI/app ecosystem whose public work helped inform the resolver and source-research direction for this personal project:

- [`pystardust/ani-cli`](https://github.com/pystardust/ani-cli)
- [`justfoolingaround/animdl`](https://github.com/justfoolingaround/animdl)
- [`justchokingaround/jerry`](https://github.com/justchokingaround/jerry)
- [`sdaqo/anipy-cli`](https://github.com/sdaqo/anipy-cli)
- [`metafates/mangal`](https://github.com/metafates/mangal)
- [`justchokingaround/lobster`](https://github.com/justchokingaround/lobster)
- [`mov-cli/mov-cli`](https://github.com/mov-cli/mov-cli)
- [`port19x/redqu`](https://github.com/port19x/redqu)
- [`TowarzyszFatCat/doccli`](https://github.com/TowarzyszFatCat/doccli)
- [`alvarorichard/GoAnime`](https://github.com/alvarorichard/GoAnime)
- [`Wraient/curd`](https://github.com/Wraient/curd)
- [`viu-media/viu`](https://github.com/viu-media/viu)
- [`KilDesu/ani-skip`](https://github.com/KilDesu/ani-skip)
- [`roshancodespace/ShonenX`](https://github.com/roshancodespace/ShonenX)
- [`Jikan`](https://jikan.moe/) for the public MyAnimeList metadata API.

Respect to everyone building open-source media tooling. This project is for personal learning and private use.

## Disclaimer

This repository is for personal education and experimentation. Use it responsibly. The app does not grant rights to download, redistribute, or stream content you do not have permission to access.
