import Foundation

struct RadioStats: Decodable, Equatable, Sendable {
    let totalSongs: Int?
    let totalEras: Int?
    let totalCategories: Int?
    let releasedSongs: Int?
    let unreleasedSongs: Int?

    enum CodingKeys: String, CodingKey {
        case totalSongs = "total_songs"
        case totalEras = "total_eras"
        case totalCategories = "total_categories"
        case releasedSongs = "released_songs"
        case unreleasedSongs = "unreleased_songs"
    }
}
