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
        let dismissedKeys = await dismissedQuestionRepository.dismissedQuestionIds()
        state = ReviewErrorsState(
            frequentErrors: frequentErrors(from: evaluations, dismissedKeys: dismissedKeys),
            isLoading: false
        )
    }

    /// `key` is the error's `FrequentError.key`. The repository stores it in place of a bare
    /// question id; ids written before keys existed match no key, so those dismissals stop applying.
    public func dismissQuestion(_ key: Int) async {
        await dismissedQuestionRepository.dismiss(questionId: key)
        await load()
    }

    /// Groups failed results by `frequentErrorKey` (bank + id + text: ids repeat across banks
    /// and inside a3b/a3c) preserving first-encounter order (see the
    /// same rationale in `StatsViewModel.categoryStats(from:)`), keeps only questions failed
    /// 3+ times that aren't dismissed, and sorts by fail count descending — mirrors Android's
    /// `groupBy` -> `filter` -> `map` -> `sortedByDescending` pipeline. Swift's `sorted(by:)`
    /// is NOT documented as stable (unlike Kotlin's `sortedByDescending`), so the final sort
    /// carries an explicit encounter-index tiebreaker instead of relying on stdlib
    /// sort-stability behavior that happens to hold today.
    private func frequentErrors(from evaluations: [MTCDomain.Evaluation], dismissedKeys: Set<Int>) -> [FrequentError] {
        var order: [Int] = []
        var buckets: [Int: [MTCDomain.QuestionResult]] = [:]
        for evaluation in evaluations {
            for result in evaluation.questionResults where !result.isCorrect {
                let key = frequentErrorKey(
                    categoryId: evaluation.categoryId,
                    questionId: result.questionId,
                    question: result.question
                )
                if buckets[key] == nil {
                    order.append(key)
                }
                buckets[key, default: []].append(result)
            }
        }

        return order
            .enumerated()
            .compactMap { encounterIndex, key -> (encounterIndex: Int, error: FrequentError)? in
                guard let results = buckets[key], results.count >= 3, !dismissedKeys.contains(key) else {
                    return nil
                }
                guard let latest = results.last else { return nil }
                let error = FrequentError(
                    key: key,
                    questionId: latest.questionId,
                    question: latest.question,
                    failCount: results.count,
                    lastWrongAnswer: latest.option ?? "",
                    correctAnswer: latest.correctAnswer
                )
                return (encounterIndex, error)
            }
            .sorted {
                if $0.error.failCount != $1.error.failCount {
                    return $0.error.failCount > $1.error.failCount
                }
                return $0.encounterIndex < $1.encounterIndex
            }
            .map(\.error)
    }
}
