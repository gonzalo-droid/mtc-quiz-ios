import Foundation
import SwiftData

/// Mirrors Android's Room DismissedQuestionEntity — a bare table of dismissed question ids.
@Model
public final class DismissedQuestionRecord {
    @Attribute(.unique) public var questionId: Int

    public init(questionId: Int) {
        self.questionId = questionId
    }
}
