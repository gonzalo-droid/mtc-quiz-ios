import Foundation
import MTCDomain

public final class UserDefaultsPreferencesRepository: PreferencesRepository {
    private nonisolated(unsafe) let defaults: UserDefaults

    private enum Keys {
        static let streak = "current_streak"
        static let userName = "user_name"
        static let numberOfQuestions = "number_of_questions"
        static let evaluationTimeMinutes = "evaluation_time_minutes"
        static let passPercentage = "pass_percentage"
        static let themeMode = "theme_mode"
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

    /// UserDefaults.integer(forKey:) returns 0 when unset — 0 is never a valid value for any of these
    /// three preferences, so it doubles safely as the "not yet configured" sentinel, falling back to
    /// Android's real DataStore defaults (40 questions / 40 minutes / 80%).
    public var numberOfQuestions: Int {
        get async {
            let value = defaults.integer(forKey: Keys.numberOfQuestions)
            return value == 0 ? 40 : value
        }
    }

    public var evaluationTimeMinutes: Int {
        get async {
            let value = defaults.integer(forKey: Keys.evaluationTimeMinutes)
            return value == 0 ? 40 : value
        }
    }

    public var passPercentage: Int {
        get async {
            let value = defaults.integer(forKey: Keys.passPercentage)
            return value == 0 ? 80 : value
        }
    }

    public var themeMode: String {
        get async { defaults.string(forKey: Keys.themeMode) ?? "system" }
    }

    public func setThemeMode(_ mode: String) async {
        defaults.set(mode, forKey: Keys.themeMode)
    }

    public func setNumberOfQuestions(_ value: Int) async {
        defaults.set(value, forKey: Keys.numberOfQuestions)
    }

    public func setEvaluationTimeMinutes(_ value: Int) async {
        defaults.set(value, forKey: Keys.evaluationTimeMinutes)
    }

    public func setPassPercentage(_ value: Int) async {
        defaults.set(value, forKey: Keys.passPercentage)
    }
}
