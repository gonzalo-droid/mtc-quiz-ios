public protocol DismissedQuestionRepository: Sendable {
    /// Marks a question as "learned" — Repaso de errores excludes it from future results
    /// even if it's later failed again fewer than 3 times since the dismissal.
    func dismiss(questionId: Int) async
    func dismissedQuestionIds() async -> Set<Int>
}
