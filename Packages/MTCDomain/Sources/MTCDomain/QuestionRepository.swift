public protocol QuestionRepository: Sendable {
    /// `pathJson` is `Category.pathJson` (e.g. "a1_questions.json"). `limit` mirrors Android's
    /// `numberQuestion`/`isTake` — pass nil for "no limit", the preference value otherwise.
    func questions(pathJson: String, limit: Int?) async -> [Question]
}
