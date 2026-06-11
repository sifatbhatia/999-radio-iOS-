import SwiftUI

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

struct StatChip: View {
    let title: String
    let value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map(String.init) ?? "-")
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
