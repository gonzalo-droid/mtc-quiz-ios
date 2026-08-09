import Foundation
import Testing
import SwiftData
import MTCDomain
@testable import MTCData

@Suite @MainActor struct SwiftDataEvaluationRepositoryTests {
    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: EvaluationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func saveThenFetchByIdRoundTripsAllFields() async {
        let repository = SwiftDataEvaluationRepository(modelContext: makeInMemoryContext())
        let result = QuestionResult(
            id: "r1", questionId: 1, question: "¿Pregunta?",
            option: "c) Opción C", isCorrect: true, correctAnswer: "c) Opción C"
        )
        let evaluation = MTCDomain.Evaluation(
            id: "eval-1", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: 8, totalIncorrect: 2, totalQuestions: 10,
            outcome: .approved, date: Date(timeIntervalSince1970: 1_700_000_000),
            questionResults: [result]
        )

        await repository.save(evaluation)
        let fetched = await repository.evaluation(withId: "eval-1")

        #expect(fetched?.id == "eval-1")
        #expect(fetched?.categoryTitle == "CLASE A - CATEGORIA I")
        #expect(fetched?.totalCorrect == 8)
        #expect(fetched?.outcome == .approved)
        #expect(fetched?.questionResults == [result])
    }

    @Test func evaluationReturnsNilForUnknownId() async {
        let repository = SwiftDataEvaluationRepository(modelContext: makeInMemoryContext())
        #expect(await repository.evaluation(withId: "does-not-exist") == nil)
    }

    @Test func allEvaluationsReturnsNewestFirst() async {
        let repository = SwiftDataEvaluationRepository(modelContext: makeInMemoryContext())
        let older = MTCDomain.Evaluation(
            id: "eval-older", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: 5, totalIncorrect: 5, totalQuestions: 10,
            outcome: .rejected, date: Date(timeIntervalSince1970: 1_000_000_000)
        )
        let newer = MTCDomain.Evaluation(
            id: "eval-newer", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: 9, totalIncorrect: 1, totalQuestions: 10,
            outcome: .approved, date: Date(timeIntervalSince1970: 2_000_000_000)
        )

        await repository.save(older)
        await repository.save(newer)
        let all = await repository.allEvaluations()

        #expect(all.map(\.id) == ["eval-newer", "eval-older"])
    }

    @Test func allEvaluationsIsEmptyWhenNothingSaved() async {
        let repository = SwiftDataEvaluationRepository(modelContext: makeInMemoryContext())
        #expect(await repository.allEvaluations().isEmpty)
    }
}
