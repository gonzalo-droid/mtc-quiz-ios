import Testing
@testable import MTCSettingsFeature

@Suite @MainActor struct SettingsViewModelTests {
    @Test func loadPopulatesThemeModeFromRepository() async {
        let preferences = FakePreferencesRepository()
        preferences.themeModeToReturn = "dark"
        let viewModel = SettingsViewModel(preferencesRepository: preferences)

        await viewModel.load()

        #expect(viewModel.state.themeMode == "dark")
        #expect(viewModel.state.isLoading == false)
    }

    @Test func setThemeModeUpdatesStateAndPersists() async {
        let preferences = FakePreferencesRepository()
        let viewModel = SettingsViewModel(preferencesRepository: preferences)
        await viewModel.load()

        await viewModel.setThemeMode("light")

        #expect(viewModel.state.themeMode == "light")
        #expect(preferences.setThemeModeCalls == ["light"])
    }
}
