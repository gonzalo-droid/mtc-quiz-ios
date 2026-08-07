import MTCDomain

final class FakeCategoryRepository: CategoryRepository {
    var categoriesToReturn: [MTCDomain.Category]

    init(categoriesToReturn: [MTCDomain.Category] = []) {
        self.categoriesToReturn = categoriesToReturn
    }

    func categories() async -> [MTCDomain.Category] {
        categoriesToReturn
    }
}
