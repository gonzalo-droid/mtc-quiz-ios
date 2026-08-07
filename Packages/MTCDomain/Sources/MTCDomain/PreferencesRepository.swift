public protocol PreferencesRepository: Sendable {
    var streak: Int { get async }
    var userName: String { get async }
}
