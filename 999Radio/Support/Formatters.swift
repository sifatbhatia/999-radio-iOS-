import Foundation

func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite else { return "0:00" }
    let total = max(0, Int(seconds.rounded()))
    return "\(total / 60):\(String(format: "%02d", total % 60))"
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
