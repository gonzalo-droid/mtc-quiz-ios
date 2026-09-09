import Testing
import Foundation
@testable import MTCEvaluationFeature

@Suite struct SummaryDateFormattingTests {
    @Test func formatsInSpanishRegardlessOfCurrentLocale() {
        // 2026-09-06 is a Sunday.
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 6
        components.timeZone = TimeZone(identifier: "America/Lima")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let formatted = spanishSummaryDate(date)

        #expect(formatted.contains("septiembre"))
        #expect(!formatted.contains("September"))
    }

    @Test func capitalizesTheFirstLetter() {
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 6
        components.timeZone = TimeZone(identifier: "America/Lima")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let formatted = spanishSummaryDate(date)

        let first = formatted.first
        #expect(first != nil && first!.isUppercase)
    }
}
