import SwiftUI

struct FullPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RadioPlayer.self) private var player
    @State private var drawer: PlayerDrawer = .upNext

    var body: some View {
        @Bindable var player = player
        ZStack {
            Color.radioBackground.ignoresSafeArea()

            if let track = player.currentTrack {
                CoverBackdrop(track: track)
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            topBar
                            artwork(track, maxWidth: proxy.size.width)
                            metadata(track)
                            scrubber(track)
                            transportControls
                            volumeControl
                            drawerPicker(track)
                            drawerContent(track)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 14)
                        .padding(.bottom, 34)
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                emptyState
                    .padding(24)
            }
        }
        .animation(.smooth(duration: 0.22), value: player.currentTrack?.id)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: drawer)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.slash")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.86))
            Text("Nothing Playing")
                .font(.title2.bold())
            Text(player.playbackErrorMessage ?? "Pick a playable song from Library to start 999 Radio.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.58))
            Button("Back to Library") { dismiss() }
                .font(.headline)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(Color.accentOrange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.bold())
                    .frame(width: 38, height: 38)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("999 Radio")
                    .font(.subheadline.bold())
                Text("Now Playing")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            ShareLink(item: player.currentTrack?.title ?? "999 Radio") {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline)
                    .frame(width: 38, height: 38)
            }
        }
        .foregroundStyle(.white.opacity(0.86))
    }

    private func artwork(_ track: Track, maxWidth: CGFloat) -> some View {
        let size = min(maxWidth - 70, 300)
        return AsyncCover(track: track, size: max(210, size))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.42), radius: 24, y: 14)
            .scaleEffect(player.isPlaying ? 1 : 0.97)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: player.isPlaying)
    }

    private func metadata(_ track: Track) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(track.title)
                    .font(.title3.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .contentTransition(.opacity)
                Text(track.artist)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            Spacer()
            Button { player.toggleLike(track.id) } label: {
                Image(systemName: player.likedIDs.contains(track.id) ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(player.likedIDs.contains(track.id) ? Color.accentOrange : .white.opacity(0.48))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 40, height: 40)
            }
        }
    }

    private func scrubber(_ track: Track) -> some View {
        VStack(spacing: 6) {
            Slider(value: Binding(
                get: { player.duration > 0 ? min(max(player.progress / player.duration, 0), 1) : 0 },
                set: { player.seek(to: $0) }
            ), in: 0...1)
            .tint(Color.accentOrange)
            HStack {
                Text(formatTime(player.progress))
                Spacer()
                Text(formatTime(player.duration > 0 ? player.duration : track.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.44))
        }
    }

    private var transportControls: some View {
        HStack(spacing: 22) {
            Button { player.isShuffle.toggle() } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(player.isShuffle ? Color.accentOrange : .white.opacity(0.48))
            }
            Button { player.previous() } label: {
                Image(systemName: "backward.fill")
            }
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title.bold())
                    .frame(width: 70, height: 58)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentTransition(.symbolEffect(.replace))
            }
            Button { player.next() } label: {
                Image(systemName: "forward.fill")
            }
            Button { player.cycleRepeatMode() } label: {
                Image(systemName: player.repeatMode.systemImage)
                    .foregroundStyle(player.repeatMode == .off ? .white.opacity(0.48) : Color.accentOrange)
            }
        }
        .font(.title2.bold())
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }

    private var volumeControl: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
            Slider(value: Binding(
                get: { player.volume },
                set: { player.volume = $0 }
            ), in: 0...1)
            Image(systemName: "speaker.wave.2.fill")
        }
        .tint(.white.opacity(0.78))
        .foregroundStyle(.white.opacity(0.42))
    }

    private func drawerPicker(_ track: Track) -> some View {
        Picker("Player Drawer", selection: $drawer) {
            Text("Up Next").tag(PlayerDrawer.upNext)
            Text("Lyrics").tag(PlayerDrawer.lyrics)
        }
        .pickerStyle(.segmented)
        .onChange(of: track.id) { _, _ in
            if drawer == .lyrics, track.lyrics == nil { drawer = .upNext }
        }
    }

    @ViewBuilder
    private func drawerContent(_ track: Track) -> some View {
        switch drawer {
        case .upNext:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Up Next").font(.headline)
                    Spacer()
                    Button("Clear") { player.clearQueue() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                let upNext = player.upNext(limit: 8)
                if upNext.isEmpty {
                    Text("No more playable songs queued.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.46))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                } else {
                    ForEach(upNext) { item in
                        HStack(spacing: 10) {
                            AsyncCover(track: item, size: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Button { player.play(item, from: player.queue) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text(item.artist)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.42))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Button { player.removeFromQueue(item) } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.white.opacity(0.38))
                            }
                        }
                    }
                }
            }
            .playerDrawerStyle()
        case .lyrics:
            ScrollView {
                Text(track.lyrics ?? "No lyrics available.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.callout)
                    .lineSpacing(5)
                    .foregroundStyle(.white.opacity(track.lyrics == nil ? 0.42 : 0.84))
            }
            .frame(minHeight: 120, maxHeight: 260)
            .playerDrawerStyle()
        }
    }
}

private enum PlayerDrawer {
    case upNext
    case lyrics
}

private extension View {
    func playerDrawerStyle() -> some View {
        padding(14)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.06)))
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
