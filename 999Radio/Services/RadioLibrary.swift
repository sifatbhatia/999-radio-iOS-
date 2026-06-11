import Observation
import SwiftUI

@MainActor
@Observable
final class RadioLibrary {
    var tracks: [Track] = []
    var stats: RadioStats?
    var query = ""
    var isLoading = false
    var isHydratingCatalog = false
    var errorMessage: String?
    var loadedSongCount = 0
    var expectedSongCount = 0

    var released: [Track] { tracks.filter { $0.category == "released" } }
    var unreleased: [Track] { tracks.filter { $0.category != "released" } }
    var suggestions: [Track] {
        tracks
            .filter { $0.sourcePath != nil }
            .sorted { lhs, rhs in
                if lhs.playCount == rhs.playCount {
                    return lhs.title < rhs.title
                }
                return lhs.playCount > rhs.playCount
            }
            .prefix(12)
            .map { $0 }
    }

    @ObservationIgnored private var hydrationTask: Task<Void, Never>?

    func loadInitialContent() async {
        await search()
        await loadStats()
    }

    func search() async {
        hydrationTask?.cancel()
        withAnimation(.smooth(duration: 0.2)) {
            isLoading = true
            isHydratingCatalog = false
        }
        errorMessage = nil
        let currentQuery = query
        do {
            let result = try await JuiceAPI.fetchSongs(query: currentQuery)
            withAnimation(.smooth(duration: 0.28)) {
                tracks = result.tracks
                loadedSongCount = result.tracks.count
                expectedSongCount = result.count
                isLoading = false
            }
            hydrateCatalogIfNeeded(query: currentQuery, totalCount: result.count)
        } catch {
            errorMessage = "Could not load 999 Radio. Pull down or search again."
            withAnimation(.smooth(duration: 0.22)) {
                isLoading = false
                isHydratingCatalog = false
            }
        }
    }

    func loadStats() async {
        let loadedStats = try? await JuiceAPI.fetchStats()
        withAnimation(.smooth(duration: 0.22)) {
            stats = loadedStats
        }
    }

    private func hydrateCatalogIfNeeded(query: String, totalCount: Int) {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, totalCount > tracks.count else {
            SpotlightIndexer.index(tracks)
            return
        }

        withAnimation(.smooth(duration: 0.2)) {
            isHydratingCatalog = true
        }

        let firstPageTracks = tracks
        hydrationTask = Task { [firstPageTracks] in
            let remaining = await JuiceAPI.fetchRemainingSongs(query: query, totalCount: totalCount, startingAt: 2)
            guard !Task.isCancelled else { return }

            let hydratedTracks = mergeTracks(firstPageTracks + remaining)
            withAnimation(.smooth(duration: 0.3)) {
                tracks = hydratedTracks
                loadedSongCount = hydratedTracks.count
                isHydratingCatalog = false
            }
            SpotlightIndexer.index(hydratedTracks)
        }
    }

    private func mergeTracks(_ incoming: [Track]) -> [Track] {
        var seen = Set<String>()
        return incoming.filter { track in
            seen.insert(track.id).inserted
        }
    }
}
