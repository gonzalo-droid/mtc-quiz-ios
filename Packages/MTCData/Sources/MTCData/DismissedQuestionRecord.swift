import Foundation
import SwiftData

/// Mirrors Android's Room DismissedQuestionEntity. `questionId` holds the error's key
/// (`FrequentError.key`: bank + PDF id + text), not the bare question id, which repeats across
/// banks and inside a3b/a3c — the same trick Android uses to avoid a schema change.
@Model
public final class DismissedQuestionRecord {
    @Attribute(.unique) public var questionId: Int

    public init(questionId: Int) {
        self.questionId = questionId
    }
}
