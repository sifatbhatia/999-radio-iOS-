import SwiftUI

struct MiniPlayer: View {
    @Environment(RadioPlayer.self) private var player
    @Binding var showPlayer: Bool
    @State private var isPressed = false

    var body: some View {
        if let track = player.currentTrack {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    showPlayer = true
                }
            } label: {
                HStack(spacing: 12) {
                    AsyncCover(track: track, size: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title).font(.subheadline.bold()).lineLimit(1)
                            .contentTransition(.opacity)
                        Text(track.artist).font(.caption).foregroundStyle(.white.opacity(0.54)).lineLimit(1)
                            .contentTransition(.opacity)
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
                .scaleEffect(isPressed ? 0.985 : 1)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isPressed)
            .animation(.smooth(duration: 0.22), value: track.id)
        }
    }
}
