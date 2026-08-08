import Testing
@testable import MTCData

@Suite struct LocalCategoryRepositoryTests {
    @Test func loadsAllNineCategoriesFromBundledJSON() async {
        let repository = LocalCategoryRepository()
        let categories = await repository.categories()
        #expect(categories.count == 9)
    }

    @Test func classAAndClassBCodesAreAllPresent() async {
        let repository = LocalCategoryRepository()
        let codes = Set(await repository.categories().map(\.category))
        let expected: Set<String> = ["A-I", "A-IIa", "A-IIb", "A-IIIa", "A-IIIb", "A-IIIc", "B-IIa", "B-IIb", "B-IIc"]
        #expect(codes == expected)
    }

    @Test func firstCategoryMatchesKnownAndroidValues() async throws {
        let repository = LocalCategoryRepository()
        let categories = await repository.categories()
        let a1 = try #require(categories.first { $0.category == "A-I" })
        #expect(a1.id == "1")
        #expect(a1.classType == "CLASE A")
        #expect(a1.pdf == "CLASE_A_I.pdf")
        #expect(a1.examId == "a1")
    }
}
