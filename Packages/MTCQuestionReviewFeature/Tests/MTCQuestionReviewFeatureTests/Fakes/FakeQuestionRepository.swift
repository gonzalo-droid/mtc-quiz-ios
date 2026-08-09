import MTCDomain

final class FakeQuestionRepository: QuestionRepository {
    var questionsToReturn: [MTCDomain.Question]
    /// nil = never called; .some(nil) = called with limit: nil; .some(.some(n)) = called with limit: n
    private(set) var receivedLimit: Int??

    init(questionsToReturn: [MTCDomain.Question] = []) {
        self.questionsToReturn = questionsToReturn
    }

    func questions(pathJson: String, limit: Int?) async -> [MTCDomain.Question] {
        receivedLimit = limit
        if let limit {
            return Array(questionsToReturn.prefix(limit))
        }
        return questionsToReturn
    }
}
