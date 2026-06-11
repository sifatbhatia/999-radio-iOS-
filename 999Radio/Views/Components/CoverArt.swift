import SwiftUI

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
