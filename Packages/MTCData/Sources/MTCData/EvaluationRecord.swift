import Foundation
import SwiftData

/// Mirrors Android's Room EvaluationEntity — same fields, questionResults stored as an
/// embedded JSON string (matches the Kotlin mapper's own JSON-blob approach) rather than
/// a SwiftData relationship, since nothing in this app's scope queries individual results.
@Model
public final class EvaluationRecord {
    @Attribute(.unique) public var id: String
    public var categoryId: String
    public var categoryTitle: String
    public var totalCorrect: Int
    public var totalIncorrect: Int
    public var totalQuestions: Int
    public var outcome: String
    public var date: Date
    public var questionResultsJSON: String

    public init(
        id: String,
        categoryId: String,
        categoryTitle: String,
        totalCorrect: Int,
        totalIncorrect: Int,
        totalQuestions: Int,
        outcome: String,
        date: Date,
        questionResultsJSON: String
    ) {
        self.id = id
        self.categoryId = categoryId
        self.categoryTitle = categoryTitle
        self.totalCorrect = totalCorrect
        self.totalIncorrect = totalIncorrect
        self.totalQuestions = totalQuestions
        self.outcome = outcome
        self.date = date
        self.questionResultsJSON = questionResultsJSON
    }
}
