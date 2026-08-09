import Foundation
import SwiftData
import MTCDomain

@MainActor
public final class SwiftDataEvaluationRepository: EvaluationRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func save(_ evaluation: Evaluation) async {
        let json = encodedQuestionResults(evaluation.questionResults)
        let record = EvaluationRecord(
            id: evaluation.id,
            categoryId: evaluation.categoryId,
            categoryTitle: evaluation.categoryTitle,
            totalCorrect: evaluation.totalCorrect,
            totalIncorrect: evaluation.totalIncorrect,
            totalQuestions: evaluation.totalQuestions,
            outcome: evaluation.outcome.rawValue,
            date: evaluation.date,
            questionResultsJSON: json
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    public func evaluation(withId id: String) async -> Evaluation? {
        let descriptor = FetchDescriptor<EvaluationRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? modelContext.fetch(descriptor).first else { return nil }
        return evaluation(from: record)
    }

    public func allEvaluations() async -> [Evaluation] {
        let descriptor = FetchDescriptor<EvaluationRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map(evaluation(from:))
    }

    private func evaluation(from record: EvaluationRecord) -> Evaluation {
        Evaluation(
            id: record.id,
            categoryId: record.categoryId,
            categoryTitle: record.categoryTitle,
            totalCorrect: record.totalCorrect,
            totalIncorrect: record.totalIncorrect,
            totalQuestions: record.totalQuestions,
            outcome: EvaluationOutcome(rawValue: record.outcome) ?? .approved,
            date: record.date,
            questionResults: decodedQuestionResults(record.questionResultsJSON)
        )
    }

    private func encodedQuestionResults(_ results: [QuestionResult]) -> String {
        guard
            let data = try? JSONEncoder().encode(results),
            let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return json
    }

    private func decodedQuestionResults(_ json: String) -> [QuestionResult] {
        guard
            let data = json.data(using: .utf8),
            let results = try? JSONDecoder().decode([QuestionResult].self, from: data)
        else {
            return []
        }
        return results
    }
}
