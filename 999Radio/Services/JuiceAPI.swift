import Foundation

enum JuiceAPI {
    static let baseURL = URL(string: "https://juicewrldapi.com/juicewrld")!
    private static let coverColors = ["#8f4a2f", "#5d4b35", "#a25036", "#6b392d", "#94613c", "#704d43", "#7c3428", "#b65a32"]

    static func fetchSongs(query: String = "", pageSize: Int = 100, page: Int = 1) async throws -> (count: Int, tracks: [Track]) {
        var components = URLComponents(url: baseURL.appending(path: "songs/"), resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "sort", value: "era")
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "search", value: trimmed))
        }
        components.queryItems = items

        let response: APISongResponse = try await request(components.url!)
        return (response.count, response.results.enumerated().map { mapSong($0.element, index: $0.offset) })
    }

    static func fetchAllSongs(query: String = "", pageSize: Int = 100) async throws -> (count: Int, tracks: [Track]) {
        var page = 1
        var expectedCount = 0
        var tracks: [Track] = []

        while true {
            let response = try await fetchSongPage(query: query, pageSize: pageSize, page: page)
            expectedCount = response.count
            let offset = tracks.count
            tracks.append(contentsOf: response.results.enumerated().map { mapSong($0.element, index: offset + $0.offset) })

            let hasNextPage = response.next != nil && !response.results.isEmpty
            let reachedCount = expectedCount > 0 && tracks.count >= expectedCount
            if !hasNextPage || reachedCount {
                return (expectedCount, tracks)
            }

            page += 1
        }
    }

    static func fetchRemainingSongs(query: String = "", pageSize: Int = 100, totalCount: Int, startingAt page: Int = 2) async -> [Track] {
        let pageCount = Int(ceil(Double(min(totalCount, 3_000)) / Double(pageSize)))
        guard page <= pageCount else { return [] }

        return await withTaskGroup(of: (Int, [Track]).self) { group in
            for pageNumber in page...pageCount {
                group.addTask {
                    do {
                        let response = try await fetchSongPage(query: query, pageSize: pageSize, page: pageNumber)
                        let offset = (pageNumber - 1) * pageSize
                        let tracks = response.results.enumerated().map { mapSong($0.element, index: offset + $0.offset) }
                        return (pageNumber, tracks)
                    } catch {
                        return (pageNumber, [])
                    }
                }
            }

            var pages: [(Int, [Track])] = []
            for await result in group {
                pages.append(result)
            }

            return pages
                .sorted { $0.0 < $1.0 }
                .flatMap { $0.1 }
        }
    }

    static func fetchStats() async throws -> RadioStats {
        try await request(baseURL.appending(path: "stats/"))
    }

    static func trackPlay(_ track: Track) async {
        guard let url = URL(string: "\(baseURL.absoluteString)/plays/"), let id = Int(track.id) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["song": id, "source": "999-radio-ios"])
        _ = try? await URLSession.shared.data(for: request)
    }

    static func mediaURL(for track: Track) -> URL? {
        guard let path = track.sourcePath, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: "https://juicewrldapi.com\(path)")
    }

    private static func request<T: Decodable & Sendable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func fetchSongPage(query: String, pageSize: Int, page: Int) async throws -> APISongResponse {
        var components = URLComponents(url: baseURL.appending(path: "songs/"), resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "sort", value: "era")
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "search", value: trimmed))
        }
        components.queryItems = items

        return try await request(components.url!)
    }

    private static func mapSong(_ song: APISong, index: Int) -> Track {
        let artist = song.creditedArtists?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Juice WRLD"
        let era = song.era?.name ?? "Archive"
        return Track(
            id: String(song.id),
            title: song.name,
            artist: artist,
            album: era,
            duration: parseDuration(song.length),
            genre: song.category ?? "archive",
            bpm: 80 + (song.id % 48),
            mood: song.category == "released" ? "Released" : "Archive",
            year: inferYear(releaseDate: song.releaseDate, leakedDate: song.dateLeaked),
            playCount: song.era?.playCount ?? 0,
            coverColorHex: coverColors[index % coverColors.count],
            lyrics: song.lyrics?.nilIfEmpty,
            producer: song.producers?.nilIfEmpty,
            era: era,
            category: song.category,
            sourcePath: song.path,
            imageURL: imageURL(song.imageURL)
        )
    }

    private static func parseDuration(_ value: String?) -> TimeInterval {
        guard let value else { return 180 }
        let parts = value.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return 180 }
        return parts[0] * 60 + parts[1]
    }

    private static func inferYear(releaseDate: String?, leakedDate: String?) -> Int {
        let text = "\(releaseDate ?? "") \(leakedDate ?? "")"
        let regex = try? NSRegularExpression(pattern: "(20\\d{2}|19\\d{2})")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex?.firstMatch(in: text, range: range), let matchRange = Range(match.range, in: text) else { return 2019 }
        return Int(text[matchRange]) ?? 2019
    }

    private static func imageURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: "https://juicewrldapi.com\(path)")
    }
}

private struct APISongResponse: Decodable, Sendable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [APISong]
}

private struct APISong: Decodable, Sendable {
    let id: Int
    let publicID: Int?
    let name: String
    let category: String?
    let era: APIEra?
    let path: String?
    let creditedArtists: String?
    let producers: String?
    let length: String?
    let lyrics: String?
    let releaseDate: String?
    let dateLeaked: String?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case publicID = "public_id"
        case name
        case category
        case era
        case path
        case creditedArtists = "credited_artists"
        case producers
        case length
        case lyrics
        case releaseDate = "release_date"
        case dateLeaked = "date_leaked"
        case imageURL = "image_url"
    }
}

private struct APIEra: Decodable, Sendable {
    let id: Int
    let name: String
    let playCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case playCount = "play_count"
    }
}
