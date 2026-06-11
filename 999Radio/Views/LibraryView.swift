import SwiftUI

struct LibraryView: View {
    @Environment(RadioLibrary.self) private var library
    @Environment(RadioPlayer.self) private var player
    @Binding var showPlayer: Bool
    @State private var segment: LibrarySegment = .all
    @State private var filterText = ""

    private var filtered: [Track] {
        let source: [Track]
        switch segment {
        case .all: source = library.tracks
        case .released: source = library.released
        case .archive: source = library.unreleased
        case .liked: source = library.tracks.filter { player.likedIDs.contains($0.id) }
        case .recent: source = player.recentlyPlayed
        }

        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return source }
        return source.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.artist.localizedCaseInsensitiveContains(trimmed) ||
            ($0.era ?? "").localizedCaseInsensitiveContains(trimmed) ||
            ($0.producer ?? "").localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var playableFiltered: [Track] {
        filtered.filter(\.isPlayable)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Library")
                            .font(.system(size: 34, weight: .bold))
                        Text(library.isHydratingCatalog ? "\(library.tracks.count) of \(library.expectedSongCount) songs loaded" : "\(filtered.count) songs · \(playableFiltered.count) playable")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.52))
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.45))
                        TextField("Search songs, eras, producers", text: $filterText)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                    }
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06)))

                    libraryActions

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LibrarySegment.allCases) { item in
                                Button {
                                    withAnimation(.smooth(duration: 0.22)) {
                                        segment = item
                                    }
                                } label: {
                                    Label(item.title, systemImage: item.systemImage)
                                        .labelStyle(.titleAndIcon)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 13)
                                        .frame(height: 34)
                                        .background(segment == item ? Color.accentOrange : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .foregroundStyle(segment == item ? .white : .white.opacity(0.72))
                                }
                                .buttonStyle(ScaleButtonStyle(scale: 0.96))
                            }
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        LibraryShortcut(title: "Released", subtitle: "\(library.released.count) tracks", icon: "checkmark.seal.fill", tint: .green) {
                            segment = .released
                        }
                        LibraryShortcut(title: "Archive", subtitle: "\(library.unreleased.count) tracks", icon: "archivebox.fill", tint: .purple) {
                            segment = .archive
                        }
                        LibraryShortcut(title: "Liked", subtitle: "\(player.likedIDs.count) tracks", icon: "heart.fill", tint: .pink) {
                            segment = .liked
                        }
                        LibraryShortcut(title: "Recent", subtitle: "\(player.recentlyPlayed.count) plays", icon: "clock.fill", tint: .orange) {
                            segment = .recent
                        }
                    }

                    if library.isHydratingCatalog {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white.opacity(0.6))
                            Text("Loading the rest in the background")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.54))
                            Spacer()
                            Text("\(library.tracks.count)/\(library.expectedSongCount)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .transition(.opacity)
                    }

                    if let message = player.playbackErrorMessage {
                        Text(message)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(segment.title)
                                .font(.title3.bold())
                            Spacer()
                            Text("\(filtered.count)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.white.opacity(0.42))
                        }

                        if filtered.isEmpty {
                            EmptyLibraryState(title: "No songs found", subtitle: "Try a different search or filter.")
                        } else if playableFiltered.isEmpty {
                            EmptyLibraryState(title: "No playable songs here", subtitle: "This filter only has metadata right now.")
                        }

                        LazyVStack(spacing: 0) {
                            ForEach(filtered.prefix(250)) { track in
                                TrackRow(track: track) {
                                    guard track.isPlayable else {
                                        player.playbackErrorMessage = "This track does not have playable audio yet."
                                        return
                                    }
                                    player.play(track, from: playableFiltered)
                                    showPlayer = true
                                }
                                Divider()
                                    .overlay(.white.opacity(0.06))
                                    .padding(.leading, 62)
                            }
                        }
                        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.055)))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 108)
            }
            .animation(.smooth(duration: 0.25), value: segment)
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: filtered.map(\.id))
            .background(Color.radioBackground)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var libraryActions: some View {
        HStack(spacing: 10) {
            Button {
                guard let first = playableFiltered.first else {
                    player.playbackErrorMessage = "No playable songs in this list yet."
                    return
                }
                player.play(first, from: playableFiltered)
                showPlayer = true
            } label: {
                Label("Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .disabled(playableFiltered.isEmpty)
            .buttonStyle(LibraryActionButtonStyle(isPrimary: true))

            Button {
                guard let first = playableFiltered.shuffled().first else {
                    player.playbackErrorMessage = "No playable songs in this list yet."
                    return
                }
                player.play(first, from: playableFiltered.shuffled())
                if !player.isShuffle { player.toggleShuffle() }
                showPlayer = true
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .disabled(playableFiltered.count < 2)
            .buttonStyle(LibraryActionButtonStyle(isPrimary: false))
        }
    }
}

private struct LibraryShortcut: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.2), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06)))
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
        .foregroundStyle(.white)
    }
}

private struct LibraryActionButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .frame(height: 44)
            .background(isPrimary ? Color.accentOrange : Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(isPrimary ? 0 : 0.07)))
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct EmptyLibraryState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note.list")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.35))
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private enum LibrarySegment: String, CaseIterable, Identifiable {
    case all
    case released
    case archive
    case liked
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .released: "Released"
        case .archive: "Archive"
        case .liked: "Liked"
        case .recent: "Recent"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "music.note.list"
        case .released: "checkmark.seal"
        case .archive: "archivebox"
        case .liked: "heart"
        case .recent: "clock"
        }
    }
}
