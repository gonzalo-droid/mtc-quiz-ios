import MTCDomain

final class FakePreferencesRepository: PreferencesRepository {
    var streakToReturn: Int = 0
    var userNameToReturn: String = ""
    var numberOfQuestionsToReturn: Int = 40
    var evaluationTimeMinutesToReturn: Int = 40
    var passPercentageToReturn: Int = 80
    var themeModeToReturn: String = "system"

    var streak: Int { get async { streakToReturn } }
    var userName: String { get async { userNameToReturn } }
    var numberOfQuestions: Int { get async { numberOfQuestionsToReturn } }
    var evaluationTimeMinutes: Int { get async { evaluationTimeMinutesToReturn } }
    var passPercentage: Int { get async { passPercentageToReturn } }
    var themeMode: String { get async { themeModeToReturn } }

    func setThemeMode(_ mode: String) async { themeModeToReturn = mode }
    func setNumberOfQuestions(_ value: Int) async { numberOfQuestionsToReturn = value }
    func setEvaluationTimeMinutes(_ value: Int) async { evaluationTimeMinutesToReturn = value }
    func setPassPercentage(_ value: Int) async { passPercentageToReturn = value }
}
