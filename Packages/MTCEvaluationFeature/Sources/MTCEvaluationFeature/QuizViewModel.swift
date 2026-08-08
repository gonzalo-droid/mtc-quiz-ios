import Foundation
import MTCDomain
import Observation

@MainActor
@Observable
public final class QuizViewModel {
    public private(set) var state = QuizState()

    /// Called once, with the newly-saved evaluation's id, when finishQuiz() completes —
    /// the app shell uses this to navigate to Summary. Not part of `state` since it's a
    /// one-shot navigation signal, not persistent UI state.
    public var onFinished: ((String) -> Void)?

    private var results: [MTCDomain.QuestionResult] = []
    private let categoryId: String
    private let categoryRepository: CategoryRepository
    private let questionRepository: QuestionRepository
    private let evaluationRepository: EvaluationRepository
    private let preferencesRepository: PreferencesRepository

    public init(
        categoryId: String,
        categoryRepository: CategoryRepository,
        questionRepository: QuestionRepository,
        evaluationRepository: EvaluationRepository,
        preferencesRepository: PreferencesRepository
    ) {
        self.categoryId = categoryId
        self.categoryRepository = categoryRepository
        self.questionRepository = questionRepository
        self.evaluationRepository = evaluationRepository
        self.preferencesRepository = preferencesRepository
    }

    public var isLastQuestion: Bool {
        state.currentIndex == state.questions.count - 1
    }

    public func load() async {
        guard let category = await categoryRepository.category(withId: categoryId) else {
            state.isLoading = false
            return
        }

        let limit = await preferencesRepository.numberOfQuestions
        let questions = await questionRepository.questions(pathJson: category.pathJson, limit: limit)

        state = QuizState(
            questions: questions,
            currentQuestion: questions.first ?? MTCDomain.Question(),
            currentIndex: 0,
            category: category,
            isLoading: false
        )
    }

    public func selectOption(at index: Int) {
        guard !state.isAnswerVerified else { return }
        state.selectedOptionIndex = index
    }

    /// Records the QuestionResult here, at verification time — see the plan's "Key naming
    /// decisions" section for why this differs from Android's defer-to-Next/Finish-tap timing
    /// (same final recorded result, simpler state machine).
    public func verifyAnswer() {
        guard let index = state.selectedOptionIndex else { return }
        state.isAnswerVerified = true

        let question = state.currentQuestion
        let isCorrect = question.isCorrectAnswer(index)
        let selectedOption = question.options.indices.contains(index) ? question.options[index] : ""

        results.append(
            MTCDomain.QuestionResult(
                id: UUID().uuidString,
                questionId: question.id,
                question: question.title,
                option: selectedOption,
                isCorrect: isCorrect,
                correctAnswer: question.option(for: question.answer)
            )
        )
    }

    public func nextQuestion() {
        let next = state.currentIndex + 1
        guard state.questions.indices.contains(next) else { return }
        state.currentIndex = next
        state.currentQuestion = state.questions[next]
        state.selectedOptionIndex = nil
        state.isAnswerVerified = false
    }

    public func finishQuiz() async {
        let correct = results.filter(\.isCorrect).count
        let total = state.questions.count
        let incorrect = total - correct
        let percentage = total > 0 ? Int((Double(correct) / Double(total)) * 100) : 0
        let threshold = await preferencesRepository.passPercentage
        let outcome: EvaluationOutcome = percentage >= threshold ? .approved : .rejected

        let evaluation = MTCDomain.Evaluation(
            id: UUID().uuidString,
            categoryId: state.category.id,
            categoryTitle: state.category.title,
            totalCorrect: correct,
            totalIncorrect: incorrect,
            totalQuestions: total,
            outcome: outcome,
            date: Date(),
            questionResults: results
        )

        await evaluationRepository.save(evaluation)
        onFinished?(evaluation.id)
    }
}
