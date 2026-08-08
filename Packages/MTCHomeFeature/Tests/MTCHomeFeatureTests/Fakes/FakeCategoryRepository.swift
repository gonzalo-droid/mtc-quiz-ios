import MTCDomain

final class FakeCategoryRepository: CategoryRepository {
    var categoriesToReturn: [MTCDomain.Category]

    init(categoriesToReturn: [MTCDomain.Category] = []) {
        self.categoriesToReturn = categoriesToReturn
    }

    func categories() async -> [MTCDomain.Category] {
        categoriesToReturn
    }

    func category(withId id: String) async -> MTCDomain.Category? {
        categoriesToReturn.first { $0.id == id }
    }
}
