import MTCDomain

public struct HistoryState: Equatable, Sendable {
    public var evaluations: [MTCDomain.Evaluation]
    public var isLoading: Bool

    public init(evaluations: [MTCDomain.Evaluation] = [], isLoading: Bool = true) {
        self.evaluations = evaluations
        self.isLoading = isLoading
    }
}
