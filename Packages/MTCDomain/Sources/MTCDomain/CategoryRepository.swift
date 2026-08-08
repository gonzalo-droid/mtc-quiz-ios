public protocol CategoryRepository: Sendable {
    func categories() async -> [Category]
    func category(withId id: String) async -> Category?
}
