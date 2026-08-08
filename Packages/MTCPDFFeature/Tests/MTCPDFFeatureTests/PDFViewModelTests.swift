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

    @Test func loadLeavesURLNilWhenCategoryFoundButPDFResourceMissing() async {
        let categoryWithMissingResource = MTCDomain.Category(
            id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
            description: "Es el más común...", pdf: "NO_EXISTE.pdf", pathJson: "a1_questions.json"
        )
        let viewModel = PDFViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [categoryWithMissingResource])
        )

        await viewModel.load()

        #expect(viewModel.state.pdfURL == nil)
        #expect(viewModel.state.isLoading == false)
    }

    // The 9 real category -> PDF mappings from
    // Packages/MTCData/Sources/MTCData/Resources/categories.json, each of which must have
    // a matching bundled resource in Packages/MTCPDFFeature/Sources/MTCPDFFeature/Resources/.
    // This pins that neither side (the JSON's "pdf" field or the bundled filename) can be
    // renamed without a test failure.
    nonisolated static let allCategoryPDFMappings: [(id: String, pdf: String)] = [
        ("1", "CLASE_A_I.pdf"),
        ("2", "CLASE_A_IIA.pdf"),
        ("3", "CLASE_A_IIB.pdf"),
        ("4", "CLASE_A_IIIA.pdf"),
        ("5", "CLASE_A_IIIB.pdf"),
        ("6", "CLASE_A_IIIC.pdf"),
        ("8", "CLASE_B_IIA.pdf"),
        ("9", "CLASE_B_IIB.pdf"),
        ("10", "CLASE_B_IIC.pdf"),
    ]

    @Test(arguments: allCategoryPDFMappings)
    func loadResolvesBundledPDFForEachRealCategoryMapping(mapping: (id: String, pdf: String)) async {
        let realCategory = MTCDomain.Category(
            id: mapping.id, title: "title", category: "category", classType: "classType",
            description: "description", pdf: mapping.pdf, pathJson: "pathJson"
        )
        let viewModel = PDFViewModel(
            categoryId: mapping.id,
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [realCategory])
        )

        await viewModel.load()

        #expect(viewModel.state.pdfURL != nil)
        #expect(viewModel.state.pdfURL?.lastPathComponent == mapping.pdf)
        #expect(viewModel.state.isLoading == false)
    }
}
