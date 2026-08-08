import Foundation
import MTCDomain
import Observation

@MainActor
@Observable
public final class PDFViewModel {
    public private(set) var state = PDFState()

    private let categoryId: String
    private let categoryRepository: CategoryRepository

    public init(categoryId: String, categoryRepository: CategoryRepository) {
        self.categoryId = categoryId
        self.categoryRepository = categoryRepository
    }

    public func load() async {
        guard let category = await categoryRepository.category(withId: categoryId) else {
            state = PDFState(pdfURL: nil, categoryTitle: "", isLoading: false)
            return
        }

        let filename = (category.pdf as NSString).deletingPathExtension
        let url = Bundle.module.url(forResource: filename, withExtension: "pdf")
        state = PDFState(pdfURL: url, categoryTitle: category.category, isLoading: false)
    }
}
