import MTCDomain

public struct SummaryState: Equatable, Sendable {
    public var category: MTCDomain.Category
    public var evaluation: MTCDomain.Evaluation?
    public var isLoading: Bool

    public init(
        category: MTCDomain.Category = MTCDomain.Category(
            id: "", title: "", category: "", classType: "", description: "", pdf: "", pathJson: ""
        ),
        evaluation: MTCDomain.Evaluation? = nil,
        isLoading: Bool = true
    ) {
        self.category = category
        self.evaluation = evaluation
        self.isLoading = isLoading
    }
}
