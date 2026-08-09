import SwiftUI

extension Color {
    /// A fixed color, same value regardless of light/dark mode — the onboarding gradients are
    /// full-bleed colored backgrounds, not adaptive UI chrome, so there's no light/dark pair to
    /// pick between (same reasoning `PremiumView` already applies with its own fixed dark theme).
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
