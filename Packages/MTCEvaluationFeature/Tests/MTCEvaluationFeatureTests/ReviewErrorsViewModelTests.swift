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

    private func makeEvaluation(categoryId: String = "1", results: [MTCDomain.QuestionResult]) -> MTCDomain.Evaluation {
        MTCDomain.Evaluation(
            id: UUID().uuidString, categoryId: categoryId, categoryTitle: "CLASE A - CATEGORIA I",
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
        dismissedRepository.dismissedIds = [frequentErrorKey(categoryId: "1", questionId: 5, question: "Q5")]
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

        let key = viewModel.state.frequentErrors[0].key
        await viewModel.dismissQuestion(key)

        #expect(viewModel.state.frequentErrors.isEmpty)
        #expect(dismissedRepository.dismissedIds == [key])
        #expect(key == frequentErrorKey(categoryId: "1", questionId: 5, question: "Q5"))
    }

    // MARK: - Ids repeat across banks and inside a3b/a3c

    @Test func frequentErrorKeyMatchesTheReferenceValuesAndroidPinsToo() {
        // Same values in Android's FrequentErrorsTest.kt.
        #expect(frequentErrorKey(categoryId: "a1", questionId: 5, question: "Pregunta") == 237896178)
        #expect(
            frequentErrorKey(
                categoryId: "a3b", questionId: 63,
                question: "¿A partir de qué edad los menores de edad deben ocupar su propio asiento?"
            ) == -1597544078
        )
    }

    @Test func theSameIdInTwoBanksIsTwoDifferentErrors() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(categoryId: "a1", results: [makeResult(questionId: 5, question: "Pregunta de A-I", isCorrect: false)]),
            makeEvaluation(categoryId: "a1", results: [makeResult(questionId: 5, question: "Pregunta de A-I", isCorrect: false)]),
            makeEvaluation(categoryId: "a1", results: [makeResult(questionId: 5, question: "Pregunta de A-I", isCorrect: false)]),
            makeEvaluation(categoryId: "b2c", results: [makeResult(questionId: 5, question: "Pregunta de B-IIC", isCorrect: false)]),
        ]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )

        await viewModel.load()

        #expect(viewModel.state.frequentErrors.map(\.question) == ["Pregunta de A-I"])
        #expect(viewModel.state.frequentErrors.map(\.failCount) == [3])
    }

    @Test func aRepeatedIdInsideA3bDoesNotMergeItsTwoQuestions() async {
        // a3b's PDF restarts numbering for its second table: id 63 is two different questions.
        let first = "¿A partir de qué año de antigüedad debe realizarse la inspección técnica?"
        let second = "¿A partir de qué edad los menores de edad deben ocupar su propio asiento?"
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(categoryId: "a3b", results: [
                makeResult(questionId: 63, question: first, isCorrect: false),
                makeResult(questionId: 63, question: second, isCorrect: false),
            ]),
            makeEvaluation(categoryId: "a3b", results: [makeResult(questionId: 63, question: first, isCorrect: false)]),
            makeEvaluation(categoryId: "a3b", results: [makeResult(questionId: 63, question: second, isCorrect: false)]),
        ]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )

        await viewModel.load()

        #expect(viewModel.state.frequentErrors.isEmpty)
    }

    @Test func dismissingOneErrorLeavesTheSameIdInAnotherBankListed() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn =
            Array(repeating: makeEvaluation(categoryId: "a1", results: [makeResult(questionId: 5, question: "Pregunta de A-I", isCorrect: false)]), count: 3)
            + Array(repeating: makeEvaluation(categoryId: "b2c", results: [makeResult(questionId: 5, question: "Pregunta de B-IIC", isCorrect: false)]), count: 4)
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )
        await viewModel.load()
        #expect(viewModel.state.frequentErrors.map(\.question) == ["Pregunta de B-IIC", "Pregunta de A-I"])

        await viewModel.dismissQuestion(viewModel.state.frequentErrors[0].key)

        #expect(viewModel.state.frequentErrors.map(\.question) == ["Pregunta de A-I"])
    }

    @Test func aDismissalStoredAsABareQuestionIdNoLongerHidesAnything() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = Array(
            repeating: makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            count: 3
        )
        let dismissedRepository = FakeDismissedQuestionRepository()
        dismissedRepository.dismissedIds = [5]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: dismissedRepository
        )

        await viewModel.load()

        #expect(viewModel.state.frequentErrors.count == 1)
    }
}
