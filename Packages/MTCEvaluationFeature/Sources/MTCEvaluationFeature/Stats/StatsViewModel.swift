import MTCDomain
import Observation

@MainActor
@Observable
public final class StatsViewModel {
    public private(set) var state = StatsState()

    private let evaluationRepository: EvaluationRepository

    public init(evaluationRepository: EvaluationRepository) {
        self.evaluationRepository = evaluationRepository
    }

    public func load() async {
        let evaluations = await evaluationRepository.allEvaluations()

        let totalApproved = evaluations.filter { $0.outcome == .approved }.count
        let totalRejected = evaluations.filter { $0.outcome == .rejected }.count
        let approvalRate = evaluations.isEmpty ? 0 : Double(totalApproved) / Double(evaluations.count)
        let totalQuestions = evaluations.reduce(0) { $0 + $1.totalQuestions }
        let totalCorrect = evaluations.reduce(0) { $0 + $1.totalCorrect }

        state = StatsState(
            totalEvaluations: evaluations.count,
            totalApproved: totalApproved,
            totalRejected: totalRejected,
            approvalRate: approvalRate,
            totalQuestionsAnswered: totalQuestions,
            totalCorrectAnswers: totalCorrect,
            categoryStats: categoryStats(from: evaluations),
            isLoading: false
        )
    }

    /// Groups by `categoryTitle` preserving first-encounter order (Swift's `Dictionary` is
    /// NOT insertion-ordered, unlike Kotlin's `groupBy`/`LinkedHashMap`). Swift's `sorted(by:)`
    /// is NOT documented as stable (unlike Kotlin's `sortedBy`), so the final sort carries an
    /// explicit encounter-index tiebreaker instead of relying on stdlib sort-stability behavior
    /// that happens to hold today.
    private func categoryStats(from evaluations: [MTCDomain.Evaluation]) -> [CategoryStat] {
        var order: [String] = []
        var buckets: [String: [MTCDomain.Evaluation]] = [:]
        for evaluation in evaluations {
            if buckets[evaluation.categoryTitle] == nil {
                order.append(evaluation.categoryTitle)
            }
            buckets[evaluation.categoryTitle, default: []].append(evaluation)
        }

        return order
            .enumerated()
            .map { encounterIndex, title -> (encounterIndex: Int, stat: CategoryStat) in
                let evals = buckets[title] ?? []
                let approved = evals.filter { $0.outcome == .approved }.count
                let stat = CategoryStat(
                    categoryTitle: title,
                    evaluationCount: evals.count,
                    approvalRate: evals.isEmpty ? 0 : Double(approved) / Double(evals.count)
                )
                return (encounterIndex, stat)
            }
            .sorted {
                if $0.stat.approvalRate != $1.stat.approvalRate {
                    return $0.stat.approvalRate < $1.stat.approvalRate
                }
                return $0.encounterIndex < $1.encounterIndex
            }
            .map(\.stat)
    }
}
