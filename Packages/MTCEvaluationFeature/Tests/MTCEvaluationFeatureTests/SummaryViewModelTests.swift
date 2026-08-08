import Testing
import MTCDomain
@testable import MTCEvaluationFeature

@Suite @MainActor struct SummaryViewModelTests {
    private let category = MTCDomain.Category(
        id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
        description: "d", pdf: "p.pdf", pathJson: "a1_questions.json"
    )

    @Test func loadPopulatesCategoryAndEvaluation() async {
        let evaluationRepository = FakeEvaluationRepository()
        let evaluation = MTCDomain.Evaluation(
            id: "eval-1", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: 9, totalIncorrect: 1, totalQuestions: 10, outcome: .approved
        )
        await evaluationRepository.save(evaluation)

        let viewModel = SummaryViewModel(
            categoryId: "1",
            evaluationId: "eval-1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            evaluationRepository: evaluationRepository
        )

        await viewModel.load()

        #expect(viewModel.state.category == category)
        #expect(viewModel.state.evaluation?.id == "eval-1")
        #expect(viewModel.state.evaluation?.totalCorrect == 9)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadLeavesEvaluationNilWhenNotFound() async {
        let viewModel = SummaryViewModel(
            categoryId: "1",
            evaluationId: "missing-id",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            evaluationRepository: FakeEvaluationRepository()
        )

        await viewModel.load()

        #expect(viewModel.state.evaluation == nil)
        #expect(viewModel.state.isLoading == false)
    }
}
