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
