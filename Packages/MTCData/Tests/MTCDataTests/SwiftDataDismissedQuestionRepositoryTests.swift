import Foundation
import Testing
import SwiftData
@testable import MTCData

@Suite @MainActor struct SwiftDataDismissedQuestionRepositoryTests {
    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: DismissedQuestionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func dismissedQuestionIdsIsEmptyInitially() async {
        let repository = SwiftDataDismissedQuestionRepository(modelContext: makeInMemoryContext())
        #expect(await repository.dismissedQuestionIds().isEmpty)
    }

    @Test func dismissThenFetchIncludesTheId() async {
        let repository = SwiftDataDismissedQuestionRepository(modelContext: makeInMemoryContext())
        await repository.dismiss(questionId: 42)
        #expect(await repository.dismissedQuestionIds() == [42])
    }

    @Test func dismissingTheSameIdTwiceDoesNotDuplicate() async {
        let repository = SwiftDataDismissedQuestionRepository(modelContext: makeInMemoryContext())
        await repository.dismiss(questionId: 42)
        await repository.dismiss(questionId: 42)
        #expect(await repository.dismissedQuestionIds() == [42])
    }
}
