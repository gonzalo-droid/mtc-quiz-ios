import MTCDomain

final class FakePreferencesRepository: PreferencesRepository {
    var streakToReturn: Int
    var userNameToReturn: String
    var numberOfQuestionsToReturn: Int
    var evaluationTimeMinutesToReturn: Int
    var passPercentageToReturn: Int

    init(
        streakToReturn: Int = 0,
        userNameToReturn: String = "",
        numberOfQuestionsToReturn: Int = 40,
        evaluationTimeMinutesToReturn: Int = 40,
        passPercentageToReturn: Int = 80
    ) {
        self.streakToReturn = streakToReturn
        self.userNameToReturn = userNameToReturn
        self.numberOfQuestionsToReturn = numberOfQuestionsToReturn
        self.evaluationTimeMinutesToReturn = evaluationTimeMinutesToReturn
        self.passPercentageToReturn = passPercentageToReturn
    }

    var streak: Int {
        get async { streakToReturn }
    }

    var userName: String {
        get async { userNameToReturn }
    }

    var numberOfQuestions: Int {
        get async { numberOfQuestionsToReturn }
    }

    var evaluationTimeMinutes: Int {
        get async { evaluationTimeMinutesToReturn }
    }

    var passPercentage: Int {
        get async { passPercentageToReturn }
    }
}
