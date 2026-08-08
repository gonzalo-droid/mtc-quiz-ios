import Testing
import MTCDomain
@testable import MTCDetailFeature

// Verify with: xcodebuild test -scheme MTCDetailFeature -destination 'platform=iOS Simulator,name=iPhone 17' (plain `swift test` can't compile MTCDesignSystem's UIKit import)

@Suite @MainActor struct DetailViewModelTests {
    private let category = MTCDomain.Category(
        id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
        description: "Es el más común y te permite manejar carros como sedanes, coupé, hatchback, convertibles, station wagon, SUV, Areneros, Pickup y furgones. Es necesaria para obtener las demás licencias de Clase A.",
        pdf: "CLASE_A_I.pdf", pathJson: "a1_questions.json"
    )

    @Test func stateStartsLoadingWithNoCategory() {
        let viewModel = DetailViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )
        #expect(viewModel.state.category == nil)
        #expect(viewModel.state.isLoading == true)
    }

    @Test func loadPopulatesCategoryAndClearsLoading() async {
        let viewModel = DetailViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )

        await viewModel.load()

        #expect(viewModel.state.category == category)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadLeavesCategoryNilWhenIdNotFound() async {
        let viewModel = DetailViewModel(
            categoryId: "missing-id",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )

        await viewModel.load()

        #expect(viewModel.state.category == nil)
        #expect(viewModel.state.isLoading == false)
    }
}
