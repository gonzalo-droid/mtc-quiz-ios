import Testing
@testable import MTCEvaluationFeature
import MTCDomain

/// The primary button ("Verificar" / "Siguiente" / "Finalizar") is only usable when there is
/// something to act on. Android greys it out until an option is picked; iOS had the same rule but
/// no visual sign of it, so the button looked tappable and silently did nothing.
@Suite struct QuizStateCanSubmitTests {
    private let question = MTCDomain.Question(id: 1)

    @Test func cannotSubmitWithoutAnAnswer() {
        let state = QuizState(questions: [question], currentQuestion: question)
        #expect(state.canSubmit == false)
    }

    @Test func canSubmitOnceAnOptionIsSelected() {
        let state = QuizState(questions: [question], currentQuestion: question, selectedOptionIndex: 2)
        #expect(state.canSubmit == true)
    }

    @Test func canStillSubmitAfterVerifying() {
        let state = QuizState(
            questions: [question], currentQuestion: question,
            selectedOptionIndex: 2, isAnswerVerified: true
        )
        #expect(state.canSubmit == true)
    }

    @Test func cannotSubmitWhileFinishing() {
        let state = QuizState(
            questions: [question], currentQuestion: question,
            selectedOptionIndex: 2, isFinishing: true
        )
        #expect(state.canSubmit == false)
    }
}
