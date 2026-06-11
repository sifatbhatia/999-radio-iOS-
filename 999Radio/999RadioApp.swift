import SwiftUI
import AVFoundation
import Observation

@main
struct NineNineNineRadioApp: App {
    @State private var library = RadioLibrary()
    @State private var player = RadioPlayer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(player)
                .task {
                    await library.loadInitialContent()
                }
        }
    }
}

// MARK: - Models

struct Track: Identifiable, Hashable, Codable {
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
}

struct RadioStats: Decodable, Equatable {
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

private struct APISongResponse: Decodable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [APISong]
}

private struct APISong: Decodable {
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

private struct APIEra: Decodable {
    let id: Int
    let name: String
    let playCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case playCount = "play_count"
    }
}

// MARK: - API

enum JuiceAPI {
    static let baseURL = URL(string: "https://juicewrldapi.com/juicewrld")!
    private static let coverColors = ["#8f4a2f", "#5d4b35", "#a25036", "#6b392d", "#94613c", "#704d43", "#7c3428", "#b65a32"]

    static func fetchSongs(query: String = "", pageSize: Int = 24, page: Int = 1) async throws -> (count: Int, tracks: [Track]) {
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
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        return URL(string: "https://juicewrldapi.com\(path)")
    }

    private static func request<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
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

// MARK: - App State

@Observable
final class RadioLibrary {
    var tracks: [Track] = []
    var stats: RadioStats?
    var query = ""
    var isLoading = false
    var errorMessage: String?

    var released: [Track] { tracks.filter { $0.category == "released" } }
    var unreleased: [Track] { tracks.filter { $0.category != "released" } }

    func loadInitialContent() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.search() }
            group.addTask { await self.loadStats() }
        }
    }

    @MainActor
    func search() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await JuiceAPI.fetchSongs(query: query)
            tracks = result.tracks
        } catch {
            errorMessage = "Could not load 999 Radio. Pull down or search again."
        }
        isLoading = false
    }

    @MainActor
    func loadStats() async {
        stats = try? await JuiceAPI.fetchStats()
    }
}

@Observable
final class RadioPlayer {
    var currentTrack: Track?
    var isPlaying = false
    var isShuffle = false
    var volume: Double = 0.85 {
        didSet { player.volume = Float(volume) }
    }
    var progress: TimeInterval = 0
    var duration: TimeInterval = 0
    var queue: [Track] = []
    var likedIDs: Set<String> = []

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var observer: Any?
    @ObservationIgnored private var lastTrackID: String?

    init() {
        player.volume = Float(volume)
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.progress = time.seconds.isFinite ? time.seconds : 0
            if let item = self?.player.currentItem {
                let seconds = item.duration.seconds
                if seconds.isFinite && seconds > 0 {
                    self?.duration = seconds
                }
            }
        }
    }

    deinit {
        if let observer { player.removeTimeObserver(observer) }
    }

    func play(_ track: Track, from tracks: [Track]) {
        currentTrack = track
        queue = tracks
        configureIfNeeded(track)
        player.play()
        isPlaying = true
        Task { await JuiceAPI.trackPlay(track) }
    }

    func toggle() {
        if isPlaying {
            player.pause()
        } else {
            configureIfNeeded(currentTrack)
            player.play()
        }
        isPlaying.toggle()
    }

    func next() {
        guard let currentTrack, !queue.isEmpty else { return }
        if isShuffle, let random = queue.filter({ $0.id != currentTrack.id }).randomElement() {
            play(random, from: queue)
            return
        }
        let index = queue.firstIndex(of: currentTrack) ?? -1
        let nextIndex = queue.index(after: index)
        play(queue[nextIndex < queue.count ? nextIndex : 0], from: queue)
    }

    func previous() {
        guard let currentTrack, !queue.isEmpty else { return }
        let index = queue.firstIndex(of: currentTrack) ?? 0
        let previousIndex = index == 0 ? queue.count - 1 : index - 1
        play(queue[previousIndex], from: queue)
    }

    func seek(to fraction: Double) {
        let clamped = min(max(fraction, 0), 1)
        let seconds = (duration > 0 ? duration : currentTrack?.duration ?? 0) * clamped
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    func toggleLike(_ id: String) {
        if likedIDs.contains(id) {
            likedIDs.remove(id)
        } else {
            likedIDs.insert(id)
        }
    }

    func upNext(limit: Int = 8) -> [Track] {
        guard let currentTrack, !queue.isEmpty else { return [] }
        let start = (queue.firstIndex(of: currentTrack) ?? 0) + 1
        return (0..<min(limit, queue.count)).map { queue[(start + $0) % queue.count] }
    }

    private func configureIfNeeded(_ track: Track?) {
        guard let track, lastTrackID != track.id else { return }
        lastTrackID = track.id
        progress = 0
        duration = track.duration
        guard let url = JuiceAPI.mediaURL(for: track) else { return }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
    }
}

// MARK: - Views

struct RootView: View {
    @Environment(RadioLibrary.self) private var library
    @Environment(RadioPlayer.self) private var player
    @State private var selectedTab: AppTab = .home
    @State private var showPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(showPlayer: $showPlayer)
                    .tag(AppTab.home)
                    .tabItem { Label("Home", systemImage: "house.fill") }

                LibraryView(showPlayer: $showPlayer)
                    .tag(AppTab.library)
                    .tabItem { Label("Library", systemImage: "rectangle.stack.fill") }

                SettingsView()
                    .tag(AppTab.settings)
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .tint(.orange)

            if player.currentTrack != nil {
                MiniPlayer(showPlayer: $showPlayer)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 54)
            }
        }
        .background(Color.radioBackground.ignoresSafeArea())
        .sheet(isPresented: $showPlayer) {
            FullPlayerView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }
}

enum AppTab { case home, library, settings }

struct HomeView: View {
    @Environment(RadioLibrary.self) private var library
    @Environment(RadioPlayer.self) private var player
    @Binding var showPlayer: Bool

    var body: some View {
        @Bindable var library = library
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HeroStats(stats: library.stats)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                        TextField("Search the archive", text: $library.query)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                            .onSubmit { Task { await library.search() } }
                    }
                    .padding(14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    SectionHeader(title: "Warm Frequencies", subtitle: "From the current API feed")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(library.tracks.prefix(8)) { track in
                            TrackCard(track: track) {
                                player.play(track, from: library.tracks)
                                showPlayer = true
                            }
                        }
                    }

                    SectionHeader(title: "Up Next", subtitle: "Sequential unless shuffle is on")
                    VStack(spacing: 8) {
                        ForEach(library.tracks.dropFirst(8).prefix(8)) { track in
                            TrackRow(track: track) {
                                player.play(track, from: library.tracks)
                            }
                        }
                    }
                }
                .padding(18)
                .padding(.bottom, 96)
            }
            .refreshable { await library.loadInitialContent() }
            .navigationTitle("999 Radio")
            .toolbarBackground(.hidden, for: .navigationBar)
            .overlay {
                if library.isLoading && library.tracks.isEmpty {
                    ProgressView("Tuning station…")
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .alert("Signal lost", isPresented: .constant(library.errorMessage != nil)) {
                Button("Retry") { Task { await library.search() } }
                Button("Dismiss", role: .cancel) { library.errorMessage = nil }
            } message: {
                Text(library.errorMessage ?? "")
            }
        }
    }
}

struct LibraryView: View {
    @Environment(RadioLibrary.self) private var library
    @Environment(RadioPlayer.self) private var player
    @Binding var showPlayer: Bool
    @State private var segment = 0

    private var filtered: [Track] {
        switch segment {
        case 1: library.released
        case 2: library.unreleased
        default: library.tracks
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $segment) {
                    Text("All").tag(0)
                    Text("Released").tag(1)
                    Text("Archive").tag(2)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                ForEach(filtered) { track in
                    Button {
                        player.play(track, from: filtered)
                        showPlayer = true
                    } label: {
                        TrackRowContent(track: track)
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.radioBackground)
            .navigationTitle("Library")
        }
    }
}

struct SettingsView: View {
    @Environment(RadioLibrary.self) private var library

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    LabeledContent("API", value: "juicewrldapi.com")
                    LabeledContent("State", value: "In memory")
                    LabeledContent("App", value: "Native SwiftUI")
                }

                Section("Stats") {
                    LabeledContent("Songs", value: String(library.stats?.totalSongs ?? library.tracks.count))
                    LabeledContent("Released", value: String(library.stats?.releasedSongs ?? library.released.count))
                    LabeledContent("Unreleased", value: String(library.stats?.unreleasedSongs ?? library.unreleased.count))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.radioBackground)
            .navigationTitle("Settings")
        }
    }
}

struct FullPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RadioPlayer.self) private var player
    @State private var showLyrics = false
    @State private var showQueue = false

    var body: some View {
        @Bindable var player = player
        ZStack {
            if let track = player.currentTrack {
                CoverBackdrop(track: track)

                VStack(spacing: 18) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down")
                                .font(.title2.bold())
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("NOW PLAYING")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.48))
                            Text("999 Radio")
                                .font(.subheadline.weight(.bold))
                        }
                        Spacer()
                        Menu {
                            Button("Toggle Queue") { showQueue.toggle() }
                            Button("Toggle Lyrics") { showLyrics.toggle() }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.title2.bold())
                        }
                    }
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 18)
                    .padding(.top, 16)

                    AsyncCover(track: track, size: 330)
                        .clipShape(RoundedRectangle(cornerRadius: player.isPlaying ? 16 : 26, style: .continuous))
                        .shadow(color: .black.opacity(0.45), radius: 28, y: 16)
                        .scaleEffect(player.isPlaying ? 1 : 0.94)
                        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: player.isPlaying)

                    HStack(spacing: 14) {
                        Button { player.toggleLike(track.id) } label: {
                            Image(systemName: player.likedIDs.contains(track.id) ? "heart.fill" : "heart")
                                .foregroundStyle(player.likedIDs.contains(track.id) ? .orange : .white.opacity(0.4))
                        }
                        VStack(spacing: 4) {
                            Text(track.title)
                                .font(.title3.bold())
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        ShareLink(item: track.title) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .font(.title3)
                    .padding(.horizontal, 26)

                    VStack(spacing: 6) {
                        Slider(value: Binding(
                            get: { player.duration > 0 ? player.progress / player.duration : 0 },
                            set: { player.seek(to: $0) }
                        ), in: 0...1)
                        .tint(.orange)
                        HStack {
                            Text(formatTime(player.progress))
                            Spacer()
                            Text(formatTime(player.duration > 0 ? player.duration : track.duration))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.44))
                    }
                    .padding(.horizontal, 26)

                    HStack(spacing: 26) {
                        Button { player.isShuffle.toggle() } label: {
                            Image(systemName: "shuffle")
                                .foregroundStyle(player.isShuffle ? .orange : .white.opacity(0.5))
                        }
                        Button { player.previous() } label: { Image(systemName: "backward.fill") }
                        Button { player.toggle() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title.bold())
                                .frame(width: player.isPlaying ? 72 : 68, height: player.isPlaying ? 56 : 68)
                                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: player.isPlaying ? 18 : 34, style: .continuous))
                        }
                        Button { player.next() } label: { Image(systemName: "forward.fill") }
                        Button { showQueue.toggle() } label: { Image(systemName: "text.quote") }
                    }
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                        Slider(value: $player.volume, in: 0...1)
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .tint(.white.opacity(0.75))
                    .foregroundStyle(.white.opacity(0.42))
                    .padding(.horizontal, 30)

                    HStack {
                        Button("Lyrics") { showLyrics.toggle(); showQueue = false }
                            .buttonStyle(PillButtonStyle(active: showLyrics))
                            .disabled(track.lyrics == nil)
                        Button("Up Next") { showQueue.toggle(); showLyrics = false }
                            .buttonStyle(PillButtonStyle(active: showQueue))
                    }

                    if showLyrics, let lyrics = track.lyrics {
                        ScrollView {
                            Text(lyrics)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.callout)
                                .lineSpacing(5)
                                .foregroundStyle(.white.opacity(0.86))
                        }
                        .frame(maxHeight: 170)
                        .padding(16)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 24)
                    }

                    if showQueue {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Up Next").font(.headline)
                                Spacer()
                                Text(player.isShuffle ? "Shuffle" : "Sequential")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.44))
                            }
                            ForEach(player.upNext()) { track in
                                Button { player.play(track, from: player.queue) } label: {
                                    Text(track.title)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 3)
                                }
                            }
                        }
                        .padding(16)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 8)
                }
            }
        }
        .background(Color.radioBackground.ignoresSafeArea())
    }
}

struct MiniPlayer: View {
    @Environment(RadioPlayer.self) private var player
    @Binding var showPlayer: Bool

    var body: some View {
        if let track = player.currentTrack {
            Button { showPlayer = true } label: {
                HStack(spacing: 12) {
                    AsyncCover(track: track, size: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title).font(.subheadline.bold()).lineLimit(1)
                        Text(track.artist).font(.caption).foregroundStyle(.white.opacity(0.54)).lineLimit(1)
                    }
                    Spacer()
                    Button { player.toggle() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3.bold())
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .foregroundStyle(.white)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
    }
}

struct HeroStats: View {
    let stats: RadioStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("999 Radio")
                .font(.largeTitle.weight(.black))
            Text("A native iOS station for Juice WRLD released cuts, leaks, eras, and deep archive browsing.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.62))
            HStack {
                StatChip(title: "Songs", value: stats?.totalSongs)
                StatChip(title: "Released", value: stats?.releasedSongs)
                StatChip(title: "Archive", value: stats?.unreleasedSongs)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.orange.opacity(0.35), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.08)))
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.bold())
            Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.48))
        }
    }
}

struct StatChip: View {
    let title: String
    let value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map(String.init) ?? "—")
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct TrackCard: View {
    let track: Track
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                AsyncCover(track: track, size: 156)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(track.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

struct TrackRow: View {
    let track: Track
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TrackRowContent(track: track)
        }
        .buttonStyle(.plain)
    }
}

struct TrackRowContent: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            AsyncCover(track: track, size: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(track.artist) · \(track.album)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer()
            Text(formatTime(track.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.38))
        }
        .foregroundStyle(.white)
        .padding(.vertical, 6)
    }
}

struct AsyncCover: View {
    let track: Track
    let size: CGFloat

    var body: some View {
        ZStack {
            CoverFallback(track: track)
            if let url = track.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: Color.clear
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

struct CoverFallback: View {
    let track: Track

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: track.coverColorHex), Color.black.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String(track.title.prefix(2)).uppercased())
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

struct CoverBackdrop: View {
    let track: Track

    var body: some View {
        ZStack {
            Color(hex: track.coverColorHex).opacity(0.75)
            LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(.ultraThinMaterial).opacity(0.55)
        }
        .ignoresSafeArea()
    }
}

struct PillButtonStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(active ? .orange : .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(active ? .orange.opacity(0.18) : .clear, in: Capsule())
            .overlay(Capsule().stroke(active ? .orange : .white.opacity(0.2)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

// MARK: - Utilities

func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite else { return "0:00" }
    let total = max(0, Int(seconds.rounded()))
    return "\(total / 60):\(String(format: "%02d", total % 60))"
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension Color {
    static let radioBackground = Color(red: 0.055, green: 0.048, blue: 0.043)

    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let r, g, b: UInt64
        switch sanitized.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            (r, g, b) = (143, 74, 47)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
