import Testing
@testable import MTCData

@Suite struct LocalQuestionRepositoryTests {
    @Test func questionsLoadsRealBundledFileInFileOrderWithNoLimit() async {
        let repository = LocalQuestionRepository()
        let questions = await repository.questions(pathJson: "a1_questions.json", limit: nil)
        #expect(questions.count == 200) // a1_questions.json has 200 questions, confirmed against the real file
        #expect(questions.first?.id == 1)
    }

    @Test func questionsWithLimitReturnsThatManyDistinctQuestionsFromTheBank() async {
        let repository = LocalQuestionRepository()
        let bankIds = Set(await repository.questions(pathJson: "a1_questions.json", limit: nil).map(\.id))
        let questions = await repository.questions(pathJson: "a1_questions.json", limit: 5)
        #expect(questions.count == 5)
        #expect(Set(questions.map(\.id)).count == 5)
        #expect(Set(questions.map(\.id)).isSubset(of: bankIds))
    }

    /// Regression guard for the "same questions every evaluation" bug — mirrors Android's
    /// `getQuestionsByCategory returns a different selection across repeated evaluations`
    /// (e892b0f). With 200 questions and a random 5-question sample, getting the identical
    /// selection on all 20 runs only happens if the shuffle is missing or broken, not by chance.
    @Test func questionsWithLimitReturnsADifferentSelectionAcrossRepeatedEvaluations() async {
        let repository = LocalQuestionRepository()
        var selections = Set<[Int]>()
        for _ in 1...20 {
            selections.insert(await repository.questions(pathJson: "a1_questions.json", limit: 5).map(\.id))
        }
        #expect(selections.count > 1)
    }

    @Test func questionsReturnsEmptyForUnknownFile() async {
        let repository = LocalQuestionRepository()
        let questions = await repository.questions(pathJson: "no_existe_questions.json", limit: nil)
        #expect(questions.isEmpty)
    }
}
