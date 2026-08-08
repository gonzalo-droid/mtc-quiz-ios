import Testing
import MTCDomain
@testable import MTCPDFFeature

@Suite @MainActor struct PDFViewModelTests {
    private let category = MTCDomain.Category(
        id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
        description: "Es el más común...", pdf: "CLASE_A_I.pdf", pathJson: "a1_questions.json"
    )

    @Test func stateStartsLoadingWithNoURL() {
        let viewModel = PDFViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )
        #expect(viewModel.state.pdfURL == nil)
        #expect(viewModel.state.isLoading == true)
    }

    @Test func loadResolvesBundledPDFForKnownCategory() async {
        let viewModel = PDFViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )

        await viewModel.load()

        #expect(viewModel.state.pdfURL != nil)
        #expect(viewModel.state.pdfURL?.lastPathComponent == "CLASE_A_I.pdf")
        #expect(viewModel.state.categoryTitle == "A-I")
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadLeavesURLNilWhenCategoryNotFound() async {
        let viewModel = PDFViewModel(
            categoryId: "missing-id",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )

        await viewModel.load()

        #expect(viewModel.state.pdfURL == nil)
        #expect(viewModel.state.isLoading == false)
    }
}
