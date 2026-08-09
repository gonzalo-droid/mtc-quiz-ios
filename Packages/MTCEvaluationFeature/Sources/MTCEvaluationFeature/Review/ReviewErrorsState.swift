public struct FrequentError: Equatable, Sendable, Identifiable {
    public let questionId: Int
    public let question: String
    public let failCount: Int
    public let lastWrongAnswer: String
    public let correctAnswer: String

    public init(questionId: Int, question: String, failCount: Int, lastWrongAnswer: String, correctAnswer: String) {
        self.questionId = questionId
        self.question = question
        self.failCount = failCount
        self.lastWrongAnswer = lastWrongAnswer
        self.correctAnswer = correctAnswer
    }

    public var id: Int { questionId }
}

public struct ReviewErrorsState: Equatable, Sendable {
    public var frequentErrors: [FrequentError]
    public var isLoading: Bool

    public init(frequentErrors: [FrequentError] = [], isLoading: Bool = true) {
        self.frequentErrors = frequentErrors
        self.isLoading = isLoading
    }
}
