import Testing
@testable import MTCSettingsFeature

@Suite @MainActor struct CustomizeViewModelTests {
    @Test func loadPopulatesFieldsFromRepository() async {
        let preferences = FakePreferencesRepository()
        preferences.numberOfQuestionsToReturn = 25
        preferences.evaluationTimeMinutesToReturn = 15
        preferences.passPercentageToReturn = 90
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        await viewModel.load()

        #expect(viewModel.state.numberOfQuestions == 25)
        #expect(viewModel.state.evaluationTimeMinutes == 15)
        #expect(viewModel.state.passPercentage == 90)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func savePersistsToRepository() async {
        let preferences = FakePreferencesRepository()
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        let succeeded = await viewModel.save(
            numberOfQuestions: 25, evaluationTimeMinutes: 15, passPercentage: 90
        )

        #expect(succeeded == true)
        #expect(preferences.setNumberOfQuestionsCalls == [25])
        #expect(preferences.setEvaluationTimeMinutesCalls == [15])
        #expect(preferences.setPassPercentageCalls == [90])
    }
}
