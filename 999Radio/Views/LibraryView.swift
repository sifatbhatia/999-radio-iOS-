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

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $segment) {
                    ForEach(LibrarySegment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    TextField("Filter title, era, producer", text: $filterText)
                        .textInputAutocapitalization(.never)
                }
                .foregroundStyle(.white.opacity(0.7))
                .listRowBackground(Color.white.opacity(0.04))

                if library.isHydratingCatalog {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading more songs... \(library.tracks.count)/\(library.expectedSongCount)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .listRowBackground(Color.clear)
                    .transition(.opacity)
                }

                ForEach(filtered) { track in
                    Button {
                        player.play(track, from: filtered)
                        showPlayer = true
                    } label: {
                        TrackRowContent(track: track)
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.25), value: segment)
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: filtered.map(\.id))
            .scrollContentBackground(.hidden)
            .background(Color.radioBackground)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(filtered.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
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
}
