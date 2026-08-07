public protocol CategoryRepository: Sendable {
    func categories() async -> [Category]
}
