public struct SettingsState: Equatable, Sendable {
    public var themeMode: String
    public var isLoading: Bool

    public init(themeMode: String = "system", isLoading: Bool = true) {
        self.themeMode = themeMode
        self.isLoading = isLoading
    }
}
