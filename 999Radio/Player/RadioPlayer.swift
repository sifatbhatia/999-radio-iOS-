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
    var isShuffle = false {
        didSet { persistence.isShuffle = isShuffle }
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
        didSet { persistence.savedQueue = queue }
    }
    var likedIDs: Set<String> = [] {
        didSet { persistence.likedIDs = likedIDs }
    }
    var recentlyPlayed: [Track] = []

    @ObservationIgnored private let persistence = RadioPersistence()
    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private let feedback = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private var lastTrackID: String?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    init() {
        likedIDs = persistence.likedIDs
        isShuffle = persistence.isShuffle
        repeatMode = persistence.repeatMode
        volume = persistence.volume
        recentlyPlayed = persistence.recentlyPlayed
        queue = persistence.savedQueue
        currentTrack = persistence.currentTrack
        player.volume = Float(volume)
        configureAudioSession()
        configureRemoteCommands()
        feedback.prepare()
    }

    func play(_ track: Track, from tracks: [Track]) {
        feedback.impactOccurred(intensity: 0.55)
        currentTrack = track
        queue = tracks
        persistence.currentTrack = track
        recordRecentlyPlayed(track)
        configureIfNeeded(track)
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
        Task.detached { await JuiceAPI.trackPlay(track) }
    }

    func toggle() {
        feedback.impactOccurred(intensity: 0.35)
        if isPlaying {
            player.pause()
        } else {
            configureIfNeeded(currentTrack)
            player.play()
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
    }

    func next() {
        feedback.impactOccurred(intensity: 0.45)
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
        feedback.impactOccurred(intensity: 0.45)
        guard let currentTrack, !queue.isEmpty else { return }
        let index = queue.firstIndex(of: currentTrack) ?? 0
        let previousIndex = index == 0 ? queue.count - 1 : index - 1
        play(queue[previousIndex], from: queue)
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
        guard let currentTrack, !queue.isEmpty else { return [] }
        let start = (queue.firstIndex(of: currentTrack) ?? 0) + 1
        return (0..<min(limit, queue.count)).map { queue[(start + $0) % queue.count] }
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
        guard let currentTrack, !queue.isEmpty else {
            queue = [track]
            return
        }
        queue.removeAll { $0.id == track.id }
        let currentIndex = queue.firstIndex(of: currentTrack) ?? 0
        queue.insert(track, at: min(currentIndex + 1, queue.count))
    }

    func addToQueue(_ track: Track) {
        feedback.impactOccurred(intensity: 0.35)
        guard !queue.contains(where: { $0.id == track.id }) else { return }
        queue.append(track)
    }

    func removeFromQueue(_ track: Track) {
        feedback.impactOccurred(intensity: 0.3)
        queue.removeAll { $0.id == track.id }
    }

    func clearQueue() {
        feedback.impactOccurred(intensity: 0.3)
        queue = currentTrack.map { [$0] } ?? []
    }

    private func recordRecentlyPlayed(_ track: Track) {
        recentlyPlayed.removeAll { $0.id == track.id }
        recentlyPlayed.insert(track, at: 0)
        recentlyPlayed = Array(recentlyPlayed.prefix(25))
        persistence.recentlyPlayed = recentlyPlayed
    }

    private func configureIfNeeded(_ track: Track?) {
        guard let track, lastTrackID != track.id else { return }
        lastTrackID = track.id
        progress = 0
        duration = track.duration
        guard let url = JuiceAPI.mediaURL(for: track) else { return }
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        observeEnd(of: item)
    }

    private func handleTrackEnded() {
        guard let currentTrack else { return }
        if repeatMode == .one {
            seek(to: 0)
            player.play()
            isPlaying = true
            return
        }

        if repeatMode == .off, queue.last == currentTrack, !isShuffle {
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

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Playback still works in-app if the session cannot be activated yet.
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
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentTrack.title,
            MPMediaItemPropertyArtist: currentTrack.artist,
            MPMediaItemPropertyAlbumTitle: currentTrack.album,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : currentTrack.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1 : 0
        ]
    }

    private func updateNowPlayingPlaybackState() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1 : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
