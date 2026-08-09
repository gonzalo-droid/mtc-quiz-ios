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
            numberQuestions: String(await preferencesRepository.numberOfQuestions),
            timeToFinishEvaluation: String(await preferencesRepository.evaluationTimeMinutes),
            percentageToApprovedEvaluation: String(await preferencesRepository.passPercentage),
            isLoading: false
        )
    }

    public func updateValues(
        numberQuestions: String,
        timeToFinishEvaluation: String,
        percentageToApprovedEvaluation: String
    ) async -> Bool {
        guard
            let questions = Int(numberQuestions), (1...1000).contains(questions),
            let minutes = Int(timeToFinishEvaluation), (1...1000).contains(minutes),
            let percentage = Int(percentageToApprovedEvaluation), (1...100).contains(percentage)
        else {
            return false
        }

        state.numberQuestions = numberQuestions
        state.timeToFinishEvaluation = timeToFinishEvaluation
        state.percentageToApprovedEvaluation = percentageToApprovedEvaluation

        await preferencesRepository.setNumberOfQuestions(questions)
        await preferencesRepository.setEvaluationTimeMinutes(minutes)
        await preferencesRepository.setPassPercentage(percentage)

        return true
    }
}
