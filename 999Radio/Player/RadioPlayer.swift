import AVFoundation
import MediaPlayer
import Observation
import UIKit

enum RepeatMode: String, CaseIterable, Codable {
    case off
    case one
    case all

    var systemImage: String {
        switch self {
        case .off, .all: "repeat"
        case .one: "repeat.1"
        }
    }

    var title: String {
        switch self {
        case .off: "Repeat Off"
        case .one: "Repeat One"
        case .all: "Repeat All"
        }
    }
}

@MainActor
@Observable
final class RadioPlayer {
    var currentTrack: Track?
    var isPlaying = false
    var isBuffering = false
    var isShuffle = false {
        didSet {
            persistence.isShuffle = isShuffle
            if isShuffle {
                rebuildShuffleOrder()
            } else {
                shuffledQueue = []
            }
        }
    }
    var repeatMode: RepeatMode = .off {
        didSet { persistence.repeatMode = repeatMode }
    }
    var volume: Double = 0.85 {
        didSet {
            player.volume = Float(volume)
            persistence.volume = volume
        }
    }
    var progress: TimeInterval = 0
    var duration: TimeInterval = 0
    var queue: [Track] = [] {
        didSet { persistence.savedQueue = queue.filter(\.isPlayable) }
    }
    var likedIDs: Set<String> = [] {
        didSet { persistence.likedIDs = likedIDs }
    }
    var recentlyPlayed: [Track] = []
    var playbackErrorMessage: String?

    @ObservationIgnored private let persistence = RadioPersistence()
    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private let feedback = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private var lastTrackID: String?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored private var likelyToKeepUpObserver: NSKeyValueObservation?
    @ObservationIgnored private var playbackBufferEmptyObserver: NSKeyValueObservation?
    @ObservationIgnored private var shuffledQueue: [Track] = []

    init() {
        likedIDs = persistence.likedIDs
        repeatMode = persistence.repeatMode
        volume = persistence.volume
        recentlyPlayed = persistence.recentlyPlayed.filter(\.isPlayable)
        queue = persistence.savedQueue.filter(\.isPlayable)
        currentTrack = persistence.currentTrack?.isPlayable == true ? persistence.currentTrack : nil
        if currentTrack == nil { persistence.currentTrack = nil }
        isShuffle = persistence.isShuffle
        player.volume = Float(volume)
        player.automaticallyWaitsToMinimizeStalling = false
        configureAudioSession()
        configureRemoteCommands()
        feedback.prepare()
    }

    func play(_ track: Track, from tracks: [Track]) {
        feedback.impactOccurred(intensity: 0.55)
        playbackErrorMessage = nil
        guard track.isPlayable, JuiceAPI.mediaURL(for: track) != nil else {
            stopWithError("This track does not have playable audio yet.")
            return
        }

        let playableQueue = tracks.filter(\.isPlayable)
        currentTrack = track
        queue = playableQueue.contains(track) ? playableQueue : [track] + playableQueue
        if isShuffle { rebuildShuffleOrder() }
        persistence.currentTrack = track
        recordRecentlyPlayed(track)
        configure(track)
        player.playImmediately(atRate: 1)
        isPlaying = true
        updateNowPlayingInfo()
        Task.detached { await JuiceAPI.trackPlay(track) }
    }

    func toggle() {
        feedback.impactOccurred(intensity: 0.35)
        playbackErrorMessage = nil
        guard let currentTrack else { return }
        guard currentTrack.isPlayable else {
            stopWithError("This track does not have playable audio yet.")
            return
        }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if player.currentItem == nil || lastTrackID != currentTrack.id {
                configure(currentTrack)
            }
            player.playImmediately(atRate: 1)
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    func toggleShuffle() {
        feedback.impactOccurred(intensity: 0.4)
        isShuffle.toggle()
    }

    func next() {
        feedback.impactOccurred(intensity: 0.45)
        let playableQueue = activeQueue()
        guard let currentTrack, !playableQueue.isEmpty else { return }
        let index = playableQueue.firstIndex(of: currentTrack) ?? -1
        let nextIndex = playableQueue.index(after: index)
        play(playableQueue[nextIndex < playableQueue.count ? nextIndex : 0], from: playableQueue)
    }

    func previous() {
        feedback.impactOccurred(intensity: 0.45)
        let playableQueue = activeQueue()
        guard let currentTrack, !playableQueue.isEmpty else { return }
        let index = playableQueue.firstIndex(of: currentTrack) ?? 0
        let previousIndex = index == 0 ? playableQueue.count - 1 : index - 1
        play(playableQueue[previousIndex], from: playableQueue)
    }

    func seek(to fraction: Double) {
        let clamped = min(max(fraction, 0), 1)
        let seconds = (duration > 0 ? duration : currentTrack?.duration ?? 0) * clamped
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        progress = seconds
        updateNowPlayingInfo()
    }

    func tick() {
        let current = player.currentTime().seconds
        if current.isFinite { progress = current }
        if let item = player.currentItem {
            let seconds = item.duration.seconds
            if seconds.isFinite && seconds > 0 { duration = seconds }
        }
        updateNowPlayingPlaybackState()
    }

    func toggleLike(_ id: String) {
        feedback.impactOccurred(intensity: 0.5)
        if likedIDs.contains(id) {
            likedIDs.remove(id)
        } else {
            likedIDs.insert(id)
        }
    }

    func upNext(limit: Int = 8) -> [Track] {
        let playableQueue = activeQueue()
        guard let currentTrack, !playableQueue.isEmpty else { return [] }
        let start = (playableQueue.firstIndex(of: currentTrack) ?? 0) + 1
        return (0..<min(limit, playableQueue.count)).map { playableQueue[(start + $0) % playableQueue.count] }
    }

    func cycleRepeatMode() {
        feedback.impactOccurred(intensity: 0.4)
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func playNext(_ track: Track) {
        feedback.impactOccurred(intensity: 0.35)
        guard track.isPlayable else {
            playbackErrorMessage = "This track does not have playable audio yet."
            return
        }
        guard let currentTrack, !queue.isEmpty else {
            queue = [track]
            return
        }
        queue.removeAll { $0.id == track.id || !$0.isPlayable }
        let currentIndex = queue.firstIndex(of: currentTrack) ?? 0
        queue.insert(track, at: min(currentIndex + 1, queue.count))
        if isShuffle { rebuildShuffleOrder() }
    }

    func addToQueue(_ track: Track) {
        feedback.impactOccurred(intensity: 0.35)
        guard track.isPlayable else {
            playbackErrorMessage = "This track does not have playable audio yet."
            return
        }
        guard !queue.contains(where: { $0.id == track.id }) else { return }
        queue.append(track)
        if isShuffle { rebuildShuffleOrder() }
    }

    func removeFromQueue(_ track: Track) {
        feedback.impactOccurred(intensity: 0.3)
        queue.removeAll { $0.id == track.id }
        shuffledQueue.removeAll { $0.id == track.id }
    }

    func clearQueue() {
        feedback.impactOccurred(intensity: 0.3)
        queue = currentTrack.map { [$0] } ?? []
        if isShuffle { rebuildShuffleOrder() }
    }

    private func activeQueue() -> [Track] {
        if isShuffle, !shuffledQueue.isEmpty { return shuffledQueue }
        return queue.filter(\.isPlayable)
    }

    private func rebuildShuffleOrder() {
        var playable = queue.filter(\.isPlayable).shuffled()
        if let currentTrack, let currentIndex = playable.firstIndex(of: currentTrack) {
            let current = playable.remove(at: currentIndex)
            playable.insert(current, at: 0)
        }
        shuffledQueue = playable
    }

    private func stopWithError(_ message: String) {
        player.pause()
        player.replaceCurrentItem(with: nil)
        lastTrackID = nil
        currentTrack = nil
        isPlaying = false
        isBuffering = false
        progress = 0
        duration = 0
        playbackErrorMessage = message
        persistence.currentTrack = nil
        updateNowPlayingInfo()
    }

    private func recordRecentlyPlayed(_ track: Track) {
        recentlyPlayed.removeAll { $0.id == track.id }
        recentlyPlayed.insert(track, at: 0)
        recentlyPlayed = Array(recentlyPlayed.filter(\.isPlayable).prefix(25))
        persistence.recentlyPlayed = recentlyPlayed
    }

    private func configure(_ track: Track) {
        lastTrackID = track.id
        progress = 0
        duration = track.duration
        isBuffering = true
        guard let url = JuiceAPI.mediaURL(for: track) else {
            stopWithError("This track does not have playable audio yet.")
            return
        }
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 1.5
        observeStatus(of: item)
        observeBuffering(of: item)
        player.replaceCurrentItem(with: item)
        observeEnd(of: item)
    }

    private func handleTrackEnded() {
        guard let currentTrack else { return }
        if repeatMode == .one {
            seek(to: 0)
            player.playImmediately(atRate: 1)
            isPlaying = true
            return
        }

        if repeatMode == .off, activeQueue().last == currentTrack, !isShuffle {
            isPlaying = false
            updateNowPlayingInfo()
            return
        }

        next()
    }

    private func observeEnd(of item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleTrackEnded() }
        }
    }

    private func observeStatus(of item: AVPlayerItem) {
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self?.isBuffering = false
                    self?.playbackErrorMessage = nil
                case .failed:
                    self?.stopWithError(item.error?.localizedDescription ?? "The audio stream could not be opened.")
                default:
                    break
                }
            }
        }
    }

    private func observeBuffering(of item: AVPlayerItem) {
        likelyToKeepUpObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in self?.isBuffering = !item.isPlaybackLikelyToKeepUp }
        }
        playbackBufferEmptyObserver = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in self?.isBuffering = item.isPlaybackBufferEmpty }
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            playbackErrorMessage = error.localizedDescription
        }
    }

    private func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isPlaying else { return }
                self.toggle()
            }
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying else { return }
                self.toggle()
            }
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                guard let self, self.duration > 0 else { return }
                self.seek(to: event.positionTime / self.duration)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        let playbackDuration = duration > 0 ? duration : currentTrack.duration
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentTrack.title,
            MPMediaItemPropertyArtist: currentTrack.artist,
            MPMediaItemPropertyAlbumTitle: currentTrack.album,
            MPMediaItemPropertyPlaybackDuration: playbackDuration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1 : 0,
            MPMediaItemPropertyArtwork: make999Artwork(for: currentTrack)
        ]
    }

    private func updateNowPlayingPlaybackState() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1 : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func make999Artwork(for track: Track) -> MPMediaItemArtwork {
        let size = CGSize(width: 720, height: 720)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let baseColor = UIColor(hexString: track.coverColorHex) ?? UIColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1)
            baseColor.setFill()
            context.fill(rect)

            UIColor.black.withAlphaComponent(0.24).setFill()
            context.fill(rect)

            let glow = UIColor.systemOrange.withAlphaComponent(0.22)
            glow.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: -120, y: 430, width: 520, height: 520))
            UIColor.systemPurple.withAlphaComponent(0.18).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 330, y: -80, width: 520, height: 520))

            let mark = "999"
            let markAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 52, weight: .black),
                .foregroundColor: UIColor.systemOrange.withAlphaComponent(0.34),
                .kern: 3
            ]
            let markSize = mark.size(withAttributes: markAttributes)
            mark.draw(at: CGPoint(x: (size.width - markSize.width) / 2, y: 18), withAttributes: markAttributes)

            let title = track.title.prefix(18).uppercased()
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 42, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
            ]
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 320), withAttributes: titleAttributes)

            let subtitle = "999 RADIO"
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.48),
                .kern: 4
            ]
            let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
            subtitle.draw(at: CGPoint(x: (size.width - subtitleSize.width) / 2, y: 376), withAttributes: subtitleAttributes)
        }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}

private extension UIColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        let red = CGFloat((value & 0xFF0000) >> 16) / 255
        let green = CGFloat((value & 0x00FF00) >> 8) / 255
        let blue = CGFloat(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
