import Foundation
import MTCDomain

public final class UserDefaultsPreferencesRepository: PreferencesRepository {
    private nonisolated(unsafe) let defaults: UserDefaults

    private enum Keys {
        static let streak = "current_streak"
        static let userName = "user_name"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var streak: Int {
        get async { defaults.integer(forKey: Keys.streak) }
    }

    public var userName: String {
        get async { defaults.string(forKey: Keys.userName) ?? "" }
    }
}
