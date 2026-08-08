public struct QuestionResult: Codable, Equatable, Sendable {
    public let id: String
    public let questionId: Int
    public let question: String
    public let option: String?
    public let isCorrect: Bool
    public let correctAnswer: String

    public init(
        id: String,
        questionId: Int,
        question: String,
        option: String?,
        isCorrect: Bool,
        correctAnswer: String
    ) {
        self.id = id
        self.questionId = questionId
        self.question = question
        self.option = option
        self.isCorrect = isCorrect
        self.correctAnswer = correctAnswer
    }
}
