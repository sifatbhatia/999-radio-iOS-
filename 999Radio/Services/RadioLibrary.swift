import Observation
import SwiftUI

@MainActor
@Observable
final class RadioLibrary {
    var tracks: [Track] = []
    var stats: RadioStats?
    var query = ""
    var isLoading = false
    var errorMessage: String?
    var loadedSongCount = 0

    var released: [Track] { tracks.filter { $0.category == "released" } }
    var unreleased: [Track] { tracks.filter { $0.category != "released" } }

    func loadInitialContent() async {
        await search()
        await loadStats()
    }

    func search() async {
        withAnimation(.smooth(duration: 0.2)) {
            isLoading = true
        }
        errorMessage = nil
        let currentQuery = query
        do {
            let result = try await JuiceAPI.fetchAllSongs(query: currentQuery)
            withAnimation(.smooth(duration: 0.28)) {
                tracks = result.tracks
                loadedSongCount = result.count
            }
            SpotlightIndexer.index(result.tracks)
        } catch {
            errorMessage = "Could not load 999 Radio. Pull down or search again."
        }
        withAnimation(.smooth(duration: 0.22)) {
            isLoading = false
        }
    }

    func loadStats() async {
        let loadedStats = try? await JuiceAPI.fetchStats()
        withAnimation(.smooth(duration: 0.22)) {
            stats = loadedStats
        }
    }
}
