public protocol DismissedQuestionRepository: Sendable {
    /// Marks a question as "learned" — Repaso de errores excludes it from future results
    /// even if it's later failed again fewer than 3 times since the dismissal.
    ///
    /// Despite the label, `questionId` is the error's key (`FrequentError.key`: bank + PDF id +
    /// text), not the bare question id, which repeats across banks and inside a3b/a3c.
    func dismiss(questionId: Int) async
    func dismissedQuestionIds() async -> Set<Int>
}
