import SwiftUI

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
                                .contentTransition(.symbolEffect(.replace))
                        }
                        VStack(spacing: 4) {
                            Text(track.title)
                                .font(.title3.bold())
                                .lineLimit(1)
                                .contentTransition(.opacity)
                            Text(track.artist)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                                .contentTransition(.opacity)
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
                                .contentTransition(.symbolEffect(.replace))
                        }
                        Button { player.previous() } label: { Image(systemName: "backward.fill") }
                        Button { player.toggle() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title.bold())
                                .frame(width: player.isPlaying ? 72 : 68, height: player.isPlaying ? 56 : 68)
                                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: player.isPlaying ? 18 : 34, style: .continuous))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        Button { player.next() } label: { Image(systemName: "forward.fill") }
                        Button { player.cycleRepeatMode() } label: {
                            Image(systemName: player.repeatMode.systemImage)
                                .foregroundStyle(player.repeatMode == .off ? .white.opacity(0.5) : .orange)
                                .contentTransition(.symbolEffect(.replace))
                        }
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
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if showQueue {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Up Next").font(.headline)
                                Spacer()
                                Button("Clear") { player.clearQueue() }
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                            ForEach(player.upNext()) { track in
                                HStack {
                                    Button { player.play(track, from: player.queue) } label: {
                                        Text(track.title)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 3)
                                    }
                                    Button { player.removeFromQueue(track) } label: {
                                        Image(systemName: "minus.circle")
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer(minLength: 8)
                }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: showLyrics)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: showQueue)
        .animation(.smooth(duration: 0.22), value: player.currentTrack?.id)
        .background(Color.radioBackground.ignoresSafeArea())
    }
}
