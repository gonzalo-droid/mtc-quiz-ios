import Foundation
import MTCDomain

public final class LocalQuestionRepository: QuestionRepository {
    public init() {}

    public func questions(pathJson: String, limit: Int?) async -> [Question] {
        let filename = (pathJson as NSString).deletingPathExtension
        guard
            let url = Bundle.module.url(forResource: filename, withExtension: "json", subdirectory: "Questions"),
            let data = try? Data(contentsOf: url),
            let response = try? JSONDecoder().decode(QuestionResponse.self, from: data)
        else {
            return []
        }

        // A limited request is an evaluation: a random sample, so repeating the simulacro doesn't
        // replay the same questions — mirrors Android's `shuffled().take(numberQuestion)`
        // (e892b0f). An unlimited request is the study list and keeps the bank's own order.
        if let limit {
            return Array(response.data.shuffled().prefix(limit))
        }
        return response.data
    }
}
