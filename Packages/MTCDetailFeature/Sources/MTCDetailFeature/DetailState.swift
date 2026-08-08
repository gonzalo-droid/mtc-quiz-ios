import MTCDomain

public struct DetailState: Equatable, Sendable {
    public var category: MTCDomain.Category?
    public var isLoading: Bool

    public init(category: MTCDomain.Category? = nil, isLoading: Bool = true) {
        self.category = category
        self.isLoading = isLoading
    }
}
