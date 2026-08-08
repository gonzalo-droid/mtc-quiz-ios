import Testing
@testable import MTCData

@Suite struct LocalQuestionRepositoryTests {
    @Test func questionsLoadsRealBundledFileInFileOrderWithNoLimit() async {
        let repository = LocalQuestionRepository()
        let questions = await repository.questions(pathJson: "a1_questions.json", limit: nil)
        #expect(questions.count == 200) // a1_questions.json has 200 questions, confirmed against the real file
        #expect(questions.first?.id == 1)
    }

    @Test func questionsRespectsLimitByTakingThePrefixNoShuffle() async {
        let repository = LocalQuestionRepository()
        let questions = await repository.questions(pathJson: "a1_questions.json", limit: 5)
        #expect(questions.count == 5)
        #expect(questions.map(\.id) == [1, 2, 3, 4, 5])
    }

    @Test func questionsReturnsEmptyForUnknownFile() async {
        let repository = LocalQuestionRepository()
        let questions = await repository.questions(pathJson: "no_existe_questions.json", limit: nil)
        #expect(questions.isEmpty)
    }
}
