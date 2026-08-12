import MTCDomain

final class FakePreferencesRepository: PreferencesRepository {
    var streakToReturn: Int
    var userNameToReturn: String
    var numberOfQuestionsToReturn: Int
    var evaluationTimeMinutesToReturn: Int
    var passPercentageToReturn: Int
    var themeModeToReturn: String

    init(
        streakToReturn: Int = 0,
        userNameToReturn: String = "",
        numberOfQuestionsToReturn: Int = 40,
        evaluationTimeMinutesToReturn: Int = 40,
        passPercentageToReturn: Int = 80,
        themeModeToReturn: String = "system"
    ) {
        self.streakToReturn = streakToReturn
        self.userNameToReturn = userNameToReturn
        self.numberOfQuestionsToReturn = numberOfQuestionsToReturn
        self.evaluationTimeMinutesToReturn = evaluationTimeMinutesToReturn
        self.passPercentageToReturn = passPercentageToReturn
        self.themeModeToReturn = themeModeToReturn
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

    var themeMode: String {
        get async { themeModeToReturn }
    }

    func setThemeMode(_ mode: String) async {
        themeModeToReturn = mode
    }

    func setNumberOfQuestions(_ value: Int) async {
        numberOfQuestionsToReturn = value
    }

    func setEvaluationTimeMinutes(_ value: Int) async {
        evaluationTimeMinutesToReturn = value
    }

    func setPassPercentage(_ value: Int) async {
        passPercentageToReturn = value
    }

    func recordStudySession() async {}
}
