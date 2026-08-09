import MTCDomain

public struct QuestionReviewState: Equatable, Sendable {
    public var category: MTCDomain.Category?
    public var questions: [MTCDomain.Question]
    public var searchText: String
    public var isLoading: Bool

    public init(
        category: MTCDomain.Category? = nil,
        questions: [MTCDomain.Question] = [],
        searchText: String = "",
        isLoading: Bool = true
    ) {
        self.category = category
        self.questions = questions
        self.searchText = searchText
        self.isLoading = isLoading
    }
}
