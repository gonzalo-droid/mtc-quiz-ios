import MTCDomain

final class FakeEvaluationRepository: EvaluationRepository {
    private(set) var savedEvaluations: [MTCDomain.Evaluation] = []

    func save(_ evaluation: MTCDomain.Evaluation) async {
        savedEvaluations.append(evaluation)
    }

    func evaluation(withId id: String) async -> MTCDomain.Evaluation? {
        savedEvaluations.first { $0.id == id }
    }
}
