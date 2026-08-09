import Testing
import MTCDomain
@testable import MTCQuestionReviewFeature

@Suite @MainActor struct QuestionReviewViewModelTests {
    private let category = MTCDomain.Category(
        id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
        description: "d", pdf: "p.pdf", pathJson: "a1_questions.json"
    )

    private func makeQuestion(id: Int, title: String) -> MTCDomain.Question {
        MTCDomain.Question(
            id: id, topic: "t", title: title, answer: "c",
            options: ["a) A", "b) B", "c) C", "d) D"]
        )
    }

    private func makeViewModel(questions: [MTCDomain.Question]) -> QuestionReviewViewModel {
        QuestionReviewViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            questionRepository: FakeQuestionRepository(questionsToReturn: questions)
        )
    }

    @Test func stateStartsLoadingWithNoQuestions() {
        let viewModel = makeViewModel(questions: [])
        #expect(viewModel.state.isLoading == true)
        #expect(viewModel.state.questions.isEmpty)
    }

    @Test func loadPopulatesAllQuestionsWithoutLimit() async {
        let questions = (1...5).map { makeQuestion(id: $0, title: "Pregunta \($0)") }
        let questionRepository = FakeQuestionRepository(questionsToReturn: questions)
        let viewModel = QuestionReviewViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            questionRepository: questionRepository
        )

        await viewModel.load()

        #expect(viewModel.state.questions.count == 5)
        #expect(viewModel.state.category == category)
        #expect(viewModel.state.isLoading == false)
        #expect(questionRepository.receivedLimit == .some(nil))
    }

    @Test func loadLeavesQuestionsEmptyWhenCategoryNotFound() async {
        let viewModel = QuestionReviewViewModel(
            categoryId: "missing-id",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            questionRepository: FakeQuestionRepository(questionsToReturn: [makeQuestion(id: 1, title: "x")])
        )

        await viewModel.load()

        #expect(viewModel.state.category == nil)
        #expect(viewModel.state.questions.isEmpty)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func filteredQuestionsMatchesWhenSearchTextIsEmpty() async {
        let questions = [
            makeQuestion(id: 1, title: "Señales de tránsito"),
            makeQuestion(id: 2, title: "Límites de velocidad"),
        ]
        let viewModel = makeViewModel(questions: questions)
        await viewModel.load()

        #expect(viewModel.filteredQuestions.count == 2)
    }

    @Test func filteredQuestionsMatchesSubstringCaseInsensitive() async {
        let questions = [
            makeQuestion(id: 1, title: "Señales de Tránsito"),
            makeQuestion(id: 2, title: "Límites de velocidad"),
        ]
        let viewModel = makeViewModel(questions: questions)
        await viewModel.load()

        viewModel.updateSearchText("señales")

        #expect(viewModel.filteredQuestions.map(\.id) == [1])
    }

    @Test func filteredQuestionsIgnoresAccents() async {
        let questions = [
            makeQuestion(id: 1, title: "Código de tránsito"),
            makeQuestion(id: 2, title: "Otro tema"),
        ]
        let viewModel = makeViewModel(questions: questions)
        await viewModel.load()

        viewModel.updateSearchText("codigo")

        #expect(viewModel.filteredQuestions.map(\.id) == [1])
    }

    @Test func filteredQuestionsIsEmptyWhenNoMatch() async {
        let questions = [makeQuestion(id: 1, title: "Señales de tránsito")]
        let viewModel = makeViewModel(questions: questions)
        await viewModel.load()

        viewModel.updateSearchText("xyz-no-match")

        #expect(viewModel.filteredQuestions.isEmpty)
    }
}
