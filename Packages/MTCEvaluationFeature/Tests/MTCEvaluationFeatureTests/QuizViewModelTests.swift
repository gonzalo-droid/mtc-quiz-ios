import Testing
import MTCDomain
@testable import MTCEvaluationFeature

@Suite @MainActor struct QuizViewModelTests {
    private let category = MTCDomain.Category(
        id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
        description: "d", pdf: "p.pdf", pathJson: "a1_questions.json"
    )

    private func makeQuestion(id: Int, answer: String = "c") -> MTCDomain.Question {
        MTCDomain.Question(
            id: id, topic: "t", title: "Pregunta \(id)", answer: answer,
            options: ["a) A", "b) B", "c) C", "d) D"]
        )
    }

    private func makeViewModel(
        questions: [MTCDomain.Question],
        numberOfQuestions: Int = 40,
        passPercentage: Int = 80
    ) -> (QuizViewModel, FakeEvaluationRepository) {
        let evaluationRepository = FakeEvaluationRepository()
        let preferences = FakePreferencesRepository()
        preferences.numberOfQuestionsToReturn = numberOfQuestions
        preferences.passPercentageToReturn = passPercentage
        let viewModel = QuizViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            questionRepository: FakeQuestionRepository(questionsToReturn: questions),
            evaluationRepository: evaluationRepository,
            preferencesRepository: preferences
        )
        return (viewModel, evaluationRepository)
    }

    @Test func loadPopulatesQuestionsRespectingNumberOfQuestionsLimit() async {
        let questions = (1...5).map { makeQuestion(id: $0) }
        let (viewModel, _) = makeViewModel(questions: questions, numberOfQuestions: 3)

        await viewModel.load()

        #expect(viewModel.state.questions.count == 3)
        #expect(viewModel.state.questions.map(\.id) == [1, 2, 3])
        #expect(viewModel.state.currentQuestion.id == 1)
        #expect(viewModel.state.currentIndex == 0)
        #expect(viewModel.state.isLoading == false)
        #expect(viewModel.state.category == category)
    }

    @Test func selectOptionSetsSelectedIndexBeforeVerification() async {
        let (viewModel, _) = makeViewModel(questions: [makeQuestion(id: 1)])
        await viewModel.load()

        viewModel.selectOption(at: 2)

        #expect(viewModel.state.selectedOptionIndex == 2)
        #expect(viewModel.state.isAnswerVerified == false)
    }

    @Test func selectOptionIsIgnoredAfterVerification() async {
        let (viewModel, _) = makeViewModel(questions: [makeQuestion(id: 1)])
        await viewModel.load()
        viewModel.selectOption(at: 2)
        viewModel.verifyAnswer()

        viewModel.selectOption(at: 0)

        #expect(viewModel.state.selectedOptionIndex == 2) // unchanged, locked after verify
    }

    @Test func verifyAnswerMarksVerifiedAndDetectsLastQuestion() async {
        let (viewModel, _) = makeViewModel(questions: [makeQuestion(id: 1)])
        await viewModel.load()
        viewModel.selectOption(at: 2) // "c" is correct per makeQuestion's default answer

        viewModel.verifyAnswer()

        #expect(viewModel.state.isAnswerVerified == true)
        #expect(viewModel.isLastQuestion == true) // only 1 question total
    }

    @Test func nextQuestionAdvancesIndexAndResetsSelectionState() async {
        let questions = [makeQuestion(id: 1), makeQuestion(id: 2)]
        let (viewModel, _) = makeViewModel(questions: questions)
        await viewModel.load()
        viewModel.selectOption(at: 2)
        viewModel.verifyAnswer()

        viewModel.nextQuestion()

        #expect(viewModel.state.currentIndex == 1)
        #expect(viewModel.state.currentQuestion.id == 2)
        #expect(viewModel.state.selectedOptionIndex == nil)
        #expect(viewModel.state.isAnswerVerified == false)
    }

    @Test func finishQuizComputesApprovedOutcomeWhenAtOrAboveThreshold() async {
        // 2 questions, both answered correctly -> 100% >= 80% threshold -> approved.
        let questions = [makeQuestion(id: 1, answer: "c"), makeQuestion(id: 2, answer: "a")]
        let (viewModel, evaluationRepository) = makeViewModel(questions: questions, passPercentage: 80)
        await viewModel.load()

        viewModel.selectOption(at: 2) // correct for question 1 ("c")
        viewModel.verifyAnswer()
        viewModel.nextQuestion()
        viewModel.selectOption(at: 0) // correct for question 2 ("a")
        viewModel.verifyAnswer()

        await viewModel.finishQuiz()

        #expect(evaluationRepository.savedEvaluations.count == 1)
        let saved = evaluationRepository.savedEvaluations[0]
        #expect(saved.totalCorrect == 2)
        #expect(saved.totalIncorrect == 0)
        #expect(saved.totalQuestions == 2)
        #expect(saved.outcome == .approved)
        #expect(saved.categoryId == "1")
        #expect(saved.categoryTitle == "CLASE A - CATEGORIA I")
        #expect(saved.questionResults.count == 2)
    }

    @Test func finishQuizComputesRejectedOutcomeWhenBelowThreshold() async {
        // 2 questions, 1 wrong -> 50% < 80% threshold -> rejected.
        let questions = [makeQuestion(id: 1, answer: "c"), makeQuestion(id: 2, answer: "a")]
        let (viewModel, evaluationRepository) = makeViewModel(questions: questions, passPercentage: 80)
        await viewModel.load()

        viewModel.selectOption(at: 2) // correct
        viewModel.verifyAnswer()
        viewModel.nextQuestion()
        viewModel.selectOption(at: 1) // wrong (answer is "a" -> index 0)
        viewModel.verifyAnswer()

        await viewModel.finishQuiz()

        let saved = evaluationRepository.savedEvaluations[0]
        #expect(saved.totalCorrect == 1)
        #expect(saved.totalIncorrect == 1)
        #expect(saved.outcome == .rejected)
    }

    @Test func finishQuizCountsUnansweredQuestionsAsIncorrect() async {
        // 3 questions, only the first is answered (correctly) before finishQuiz() is called —
        // mirrors the real time's-up path, where the timer fires finishQuiz() with some
        // questions never verified. 1/3 ≈ 33% < 80% threshold -> rejected, and the 2
        // unanswered questions should count as incorrect rather than being dropped.
        let questions = [
            makeQuestion(id: 1, answer: "c"), makeQuestion(id: 2, answer: "a"), makeQuestion(id: 3, answer: "b"),
        ]
        let (viewModel, evaluationRepository) = makeViewModel(questions: questions, passPercentage: 80)
        await viewModel.load()

        viewModel.selectOption(at: 2) // correct for question 1 ("c")
        viewModel.verifyAnswer()
        // Questions 2 and 3 are left unanswered.

        await viewModel.finishQuiz()

        #expect(evaluationRepository.savedEvaluations.count == 1)
        let saved = evaluationRepository.savedEvaluations[0]
        #expect(saved.totalCorrect == 1)
        #expect(saved.totalIncorrect == 2)
        #expect(saved.totalQuestions == 3)
        #expect(saved.outcome == .rejected)
    }

    @Test func finishQuizInvokesOnFinishedWithTheSavedEvaluationId() async {
        let (viewModel, _) = makeViewModel(questions: [makeQuestion(id: 1)])
        await viewModel.load()
        viewModel.selectOption(at: 2)
        viewModel.verifyAnswer()

        var finishedId: String?
        viewModel.onFinished = { id in finishedId = id }
        await viewModel.finishQuiz()

        #expect(finishedId != nil)
    }
}
