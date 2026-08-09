import MTCDomain

final class FakeDismissedQuestionRepository: DismissedQuestionRepository {
    var dismissedIds: Set<Int> = []

    func dismiss(questionId: Int) async {
        dismissedIds.insert(questionId)
    }

    func dismissedQuestionIds() async -> Set<Int> {
        dismissedIds
    }
}
