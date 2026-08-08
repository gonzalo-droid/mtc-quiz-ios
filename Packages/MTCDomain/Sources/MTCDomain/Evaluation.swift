import Foundation

public struct Evaluation: Equatable, Sendable {
    public let id: String
    public let categoryId: String
    public let categoryTitle: String
    public let totalCorrect: Int
    public let totalIncorrect: Int
    public let totalQuestions: Int
    public var outcome: EvaluationOutcome
    public let date: Date
    public let questionResults: [QuestionResult]

    public init(
        id: String = "",
        categoryId: String = "",
        categoryTitle: String = "",
        totalCorrect: Int = 0,
        totalIncorrect: Int = 0,
        totalQuestions: Int = 0,
        outcome: EvaluationOutcome = .approved,
        date: Date = Date(),
        questionResults: [QuestionResult] = []
    ) {
        self.id = id
        self.categoryId = categoryId
        self.categoryTitle = categoryTitle
        self.totalCorrect = totalCorrect
        self.totalIncorrect = totalIncorrect
        self.totalQuestions = totalQuestions
        self.outcome = outcome
        self.date = date
        self.questionResults = questionResults
    }
}

public enum EvaluationOutcome: String, Equatable, Sendable {
    case approved
    case rejected
}
