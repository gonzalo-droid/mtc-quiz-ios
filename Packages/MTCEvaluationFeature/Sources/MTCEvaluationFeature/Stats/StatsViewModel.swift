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
    /// NOT insertion-ordered, unlike Kotlin's `groupBy`/`LinkedHashMap`) so that the final
    /// `sorted` — stable in Swift — ties break the same way Android's `sortedBy` would.
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
            .map { title -> CategoryStat in
                let evals = buckets[title] ?? []
                let approved = evals.filter { $0.outcome == .approved }.count
                return CategoryStat(
                    categoryTitle: title,
                    evaluationCount: evals.count,
                    approvalRate: evals.isEmpty ? 0 : Double(approved) / Double(evals.count)
                )
            }
            .sorted { $0.approvalRate < $1.approvalRate }
    }
}
