import MTCDomain
import Observation

@MainActor
@Observable
public final class HistoryViewModel {
    public private(set) var state = HistoryState()

    private let evaluationRepository: EvaluationRepository

    public init(evaluationRepository: EvaluationRepository) {
        self.evaluationRepository = evaluationRepository
    }

    public func load() async {
        let evaluations = await evaluationRepository.allEvaluations()
        state = HistoryState(evaluations: evaluations, isLoading: false)
    }
}
