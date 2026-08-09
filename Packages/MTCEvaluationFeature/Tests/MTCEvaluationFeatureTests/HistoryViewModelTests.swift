import Testing
import Foundation
import MTCDomain
@testable import MTCEvaluationFeature

@Suite @MainActor struct HistoryViewModelTests {
    private func makeEvaluation(id: String, date: Date) -> MTCDomain.Evaluation {
        MTCDomain.Evaluation(
            id: id, categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: 8, totalIncorrect: 2, totalQuestions: 10,
            outcome: .approved, date: date
        )
    }

    @Test func stateStartsLoadingWithNoEvaluations() {
        let viewModel = HistoryViewModel(evaluationRepository: FakeEvaluationRepository())
        #expect(viewModel.state.isLoading == true)
        #expect(viewModel.state.evaluations.isEmpty)
    }

    @Test func loadPopulatesEvaluationsInRepositoryOrder() async {
        let repository = FakeEvaluationRepository()
        repository.evaluationsToReturn = [
            makeEvaluation(id: "newer", date: Date(timeIntervalSince1970: 2_000_000_000)),
            makeEvaluation(id: "older", date: Date(timeIntervalSince1970: 1_000_000_000)),
        ]
        let viewModel = HistoryViewModel(evaluationRepository: repository)

        await viewModel.load()

        #expect(viewModel.state.evaluations.map(\.id) == ["newer", "older"])
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadLeavesEmptyStateWhenNoEvaluationsExist() async {
        let viewModel = HistoryViewModel(evaluationRepository: FakeEvaluationRepository())
        await viewModel.load()
        #expect(viewModel.state.evaluations.isEmpty)
        #expect(viewModel.state.isLoading == false)
    }
}
