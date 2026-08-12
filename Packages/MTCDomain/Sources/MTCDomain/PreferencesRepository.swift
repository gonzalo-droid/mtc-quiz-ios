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

    /// Call once per completed quiz. Advances `streak` by day: same-day calls are a no-op,
    /// a call on the day right after the last one increments the streak, and any bigger gap
    /// (or the very first call) resets it to 1.
    func recordStudySession() async
}
