import Foundation

struct RadioPersistence {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var likedIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.likedIDs) ?? []) }
        nonmutating set { defaults.set(Array(newValue).sorted(), forKey: Keys.likedIDs) }
    }

    var isShuffle: Bool {
        get { defaults.bool(forKey: Keys.isShuffle) }
        nonmutating set { defaults.set(newValue, forKey: Keys.isShuffle) }
    }

    var repeatMode: RepeatMode {
        get {
            guard let rawValue = defaults.string(forKey: Keys.repeatMode) else { return .off }
            return RepeatMode(rawValue: rawValue) ?? .off
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Keys.repeatMode) }
    }

    var volume: Double {
        get {
            guard defaults.object(forKey: Keys.volume) != nil else { return 0.85 }
            return defaults.double(forKey: Keys.volume)
        }
        nonmutating set { defaults.set(newValue, forKey: Keys.volume) }
    }

    var recentlyPlayed: [Track] {
        get {
            guard let data = defaults.data(forKey: Keys.recentlyPlayed) else { return [] }
            return (try? JSONDecoder().decode([Track].self, from: data)) ?? []
        }
        nonmutating set {
            let trimmed = Array(newValue.prefix(25))
            defaults.set(try? JSONEncoder().encode(trimmed), forKey: Keys.recentlyPlayed)
        }
    }

    var savedQueue: [Track] {
        get { decodeTracks(forKey: Keys.savedQueue) }
        nonmutating set { encode(Array(newValue.prefix(100)), forKey: Keys.savedQueue) }
    }

    var currentTrack: Track? {
        get {
            guard let data = defaults.data(forKey: Keys.currentTrack) else { return nil }
            return try? JSONDecoder().decode(Track.self, from: data)
        }
        nonmutating set {
            guard let newValue else {
                defaults.removeObject(forKey: Keys.currentTrack)
                return
            }
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Keys.currentTrack)
        }
    }

    private func decodeTracks(forKey key: String) -> [Track] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Track].self, from: data)) ?? []
    }

    private func encode(_ tracks: [Track], forKey key: String) {
        defaults.set(try? JSONEncoder().encode(tracks), forKey: key)
    }

    private enum Keys {
        static let likedIDs = "radio.likedIDs"
        static let isShuffle = "radio.isShuffle"
        static let repeatMode = "radio.repeatMode"
        static let volume = "radio.volume"
        static let recentlyPlayed = "radio.recentlyPlayed"
        static let savedQueue = "radio.savedQueue"
        static let currentTrack = "radio.currentTrack"
    }
}
