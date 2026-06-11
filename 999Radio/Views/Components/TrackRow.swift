import SwiftUI

struct TrackRow: View {
    @Environment(RadioPlayer.self) private var player
    let track: Track
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TrackRowContent(track: track)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.99))
        .contextMenu {
            Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                player.playNext(track)
            }
            Button("Add to Queue", systemImage: "text.badge.plus") {
                player.addToQueue(track)
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
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(track.artist) - \(track.album)")
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
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
