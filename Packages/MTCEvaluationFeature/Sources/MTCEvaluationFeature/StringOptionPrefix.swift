import Foundation

extension String {
    /// Strips a leading "a) "/"b) "/"c) "/"d) " (case-insensitive) — the option text from the
    /// JSON already includes this prefix, but the UI shows the letter separately via the row's
    /// own badge, so the prefix would otherwise be shown twice. Matches Android's
    /// stripOptionLetterPrefix() exactly.
    func strippingOptionLetterPrefix() -> String {
        replacing(#/^[a-dA-D]\)\s*/#, with: "")
    }
}
