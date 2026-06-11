import SwiftUI

struct HomeView: View {
    @Environment(RadioLibrary.self) private var library
    @Environment(RadioPlayer.self) private var player
    @Binding var showPlayer: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    shuffleStation

                    if !player.recentlyPlayed.isEmpty {
                        ListenSection(
                            title: "Recently Played",
                            subtitle: "Pick up where you left off",
                            tracks: Array(player.recentlyPlayed.filter(\.isPlayable).prefix(10)),
                            showPlayer: $showPlayer
                        )
                    }

                    let likedTracks = library.tracks.filter { player.likedIDs.contains($0.id) && $0.isPlayable }
                    if !likedTracks.isEmpty {
                        ListenSection(
                            title: "Favorites",
                            subtitle: "\(likedTracks.count) liked playable songs",
                            tracks: Array(likedTracks.prefix(10)),
                            showPlayer: $showPlayer
                        )
                    }

                    ListenSection(
                        title: "For You",
                        subtitle: "Freshly rotated from the archive",
                        tracks: Array(library.suggestions.prefix(12)),
                        showPlayer: $showPlayer
                    )

                    if !library.deepCuts.isEmpty {
                        ListenSection(
                            title: "Deep Cuts",
                            subtitle: "A less obvious 999 mix",
                            tracks: Array(library.deepCuts.prefix(12)),
                            showPlayer: $showPlayer
                        )
                    }

                    if !library.releasedMix.isEmpty {
                        ListenSection(
                            title: "Released Mix",
                            subtitle: "Familiar tracks in a fresh order",
                            tracks: Array(library.releasedMix.prefix(12)),
                            showPlayer: $showPlayer
                        )
                    }

                    quickStats
                }
                .padding(18)
                .padding(.bottom, 108)
            }
            .refreshable {
                library.refreshSuggestions()
                await library.loadInitialContent()
            }
            .background(Color.radioBackground)
            .toolbarBackground(.hidden, for: .navigationBar)
            .overlay {
                if library.isLoading && library.tracks.isEmpty {
                    ProgressView("Tuning station...")
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.24), value: library.isLoading)
            .animation(.smooth(duration: 0.28), value: library.suggestionSeed)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Listen Now")
                    .font(.system(size: 34, weight: .bold))
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.52))
            }
            Spacer()
            Button {
                library.refreshSuggestions()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline.bold())
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.96))
            .foregroundStyle(.white.opacity(0.78))
            .accessibilityLabel("Refresh suggestions")
        }
    }

    private var statusText: String {
        let playableCount = library.tracks.filter(\.isPlayable).count
        if library.isUsingCachedCatalog {
            return "Ready from cache, refreshing live"
        }
        if library.isHydratingCatalog {
            return "Refreshing the archive in the background"
        }
        return "\(playableCount) playable songs ready"
    }

    private var shuffleStation: some View {
        Button {
            let playable = library.tracks.filter(\.isPlayable)
            let shuffled = playable.seededHomeShuffle(seed: library.suggestionSeed &+ Int.random(in: 1...99_999))
            if let track = shuffled.first {
                player.play(track, from: shuffled)
                if !player.isShuffle { player.toggleShuffle() }
                showPlayer = true
            } else {
                player.playbackErrorMessage = "No playable songs are loaded yet."
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title2.bold())
                    .frame(width: 48, height: 48)
                    .background(Color.accentOrange, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Shuffle 999 Radio")
                        .font(.headline)
                    Text("Start a fresh no-repeat station")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.52))
                }
                Spacer()
                Image(systemName: "play.fill")
            }
            .padding(14)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.06)))
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
        .foregroundStyle(.white)
    }

    private var quickStats: some View {
        HStack(spacing: 10) {
            StatPill(title: "Songs", value: library.stats?.totalSongs ?? library.expectedSongCount)
            StatPill(title: "Released", value: library.stats?.releasedSongs ?? library.released.count)
            StatPill(title: "Archive", value: library.stats?.unreleasedSongs ?? library.unreleased.count)
        }
    }
}

private struct ListenSection: View {
    @Environment(RadioLibrary.self) private var library
    @Environment(RadioPlayer.self) private var player
    let title: String
    let subtitle: String
    let tracks: [Track]
    @Binding var showPlayer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, subtitle: subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(tracks) { track in
                        TrackCard(track: track) {
                            let playable = tracks.filter(\.isPlayable)
                            guard track.isPlayable else {
                                player.playbackErrorMessage = "This track does not have playable audio yet."
                                return
                            }
                            player.play(track, from: playable.isEmpty ? library.tracks.filter(\.isPlayable) : playable)
                            showPlayer = true
                        }
                        .frame(width: 152)
                    }
                }
            }
        }
        .transition(.opacity)
    }
}

private struct StatPill: View {
    let title: String
    let value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value.map(String.init) ?? "-")
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.44))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension Array where Element == Track {
    func seededHomeShuffle(seed: Int) -> [Track] {
        sorted { lhs, rhs in
            stableScore(lhs.id, seed: seed) < stableScore(rhs.id, seed: seed)
        }
    }

    private func stableScore(_ id: String, seed: Int) -> UInt64 {
        var hash = UInt64(bitPattern: Int64(seed == 0 ? 999 : seed))
        for scalar in id.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
