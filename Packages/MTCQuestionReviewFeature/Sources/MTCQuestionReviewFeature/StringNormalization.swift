import Foundation

extension String {
    /// Accent- and case-insensitive normalization, matching Android's `normalizeText()`
    /// exactly (NFD-strip-diacritics + lowercase): strip diacritics, then lowercase.
    func normalizedForSearch() -> String {
        folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
}
