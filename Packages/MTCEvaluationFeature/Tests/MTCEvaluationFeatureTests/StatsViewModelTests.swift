import Testing
import Foundation
import MTCDomain
@testable import MTCEvaluationFeature

@Suite @MainActor struct StatsViewModelTests {
    private func makeEvaluation(
        categoryTitle: String, correct: Int, total: Int, outcome: MTCDomain.EvaluationOutcome
    ) -> MTCDomain.Evaluation {
        MTCDomain.Evaluation(
            id: UUID().uuidString, categoryId: "1", categoryTitle: categoryTitle,
            totalCorrect: correct, totalIncorrect: total - correct, totalQuestions: total,
            outcome: outcome, date: Date()
        )
    }

    @Test func stateStartsLoadingWithZeroedAggregates() {
        let viewModel = StatsViewModel(evaluationRepository: FakeEvaluationRepository())
        #expect(viewModel.state.isLoading == true)
        #expect(viewModel.state.totalEvaluations == 0)
        #expect(viewModel.state.approvalRate == 0)
    }

    @Test func loadComputesOverallAggregates() async {
        let repository = FakeEvaluationRepository()
        repository.evaluationsToReturn = [
            makeEvaluation(categoryTitle: "A", correct: 9, total: 10, outcome: .approved),
            makeEvaluation(categoryTitle: "A", correct: 3, total: 10, outcome: .rejected),
            makeEvaluation(categoryTitle: "B", correct: 8, total: 10, outcome: .approved),
        ]
        let viewModel = StatsViewModel(evaluationRepository: repository)

        await viewModel.load()

        #expect(viewModel.state.totalEvaluations == 3)
        #expect(viewModel.state.totalApproved == 2)
        #expect(viewModel.state.totalRejected == 1)
        #expect(viewModel.state.approvalRate == 2.0 / 3.0)
        #expect(viewModel.state.totalQuestionsAnswered == 30)
        #expect(viewModel.state.totalCorrectAnswers == 20)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadGroupsAndSortsCategoryStatsByApprovalRateAscending() async {
        let repository = FakeEvaluationRepository()
        repository.evaluationsToReturn = [
            // Category "Strong": 2/2 approved -> rate 1.0
            makeEvaluation(categoryTitle: "Strong", correct: 9, total: 10, outcome: .approved),
            makeEvaluation(categoryTitle: "Strong", correct: 9, total: 10, outcome: .approved),
            // Category "Weak": 0/2 approved -> rate 0.0
            makeEvaluation(categoryTitle: "Weak", correct: 2, total: 10, outcome: .rejected),
            makeEvaluation(categoryTitle: "Weak", correct: 3, total: 10, outcome: .rejected),
        ]
        let viewModel = StatsViewModel(evaluationRepository: repository)

        await viewModel.load()

        #expect(viewModel.state.categoryStats.map(\.categoryTitle) == ["Weak", "Strong"])
        #expect(viewModel.state.categoryStats.map(\.evaluationCount) == [2, 2])
        #expect(viewModel.state.categoryStats.map(\.approvalRate) == [0.0, 1.0])
    }

    @Test func loadHandlesNoEvaluationsWithoutDivisionByZero() async {
        let viewModel = StatsViewModel(evaluationRepository: FakeEvaluationRepository())
        await viewModel.load()
        #expect(viewModel.state.totalEvaluations == 0)
        #expect(viewModel.state.approvalRate == 0)
        #expect(viewModel.state.categoryStats.isEmpty)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadPreservesFirstEncounterOrderWhenCategoryRatesTie() async {
        let repository = FakeEvaluationRepository()
        repository.evaluationsToReturn = [
            // Category "First": 1/2 approved -> rate 0.5 (encountered first)
            makeEvaluation(categoryTitle: "First", correct: 9, total: 10, outcome: .approved),
            makeEvaluation(categoryTitle: "First", correct: 2, total: 10, outcome: .rejected),
            // Category "Second": 1/2 approved -> rate 0.5 (encountered second, same rate)
            makeEvaluation(categoryTitle: "Second", correct: 8, total: 10, outcome: .approved),
            makeEvaluation(categoryTitle: "Second", correct: 3, total: 10, outcome: .rejected),
        ]
        let viewModel = StatsViewModel(evaluationRepository: repository)

        await viewModel.load()

        // When approval rates tie (both 0.5), order-preserving grouping ensures
        // first-encounter order is maintained: ["First", "Second"]
        #expect(viewModel.state.categoryStats.map(\.categoryTitle) == ["First", "Second"])
        #expect(viewModel.state.categoryStats.map(\.evaluationCount) == [2, 2])
        #expect(viewModel.state.categoryStats.map(\.approvalRate) == [0.5, 0.5])
    }
}
