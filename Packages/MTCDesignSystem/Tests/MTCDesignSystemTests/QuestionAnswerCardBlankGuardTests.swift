import Testing
@testable import MTCDesignSystem

@Suite struct QuestionAnswerCardBlankGuardTests {
    @Test func leavesAlreadyCanonicalBlanksUntouched() {
        let title = "El plazo es de __________ días."
        #expect(title.withVisibleBlanks() == title)
    }

    @Test func replacesARunOfNonBreakingSpacesWithTheCanonicalMarker() {
        let title = "El plazo es de \u{00a0}\u{00a0}\u{00a0}\u{00a0}\u{00a0} días."
        #expect(title.withVisibleBlanks() == "El plazo es de __________ días.")
    }

    @Test func replacesAShortOrLongUnderscoreRunWithTheCanonicalMarker() {
        #expect("El plazo es de ____ días.".withVisibleBlanks() == "El plazo es de __________ días.")
        #expect("El plazo es de ________________ días.".withVisibleBlanks() == "El plazo es de __________ días.")
    }

    @Test func insertsASpaceWhenTheBlankSitsFlushAgainstThePrecedingWord() {
        #expect("El plazo es de:____________días.".withVisibleBlanks() == "El plazo es de: __________ días.")
    }

    @Test func leavesShortUnderscoreRunsAlone() {
        // 3 or fewer underscores is not treated as a blank marker (matches Android's {4,} bound).
        let title = "Código A_B_C sin cambios"
        #expect(title.withVisibleBlanks() == title)
    }
}
