import MTCDomain

public struct QuizState: Equatable, Sendable {
    public var questions: [MTCDomain.Question]
    public var currentQuestion: MTCDomain.Question
    public var currentIndex: Int
    public var selectedOptionIndex: Int?
    public var isAnswerVerified: Bool
    public var category: MTCDomain.Category
    public var isLoading: Bool
    /// True once `finishQuiz()` has been triggered (re-entrancy guard). Once set, it never
    /// resets — the owning `QuizViewModel` instance is done with its job as soon as
    /// `finishQuiz()` completes and navigates away. The view uses this to disable the
    /// "Finalizar" button and to stop the countdown timer from firing a second finish.
    public var isFinishing: Bool

    public init(
        questions: [MTCDomain.Question] = [],
        currentQuestion: MTCDomain.Question = MTCDomain.Question(),
        currentIndex: Int = 0,
        selectedOptionIndex: Int? = nil,
        isAnswerVerified: Bool = false,
        category: MTCDomain.Category = MTCDomain.Category(
            id: "", title: "", category: "", classType: "", description: "", pdf: "", pathJson: ""
        ),
        isLoading: Bool = true,
        isFinishing: Bool = false
    ) {
        self.questions = questions
        self.currentQuestion = currentQuestion
        self.currentIndex = currentIndex
        self.selectedOptionIndex = selectedOptionIndex
        self.isAnswerVerified = isAnswerVerified
        self.category = category
        self.isLoading = isLoading
        self.isFinishing = isFinishing
    }
}

public extension QuizState {
    /// Whether the primary button has anything to act on: an option must be picked before
    /// "Verificar", and nothing is actionable once the evaluation is being saved. Same rule
    /// Android uses to grey its button out.
    var canSubmit: Bool {
        selectedOptionIndex != nil && !isFinishing
    }

    /// How far through the evaluation the user is, for the progress bar: 0 on the first question,
    /// 1 on the last. Mirrors Android's `EvaluationScreen.kt` exactly — `index / (count - 1)`,
    /// clamped to 0...1, and 0 with fewer than two questions.
    var progress: Double {
        guard questions.count > 1 else { return 0 }
        return min(max(Double(currentIndex) / Double(questions.count - 1), 0), 1)
    }
}
