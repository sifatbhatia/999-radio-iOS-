import Foundation
import SwiftUI

struct PillButtonStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(active ? .orange : .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(active ? .orange.opacity(0.18) : .clear, in: Capsule())
            .overlay(Capsule().stroke(active ? .orange : .white.opacity(0.2)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

extension Color {
    static let radioBackground = Color(red: 0.055, green: 0.048, blue: 0.043)

    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let r, g, b: UInt64
        switch sanitized.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            (r, g, b) = (143, 74, 47)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
