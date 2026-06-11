import Foundation

struct Track: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let genre: String
    let bpm: Int
    let mood: String
    let year: Int
    let playCount: Int
    let coverColorHex: String
    let lyrics: String?
    let producer: String?
    let era: String?
    let category: String?
    let sourcePath: String?
    let imageURL: URL?

    var isPlayable: Bool {
        guard let sourcePath else { return false }
        return !sourcePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
