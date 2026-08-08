import MTCDomain
import Observation

@MainActor
@Observable
public final class DetailViewModel {
    public private(set) var state = DetailState()

    private let categoryId: String
    private let categoryRepository: CategoryRepository

    public init(categoryId: String, categoryRepository: CategoryRepository) {
        self.categoryId = categoryId
        self.categoryRepository = categoryRepository
    }

    public func load() async {
        let category = await categoryRepository.category(withId: categoryId)
        state = DetailState(category: category, isLoading: false)
    }
}
