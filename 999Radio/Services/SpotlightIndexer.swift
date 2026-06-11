import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

enum SpotlightIndexer {
    static func index(_ tracks: [Track]) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let items = tracks.prefix(500).map { track in
            let attributes = CSSearchableItemAttributeSet(contentType: .audio)
            attributes.title = track.title
            attributes.contentDescription = [track.era, track.producer, track.category]
                .compactMap { $0?.nilIfEmpty }
                .joined(separator: " - ")
            attributes.keywords = [track.artist, track.album, track.genre, track.mood, track.era, track.producer]
                .compactMap { $0?.nilIfEmpty }

            return CSSearchableItem(
                uniqueIdentifier: "track-\(track.id)",
                domainIdentifier: "songs",
                attributeSet: attributes
            )
        }

        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }
}
