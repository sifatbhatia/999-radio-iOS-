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
                        title: "Suggestions",
                        subtitle: "From the live archive",
                        tracks: Array(library.suggestions.filter(\.isPlayable).prefix(10)),
                        showPlayer: $showPlayer
                    )

                    quickStats
                }
                .padding(18)
                .padding(.bottom, 108)
            }
            .refreshable { await library.loadInitialContent() }
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
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Listen Now")
                .font(.system(size: 34, weight: .bold))
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.52))
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
            if let track = playable.randomElement() {
                player.play(track, from: playable)
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
                    Text("Start a station from playable archive tracks")
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
