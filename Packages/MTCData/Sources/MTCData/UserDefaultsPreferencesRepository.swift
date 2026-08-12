import Foundation
import MTCDomain

public final class UserDefaultsPreferencesRepository: PreferencesRepository {
    private nonisolated(unsafe) let defaults: UserDefaults

    private enum Keys {
        static let streak = "current_streak"
        static let lastStudyDate = "last_study_date"
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

    public func recordStudySession() async {
        let today = Self.epochDay(for: Date())
        let lastDate = defaults.integer(forKey: Keys.lastStudyDate)
        let currentStreak = defaults.integer(forKey: Keys.streak)

        switch today {
        case lastDate:
            break // already recorded today, no change
        case lastDate + 1:
            defaults.set(currentStreak + 1, forKey: Keys.streak)
            defaults.set(today, forKey: Keys.lastStudyDate)
        default:
            defaults.set(1, forKey: Keys.streak)
            defaults.set(today, forKey: Keys.lastStudyDate)
        }
    }

    /// Day count in the current calendar/timezone since the Unix epoch — the Swift equivalent of
    /// Android's `LocalDate.now().toEpochDay()`, used so the streak resets at local midnight rather
    /// than UTC midnight.
    private static func epochDay(for date: Date, calendar: Calendar = .current) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        let epoch = Date(timeIntervalSince1970: 0)
        return calendar.dateComponents([.day], from: epoch, to: startOfDay).day ?? 0
    }
}
