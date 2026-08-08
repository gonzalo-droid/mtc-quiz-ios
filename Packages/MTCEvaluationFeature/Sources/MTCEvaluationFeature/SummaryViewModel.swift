import MTCDomain
import Observation

@MainActor
@Observable
public final class SummaryViewModel {
    public private(set) var state = SummaryState()

    private let categoryId: String
    private let evaluationId: String
    private let categoryRepository: CategoryRepository
    private let evaluationRepository: EvaluationRepository

    public init(
        categoryId: String,
        evaluationId: String,
        categoryRepository: CategoryRepository,
        evaluationRepository: EvaluationRepository
    ) {
        self.categoryId = categoryId
        self.evaluationId = evaluationId
        self.categoryRepository = categoryRepository
        self.evaluationRepository = evaluationRepository
    }

    public func load() async {
        async let category = categoryRepository.category(withId: categoryId)
        async let evaluation = evaluationRepository.evaluation(withId: evaluationId)

        state = SummaryState(
            category: await category ?? state.category,
            evaluation: await evaluation,
            isLoading: false
        )
    }
}
