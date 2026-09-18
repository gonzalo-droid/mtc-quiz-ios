import SwiftUI

public enum MTCColor {
    /// Ported from Color.kt: primaryLight/primaryDark.
    public static let primary = Color(light: "#3949AB", dark: "#B6C4FF")
    /// Ported from Color.kt: onPrimaryLight/onPrimaryDark — readable text/icon color on top of `primary`.
    public static let onPrimary = Color(light: "#FFFFFF", dark: "#08218A")
    /// Ported from Color.kt: tertiaryLight/tertiaryDark (used for the streak flame).
    public static let amber = Color(light: "#785900", dark: "#F5BF48")

    /// Android's premium gold gradient (0xFFFFB300 → 0xFFFF8F00): the paywall, the Home crown and
    /// the Settings premium row. Fixed values — Android doesn't vary them by theme either.
    public static let premiumGold = Color(hex: "#FFB300")
    public static let premiumAmber = Color(hex: "#FF8F00")
    /// Text/icons on top of the premium gold. Android uses white there, but white on #FFB300 is
    /// 1.79:1 — below even WCAG's 3:1 for large bold text. This is the paywall's own dark
    /// (#1A1A2E): 9.5:1 on gold, 7.5:1 on amber.
    public static let onPremiumGold = Color(hex: "#1A1A2E")

    public struct CategoryPalette: Sendable {
        public let container: Color
        public let content: Color
    }

    /// Ported verbatim from CategoryColors.kt's categoryColorMap — 9 entries, one per
    /// license category code. Fixed values (not light/dark pairs): Android doesn't vary
    /// these by theme either.
    private static let categoryPalettes: [String: CategoryPalette] = [
        "A-I": CategoryPalette(container: Color(hex: "#274C93"), content: .white),
        "A-IIa": CategoryPalette(container: Color(hex: "#3461B3"), content: .white),
        "A-IIb": CategoryPalette(container: Color(hex: "#3F76D6"), content: .white),
        "A-IIIa": CategoryPalette(container: Color(hex: "#5C8CE0"), content: .white),
        "A-IIIb": CategoryPalette(container: Color(hex: "#7BA3E8"), content: Color(hex: "#12233F")),
        "A-IIIc": CategoryPalette(container: Color(hex: "#9EBCEF"), content: Color(hex: "#12233F")),
        "B-IIa": CategoryPalette(container: Color(hex: "#B5651D"), content: .white),
        "B-IIb": CategoryPalette(container: Color(hex: "#D07A2B"), content: .white),
        "B-IIc": CategoryPalette(container: Color(hex: "#E89A4D"), content: Color(hex: "#12233F")),
    ]

    /// Falls back to `primary`/`.white` for an unknown code — mirrors the `fallback`
    /// parameter Android's `categoryColors(category:fallback:)` requires callers to supply.
    public static func categoryPalette(for code: String) -> CategoryPalette {
        categoryPalettes[code] ?? CategoryPalette(container: primary, content: .white)
    }
}
