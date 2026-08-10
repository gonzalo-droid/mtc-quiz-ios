import MTCDomain

/// Shared across every `#Preview` in this package that needs an `EvaluationRepository` —
/// consolidates what used to be 5 near-identical `private` copies (one per screen file).
/// Preview-only; the real fake used by Swift Testing (`FakeEvaluationRepository`, in the
/// Tests target) stays separate — different responsibility (tracks `savedEvaluations` for
/// assertions), not something this consolidation touches.
struct PreviewEvaluationRepository: EvaluationRepository {
    var evaluations: [MTCDomain.Evaluation] = []
    var evaluationToReturn: MTCDomain.Evaluation? = nil

    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { evaluationToReturn }
    func allEvaluations() async -> [MTCDomain.Evaluation] { evaluations }
}
