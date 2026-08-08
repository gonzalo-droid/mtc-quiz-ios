import MTCDomain
import Observation

@available(macOS 14, *)
@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var state = HomeState()

    private let categoryRepository: CategoryRepository
    private let preferencesRepository: PreferencesRepository

    public init(categoryRepository: CategoryRepository, preferencesRepository: PreferencesRepository) {
        self.categoryRepository = categoryRepository
        self.preferencesRepository = preferencesRepository
    }

    public func load() async {
        async let categories = categoryRepository.categories()
        async let streak = preferencesRepository.streak
        async let userName = preferencesRepository.userName
        state = HomeState(categories: await categories, streak: await streak, userName: await userName)
    }
}
