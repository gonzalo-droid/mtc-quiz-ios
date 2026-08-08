public protocol PreferencesRepository: Sendable {
    var streak: Int { get async }
    var userName: String { get async }
    var numberOfQuestions: Int { get async }
    var evaluationTimeMinutes: Int { get async }
    var passPercentage: Int { get async }
}
