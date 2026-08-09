public protocol PreferencesRepository: Sendable {
    var streak: Int { get async }
    var userName: String { get async }
    var numberOfQuestions: Int { get async }
    var evaluationTimeMinutes: Int { get async }
    var passPercentage: Int { get async }
    var themeMode: String { get async }

    func setThemeMode(_ mode: String) async
    func setNumberOfQuestions(_ value: Int) async
    func setEvaluationTimeMinutes(_ value: Int) async
    func setPassPercentage(_ value: Int) async
}
