import Testing
@testable import MTCDesignSystem

@Suite struct AnswerOptionTests {
    @Test func idIsStableAcrossSeparateConstructionsWithTheSameLetter() {
        let first = AnswerOption(letter: "A", text: "Opción A", state: .unselected)
        let second = AnswerOption(letter: "A", text: "Opción A", state: .selected)
        #expect(first.id == second.id)
    }

    @Test func idDiffersForDifferentLetters() {
        let a = AnswerOption(letter: "A", text: "Opción A", state: .unselected)
        let b = AnswerOption(letter: "B", text: "Opción B", state: .unselected)
        #expect(a.id != b.id)
    }
}
