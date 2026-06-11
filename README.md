# 999 Radio iOS

Native SwiftUI rebuild of the 999 Radio web app for iOS 26.

This is not a WebView wrapper. It uses SwiftUI, Observation, AVFoundation, async networking, and the same Juice WRLD API consumed by the web app.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the staged product and architecture plan. The next recommended work is to split the current single Swift file into app, model, service, player, persistence, and view modules before adding more feature surface area.

## What is included

- Native SwiftUI home/library/player/settings UI
- Search against `https://juicewrldapi.com/juicewrld/songs/`
- Stats from `https://juicewrldapi.com/juicewrld/stats/`
- Track mapping compatible with the web app model
- AVPlayer-backed playback from API source paths
- Native now-playing screen with scrubber, volume, shuffle, lyrics, queue, liked tracks, and share sheet
- Unsigned GitHub Actions build artifact

## Local build

Open `999Radio.xcodeproj` in Xcode 17 or newer and run the `999Radio` scheme.

CLI:

```bash
xcodebuild \
  -project 999Radio.xcodeproj \
  -scheme 999Radio \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
```

## GitHub Actions unsigned build

Run **Actions → Build Unsigned iOS App → Run workflow**.

The workflow builds without code signing and uploads `999Radio-unsigned.app` as an artifact. That artifact is for later unsigned/manual packaging workflows, not App Store/TestFlight distribution.
