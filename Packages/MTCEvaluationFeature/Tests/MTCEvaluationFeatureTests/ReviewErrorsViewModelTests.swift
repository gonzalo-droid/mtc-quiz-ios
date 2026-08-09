import Testing
import Foundation
import MTCDomain
@testable import MTCEvaluationFeature

@Suite @MainActor struct ReviewErrorsViewModelTests {
    private func makeResult(questionId: Int, question: String, isCorrect: Bool, option: String = "a) Wrong", correctAnswer: String = "c) Right") -> MTCDomain.QuestionResult {
        MTCDomain.QuestionResult(
            id: UUID().uuidString, questionId: questionId, question: question,
            option: option, isCorrect: isCorrect, correctAnswer: correctAnswer
        )
    }

    private func makeEvaluation(results: [MTCDomain.QuestionResult]) -> MTCDomain.Evaluation {
        MTCDomain.Evaluation(
            id: UUID().uuidString, categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: results.filter(\.isCorrect).count,
            totalIncorrect: results.filter { !$0.isCorrect }.count,
            totalQuestions: results.count, outcome: .approved, date: Date(),
            questionResults: results
        )
    }

    @Test func stateStartsLoadingWithNoFrequentErrors() {
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: FakeEvaluationRepository(),
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )
        #expect(viewModel.state.isLoading == true)
        #expect(viewModel.state.frequentErrors.isEmpty)
    }

    @Test func loadIncludesQuestionsFailedThreeOrMoreTimesAcrossEvaluations() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
        ]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )

        await viewModel.load()

        #expect(viewModel.state.frequentErrors.map(\.questionId) == [5])
        #expect(viewModel.state.frequentErrors[0].failCount == 3)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadExcludesQuestionsFailedFewerThanThreeTimes() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
        ]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )

        await viewModel.load()

        #expect(viewModel.state.frequentErrors.isEmpty)
    }

    @Test func loadExcludesDismissedQuestionsEvenIfFailedThreeOrMoreTimes() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
        ]
        let dismissedRepository = FakeDismissedQuestionRepository()
        dismissedRepository.dismissedIds = [5]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: dismissedRepository
        )

        await viewModel.load()

        #expect(viewModel.state.frequentErrors.isEmpty)
    }

    @Test func loadSortsByFailCountDescending() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(results: [
                makeResult(questionId: 1, question: "Q1", isCorrect: false),
                makeResult(questionId: 2, question: "Q2", isCorrect: false),
            ]),
            makeEvaluation(results: [
                makeResult(questionId: 1, question: "Q1", isCorrect: false),
                makeResult(questionId: 2, question: "Q2", isCorrect: false),
            ]),
            makeEvaluation(results: [
                makeResult(questionId: 1, question: "Q1", isCorrect: false),
                makeResult(questionId: 2, question: "Q2", isCorrect: false),
            ]),
            makeEvaluation(results: [
                makeResult(questionId: 2, question: "Q2", isCorrect: false),
            ]),
        ]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )

        await viewModel.load()

        // Q2 failed 4 times, Q1 failed 3 times.
        #expect(viewModel.state.frequentErrors.map(\.questionId) == [2, 1])
        #expect(viewModel.state.frequentErrors.map(\.failCount) == [4, 3])
    }

    @Test func loadPreservesFirstEncounterOrderWhenFailCountsTie() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            // Each evaluation fails question 9 ("First") before question 7 ("Second"),
            // so 9 is encountered first. Both end up with the same fail count (3) -> tie.
            makeEvaluation(results: [
                makeResult(questionId: 9, question: "First", isCorrect: false),
                makeResult(questionId: 7, question: "Second", isCorrect: false),
            ]),
            makeEvaluation(results: [
                makeResult(questionId: 9, question: "First", isCorrect: false),
                makeResult(questionId: 7, question: "Second", isCorrect: false),
            ]),
            makeEvaluation(results: [
                makeResult(questionId: 9, question: "First", isCorrect: false),
                makeResult(questionId: 7, question: "Second", isCorrect: false),
            ]),
        ]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )

        await viewModel.load()

        // Both questions failed exactly 3 times -> tie. Order-preserving grouping ensures
        // first-encounter order is maintained: [9, 7], not some incidental Dictionary order.
        #expect(viewModel.state.frequentErrors.map(\.questionId) == [9, 7])
        #expect(viewModel.state.frequentErrors.map(\.failCount) == [3, 3])
    }

    @Test func dismissQuestionRemovesItAndPersists() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
        ]
        let dismissedRepository = FakeDismissedQuestionRepository()
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: dismissedRepository
        )
        await viewModel.load()
        #expect(viewModel.state.frequentErrors.count == 1)

        await viewModel.dismissQuestion(5)

        #expect(viewModel.state.frequentErrors.isEmpty)
        #expect(dismissedRepository.dismissedIds == [5])
    }
}
