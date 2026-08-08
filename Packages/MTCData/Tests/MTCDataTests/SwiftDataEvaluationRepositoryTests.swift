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
}
