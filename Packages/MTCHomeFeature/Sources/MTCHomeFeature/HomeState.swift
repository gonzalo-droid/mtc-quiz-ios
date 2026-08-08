import MTCDomain

public struct HomeState: Equatable, Sendable {
    public var categories: [MTCDomain.Category]
    public var streak: Int
    public var userName: String

    public init(categories: [MTCDomain.Category] = [], streak: Int = 0, userName: String = "") {
        self.categories = categories
        self.streak = streak
        self.userName = userName
    }
}
