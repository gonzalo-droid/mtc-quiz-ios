import Testing
@testable import MTCSettingsFeature

@Suite @MainActor struct CustomizeViewModelTests {
    @Test func loadPopulatesFieldsAsStringsFromRepository() async {
        let preferences = FakePreferencesRepository()
        preferences.numberOfQuestionsToReturn = 25
        preferences.evaluationTimeMinutesToReturn = 15
        preferences.passPercentageToReturn = 90
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        await viewModel.load()

        #expect(viewModel.state.numberQuestions == "25")
        #expect(viewModel.state.timeToFinishEvaluation == "15")
        #expect(viewModel.state.percentageToApprovedEvaluation == "90")
        #expect(viewModel.state.isLoading == false)
    }

    @Test func updateValuesPersistsWhenAllWithinRange() async {
        let preferences = FakePreferencesRepository()
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        let succeeded = await viewModel.updateValues(
            numberQuestions: "25", timeToFinishEvaluation: "15", percentageToApprovedEvaluation: "90"
        )

        #expect(succeeded == true)
        #expect(preferences.setNumberOfQuestionsCalls == [25])
        #expect(preferences.setEvaluationTimeMinutesCalls == [15])
        #expect(preferences.setPassPercentageCalls == [90])
    }

    @Test func updateValuesFailsWhenNumberQuestionsOutOfRange() async {
        let preferences = FakePreferencesRepository()
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        let succeeded = await viewModel.updateValues(
            numberQuestions: "0", timeToFinishEvaluation: "15", percentageToApprovedEvaluation: "90"
        )

        #expect(succeeded == false)
        #expect(preferences.setNumberOfQuestionsCalls.isEmpty)
    }

    @Test func updateValuesFailsWhenPercentageOutOfRange() async {
        let preferences = FakePreferencesRepository()
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        let succeeded = await viewModel.updateValues(
            numberQuestions: "25", timeToFinishEvaluation: "15", percentageToApprovedEvaluation: "150"
        )

        #expect(succeeded == false)
        #expect(preferences.setNumberOfQuestionsCalls.isEmpty)
        #expect(preferences.setEvaluationTimeMinutesCalls.isEmpty)
        #expect(preferences.setPassPercentageCalls.isEmpty)
    }

    @Test func updateValuesFailsWhenFieldIsNotANumber() async {
        let preferences = FakePreferencesRepository()
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        let succeeded = await viewModel.updateValues(
            numberQuestions: "abc", timeToFinishEvaluation: "15", percentageToApprovedEvaluation: "90"
        )

        #expect(succeeded == false)
    }
}
