import MTCDomain

final class FakeQuestionRepository: QuestionRepository {
    var questionsToReturn: [MTCDomain.Question]

    init(questionsToReturn: [MTCDomain.Question] = []) {
        self.questionsToReturn = questionsToReturn
    }

    func questions(pathJson: String, limit: Int?) async -> [MTCDomain.Question] {
        if let limit {
            return Array(questionsToReturn.prefix(limit))
        }
        return questionsToReturn
    }
}
