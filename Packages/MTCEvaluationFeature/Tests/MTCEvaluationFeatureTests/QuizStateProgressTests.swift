import Testing
@testable import MTCEvaluationFeature
import MTCDomain

/// Mirrors Android's `progress` in `EvaluationScreen.kt`: position among the questions, from 0 on
/// the first to 1 on the last — `index / (count - 1)`, clamped to 0...1, and 0 when there are fewer
/// than two questions.
@Suite struct QuizStateProgressTests {
    private func state(count: Int, index: Int) -> QuizState {
        QuizState(questions: (0..<count).map { MTCDomain.Question(id: $0 + 1) }, currentIndex: index)
    }

    @Test(arguments: [
        (40, 0, 0.0),        // first question: empty bar
        (40, 39, 1.0),       // last question: full bar
        (40, 19, 19.0 / 39), // in between: position over the last index
        (2, 1, 1.0),
        (1, 0, 0.0),         // a single question never fills the bar, as on Android
        (0, 0, 0.0),         // still loading
        (5, 7, 1.0),         // an out-of-range index is clamped, never above 1
    ])
    func progressIsThePositionAmongTheQuestions(count: Int, index: Int, expected: Double) {
        #expect(abs(state(count: count, index: index).progress - expected) < 0.000_001)
    }
}
