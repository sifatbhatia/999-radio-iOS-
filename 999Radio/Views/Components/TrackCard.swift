import SwiftUI

struct TrackCard: View {
    @Environment(RadioPlayer.self) private var player
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
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .transition(.scale(scale: 0.98).combined(with: .opacity))
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
