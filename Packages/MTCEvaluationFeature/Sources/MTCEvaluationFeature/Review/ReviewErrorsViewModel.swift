import MTCDomain
import Observation

@MainActor
@Observable
public final class ReviewErrorsViewModel {
    public private(set) var state = ReviewErrorsState()

    private let evaluationRepository: EvaluationRepository
    private let dismissedQuestionRepository: DismissedQuestionRepository

    public init(evaluationRepository: EvaluationRepository, dismissedQuestionRepository: DismissedQuestionRepository) {
        self.evaluationRepository = evaluationRepository
        self.dismissedQuestionRepository = dismissedQuestionRepository
    }

    public func load() async {
        let evaluations = await evaluationRepository.allEvaluations()
        let dismissedIds = await dismissedQuestionRepository.dismissedQuestionIds()
        state = ReviewErrorsState(
            frequentErrors: frequentErrors(from: evaluations, dismissedIds: dismissedIds),
            isLoading: false
        )
    }

    public func dismissQuestion(_ questionId: Int) async {
        await dismissedQuestionRepository.dismiss(questionId: questionId)
        await load()
    }

    /// Groups failed results by `questionId` preserving first-encounter order (see the
    /// same rationale in `StatsViewModel.categoryStats(from:)`), keeps only questions failed
    /// 3+ times that aren't dismissed, and sorts by fail count descending — mirrors Android's
    /// `groupBy` -> `filter` -> `map` -> `sortedByDescending` pipeline exactly.
    private func frequentErrors(from evaluations: [MTCDomain.Evaluation], dismissedIds: Set<Int>) -> [FrequentError] {
        let failedResults = evaluations.flatMap(\.questionResults).filter { !$0.isCorrect }

        var order: [Int] = []
        var buckets: [Int: [MTCDomain.QuestionResult]] = [:]
        for result in failedResults {
            if buckets[result.questionId] == nil {
                order.append(result.questionId)
            }
            buckets[result.questionId, default: []].append(result)
        }

        return order
            .compactMap { questionId -> FrequentError? in
                guard let results = buckets[questionId], results.count >= 3, !dismissedIds.contains(questionId) else {
                    return nil
                }
                guard let latest = results.last else { return nil }
                return FrequentError(
                    questionId: questionId,
                    question: latest.question,
                    failCount: results.count,
                    lastWrongAnswer: latest.option ?? "",
                    correctAnswer: latest.correctAnswer
                )
            }
            .sorted { $0.failCount > $1.failCount }
    }
}
