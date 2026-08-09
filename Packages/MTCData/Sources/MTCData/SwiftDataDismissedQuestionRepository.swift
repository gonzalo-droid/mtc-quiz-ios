import Foundation
import SwiftData
import MTCDomain

@MainActor
public final class SwiftDataDismissedQuestionRepository: DismissedQuestionRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func dismiss(questionId: Int) async {
        let descriptor = FetchDescriptor<DismissedQuestionRecord>(
            predicate: #Predicate { $0.questionId == questionId }
        )
        guard (try? modelContext.fetch(descriptor).first) == nil else { return }
        modelContext.insert(DismissedQuestionRecord(questionId: questionId))
        try? modelContext.save()
    }

    public func dismissedQuestionIds() async -> Set<Int> {
        let descriptor = FetchDescriptor<DismissedQuestionRecord>()
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return Set(records.map(\.questionId))
    }
}
