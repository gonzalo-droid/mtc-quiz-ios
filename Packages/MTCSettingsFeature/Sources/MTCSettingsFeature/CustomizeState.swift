public struct CustomizeState: Equatable, Sendable {
    public var numberOfQuestions: Int
    public var evaluationTimeMinutes: Int
    public var passPercentage: Int
    public var isLoading: Bool

    public init(
        numberOfQuestions: Int = 40,
        evaluationTimeMinutes: Int = 40,
        passPercentage: Int = 80,
        isLoading: Bool = true
    ) {
        self.numberOfQuestions = numberOfQuestions
        self.evaluationTimeMinutes = evaluationTimeMinutes
        self.passPercentage = passPercentage
        self.isLoading = isLoading
    }
}
