import SwiftUI

struct TrackRow: View {
    @Environment(RadioPlayer.self) private var player
    let track: Track
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TrackRowContent(track: track)
        }
        .disabled(!track.isPlayable)
        .buttonStyle(ScaleButtonStyle(scale: 0.99))
        .contextMenu {
            if track.isPlayable {
                Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                    player.playNext(track)
                }
                Button("Add to Queue", systemImage: "text.badge.plus") {
                    player.addToQueue(track)
                }
            }
            Button(player.likedIDs.contains(track.id) ? "Unlike" : "Like", systemImage: player.likedIDs.contains(track.id) ? "heart.slash" : "heart") {
                player.toggleLike(track.id)
            }
        }
    }
}

struct TrackRowContent: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            AsyncCover(track: track, size: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .opacity(track.isPlayable ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(track.isPlayable ? "\(track.artist) - \(track.album)" : "Audio unavailable")
                    .font(.caption)
                    .foregroundStyle(track.isPlayable ? .white.opacity(0.5) : .orange.opacity(0.8))
                    .lineLimit(1)
            }
            Spacer()
            if track.isPlayable {
                Text(formatTime(track.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.38))
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.75))
            }
        }
        .foregroundStyle(track.isPlayable ? .white : .white.opacity(0.45))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
