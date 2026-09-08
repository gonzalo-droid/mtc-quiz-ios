import MTCDomain
import Observation

@MainActor
@Observable
public final class CustomizeViewModel {
    public private(set) var state = CustomizeState()

    private let preferencesRepository: PreferencesRepository

    public init(preferencesRepository: PreferencesRepository) {
        self.preferencesRepository = preferencesRepository
    }

    public func load() async {
        state = CustomizeState(
            numberOfQuestions: await preferencesRepository.numberOfQuestions,
            evaluationTimeMinutes: await preferencesRepository.evaluationTimeMinutes,
            passPercentage: await preferencesRepository.passPercentage,
            isLoading: false
        )
    }

    /// A slider-bounded value can't be invalid, so unlike the old text-field `updateValues`,
    /// there's nothing left to validate here — this always succeeds. It still returns `Bool`
    /// (rather than `Void`) so the view's existing success/failure alert plumbing needs no
    /// restructuring, matching the shape `PreferencesRepository`'s setters already commit to.
    public func save(numberOfQuestions: Int, evaluationTimeMinutes: Int, passPercentage: Int) async -> Bool {
        state.numberOfQuestions = numberOfQuestions
        state.evaluationTimeMinutes = evaluationTimeMinutes
        state.passPercentage = passPercentage

        await preferencesRepository.setNumberOfQuestions(numberOfQuestions)
        await preferencesRepository.setEvaluationTimeMinutes(evaluationTimeMinutes)
        await preferencesRepository.setPassPercentage(passPercentage)

        return true
    }
}
