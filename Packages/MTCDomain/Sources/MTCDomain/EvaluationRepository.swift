public protocol EvaluationRepository: Sendable {
    func save(_ evaluation: Evaluation) async
    func evaluation(withId id: String) async -> Evaluation?
}
