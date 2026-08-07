import Foundation
import MTCDomain

public final class LocalCategoryRepository: CategoryRepository {
    public init() {}

    public func categories() async -> [MTCDomain.Category] {
        guard
            let url = Bundle.module.url(forResource: "categories", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([CategoryDTO].self, from: data)
        else {
            assertionFailure("categories.json is missing or malformed in the MTCData bundle")
            return []
        }
        return decoded.map(\.asDomain)
    }
}

private struct CategoryDTO: Decodable {
    let id: String
    let title: String
    let category: String
    let classType: String
    let description: String
    let pdf: String
    let pathJson: String

    var asDomain: MTCDomain.Category {
        MTCDomain.Category(
            id: id,
            title: title,
            category: category,
            classType: classType,
            description: description,
            pdf: pdf,
            pathJson: pathJson
        )
    }
}
