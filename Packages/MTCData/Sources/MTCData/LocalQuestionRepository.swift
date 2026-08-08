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

        if let limit {
            return Array(response.data.prefix(limit))
        }
        return response.data
    }
}
