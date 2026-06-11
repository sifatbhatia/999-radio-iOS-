# 999 Radio iOS Roadmap

This project is currently a native SwiftUI foundation for 999 Radio. The next goal is to turn it into a polished music app through staged product and architecture work instead of adding screens at random.

## Phase 0: Build Baseline

Goal: keep the current app buildable while feature work starts.

- Keep the `999Radio` scheme shared.
- Keep GitHub Actions producing an unsigned IPA artifact.
- Add at least one simulator build check when tests or previews are introduced.
- Document any signing path separately from the unsigned CI flow.

Exit criteria:

- `xcodebuild` succeeds locally on macOS with code signing disabled.
- GitHub Actions uploads `999Radio-unsigned.ipa`.
- Project settings needed for CI are documented in `README.md`.

## Phase 1: Architecture Split

Goal: break the one-file prototype into clear modules before the app grows.

- Move app entry and root navigation into `App/`.
- Move API mapping and networking into `Services/`.
- Move `Track`, `RadioStats`, and API DTOs into `Models/`.
- Move player state and AVPlayer integration into `Player/`.
- Move home, library, settings, full player, mini player, and shared components into `Views/`.
- Add a small design system for colors, button styles, spacing, and reusable cover art views.

Exit criteria:

- No single Swift file owns unrelated app, API, player, and view logic.
- New features have obvious folders to land in.
- Existing behavior remains visually and functionally equivalent.

## Phase 2: Persistence

Goal: make user state survive app restarts.

- Persist liked song IDs.
- Persist recently played tracks.
- Persist queue state and current playback context where practical.
- Persist settings such as volume, shuffle, repeat, theme preference, and filter choices.
- Add a small persistence service around `UserDefaults` or SwiftData, chosen by data complexity.

Exit criteria:

- Likes, recents, queue-related state, and user settings survive relaunch.
- Persistence failures degrade gracefully without blocking playback.
- Settings screen no longer reports state as only in memory.

## Phase 3: Core Player

Goal: make playback feel like a real music app.

- Add repeat modes: off, one, all.
- Add play next and add to queue.
- Add queue editing and clear queue.
- Add better seek handling and end-of-track advancement.
- Configure `AVAudioSession` for background playback.
- Add lock screen metadata and remote transport controls.
- Improve loading, empty, and error states for media URLs.

Exit criteria:

- The player can manage a session without losing context.
- Queue behavior is predictable and visible.
- Lock screen and Control Center controls work during playback.

## Phase 4: Web App Parity

Goal: preserve the curated identity of the web app in native iOS form.

- Build richer home feed sections.
- Add stats cards for archive size and categories.
- Add genre, mood, era, producer, released, and unreleased filters.
- Add song detail pages.
- Add lyrics view as a first-class surface.
- Add an up-next drawer.
- Improve album-art fallback blocks.
- Expand settings into a polished app control center.

Exit criteria:

- Users can browse by the same core concepts as the web app.
- Native UI feels intentionally iOS, not like a copied web layout.
- Empty and loading states feel designed, not temporary.

## Phase 5: iOS-Native Features

Goal: make the app better than the web app where iOS can help.

- Add haptics for player actions.
- Add Spotlight indexing for tracks if local metadata is stable enough.
- Add App Intents and Siri Shortcuts for common playback actions.
- Add widgets for now playing or quick access.
- Explore Live Activity or Dynamic Island behavior if playback state and policy fit.
- Add AirPlay route handling.
- Investigate offline cache only if API and legal constraints allow it.

Exit criteria:

- Native features are useful without compromising reliability.
- Any cache or offline behavior has explicit API/legal approval.
- Features that need entitlements or signing are separated from unsigned CI assumptions.


## Near-Term Backlog

Recommended order:

1. Complete the architecture split.
2. Add persistence for liked songs and settings.
3. Add recently played persistence.
4. Add repeat modes and play-next queue operations.
5. Add `AVAudioSession`, lock screen metadata, and remote command handling.
6. Add home and library filters for era, producer, released, and unreleased.
7. Add focused API mapping tests once a test target exists.
