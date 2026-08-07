import Testing
import MTCDomain
@testable import MTCHomeFeature

@Suite @MainActor struct HomeViewModelTests {
    @Test func stateStartsEmptyBeforeLoad() {
        let viewModel = HomeViewModel(
            categoryRepository: FakeCategoryRepository(),
            preferencesRepository: FakePreferencesRepository()
        )
        #expect(viewModel.state.categories.isEmpty)
        #expect(viewModel.state.streak == 0)
        #expect(viewModel.state.userName == "")
    }

    @Test func loadPopulatesStateFromBothRepositories() async {
        let category = MTCDomain.Category(
            id: "1", title: "CLASE A - CATEGORIA I", category: "A-I",
            classType: "CLASE A", description: "d", pdf: "p.pdf",
            pathJson: "a1_questions.json"
        )
        let viewModel = HomeViewModel(
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            preferencesRepository: FakePreferencesRepository(streakToReturn: 5, userNameToReturn: "Gonzalo")
        )

        await viewModel.load()

        #expect(viewModel.state.categories == [category])
        #expect(viewModel.state.streak == 5)
        #expect(viewModel.state.userName == "Gonzalo")
    }
}
