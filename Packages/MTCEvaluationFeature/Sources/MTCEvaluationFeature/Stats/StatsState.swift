public struct CategoryStat: Equatable, Sendable {
    public let categoryTitle: String
    public let evaluationCount: Int
    public let approvalRate: Double

    public init(categoryTitle: String, evaluationCount: Int, approvalRate: Double) {
        self.categoryTitle = categoryTitle
        self.evaluationCount = evaluationCount
        self.approvalRate = approvalRate
    }
}

public struct StatsState: Equatable, Sendable {
    public var totalEvaluations: Int
    public var totalApproved: Int
    public var totalRejected: Int
    public var approvalRate: Double
    public var totalQuestionsAnswered: Int
    public var totalCorrectAnswers: Int
    public var categoryStats: [CategoryStat]
    public var isLoading: Bool

    public init(
        totalEvaluations: Int = 0,
        totalApproved: Int = 0,
        totalRejected: Int = 0,
        approvalRate: Double = 0,
        totalQuestionsAnswered: Int = 0,
        totalCorrectAnswers: Int = 0,
        categoryStats: [CategoryStat] = [],
        isLoading: Bool = true
    ) {
        self.totalEvaluations = totalEvaluations
        self.totalApproved = totalApproved
        self.totalRejected = totalRejected
        self.approvalRate = approvalRate
        self.totalQuestionsAnswered = totalQuestionsAnswered
        self.totalCorrectAnswers = totalCorrectAnswers
        self.categoryStats = categoryStats
        self.isLoading = isLoading
    }
}
