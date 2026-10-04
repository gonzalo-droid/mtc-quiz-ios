import Testing
@testable import MTCEvaluationFeature
import MTCDomain

/// The evaluation screen's visible text, held to Android's `EvaluationScreen.kt` wording.
@Suite struct QuizStateLabelsTests {
    private func state(count: Int, index: Int, verified: Bool = false, title: String = "¿Pregunta?") -> QuizState {
        let questions = (0..<count).map { MTCDomain.Question(id: 100 + $0, title: title) }
        return QuizState(
            questions: questions,
            currentQuestion: questions.indices.contains(index) ? questions[index] : MTCDomain.Question(),
            currentIndex: index,
            isAnswerVerified: verified
        )
    }

    @Test(arguments: [
        (40, 0, "1/40"),
        (40, 39, "40/40"),
        (1, 0, "1/1"),
    ])
    func positionTextIsOneBasedOverTheTotal(count: Int, index: Int, expected: String) {
        #expect(state(count: count, index: index).positionText == expected)
    }

    @Test func questionTitleIsPrefixedWithItsPositionNotItsId() {
        // Question ids start at 100 here, so an id-based prefix would read "103.- ".
        let quiz = state(count: 5, index: 3, title: "¿Qué indica la señal?")
        #expect(quiz.numberedQuestionTitle == "4.- ¿Qué indica la señal?")
    }

    @Test(arguments: [
        (5, 0, false, "Verificar"),
        (5, 4, false, "Verificar"),            // last question, not yet verified
        (5, 0, true, "Siguiente"),
        (5, 3, true, "Siguiente"),             // second to last
        (5, 4, true, "Terminar evaluación"),   // last question, verified
        (1, 0, true, "Terminar evaluación"),   // a single question is also the last
    ])
    func primaryButtonTitleFollowsAndroidsWording(count: Int, index: Int, verified: Bool, expected: String) {
        #expect(state(count: count, index: index, verified: verified).primaryButtonTitle == expected)
    }
}
