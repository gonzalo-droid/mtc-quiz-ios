import MTCDomain

final class FakePreferencesRepository: PreferencesRepository {
    var streakToReturn: Int = 0
    var userNameToReturn: String = ""
    var numberOfQuestionsToReturn: Int = 40
    var evaluationTimeMinutesToReturn: Int = 40
    var passPercentageToReturn: Int = 80

    var streak: Int { get async { streakToReturn } }
    var userName: String { get async { userNameToReturn } }
    var numberOfQuestions: Int { get async { numberOfQuestionsToReturn } }
    var evaluationTimeMinutes: Int { get async { evaluationTimeMinutesToReturn } }
    var passPercentage: Int { get async { passPercentageToReturn } }
}
