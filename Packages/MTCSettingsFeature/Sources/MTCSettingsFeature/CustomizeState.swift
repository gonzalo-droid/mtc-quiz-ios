public struct CustomizeState: Equatable, Sendable {
    public var numberQuestions: String
    public var timeToFinishEvaluation: String
    public var percentageToApprovedEvaluation: String
    public var isLoading: Bool

    public init(
        numberQuestions: String = "",
        timeToFinishEvaluation: String = "",
        percentageToApprovedEvaluation: String = "",
        isLoading: Bool = true
    ) {
        self.numberQuestions = numberQuestions
        self.timeToFinishEvaluation = timeToFinishEvaluation
        self.percentageToApprovedEvaluation = percentageToApprovedEvaluation
        self.isLoading = isLoading
    }
}
