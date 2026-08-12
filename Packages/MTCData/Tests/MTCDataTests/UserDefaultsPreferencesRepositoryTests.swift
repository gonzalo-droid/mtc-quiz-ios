import Testing
import Foundation
@testable import MTCData

@Suite struct UserDefaultsPreferencesRepositoryTests {
    @Test func readsStreakAndUserNameFromUnderlyingDefaults() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(5, forKey: "current_streak")
        defaults.set("Gonzalo", forKey: "user_name")

        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        #expect(await repository.streak == 5)
        #expect(await repository.userName == "Gonzalo")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func defaultsToZeroAndEmptyStringWhenUnset() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        #expect(await repository.streak == 0)
        #expect(await repository.userName == "")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func numberOfQuestionsDefaultsTo40WhenUnset() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        #expect(await repository.numberOfQuestions == 40)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func evaluationTimeMinutesDefaultsTo40WhenUnset() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        #expect(await repository.evaluationTimeMinutes == 40)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func passPercentageDefaultsTo80WhenUnset() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        #expect(await repository.passPercentage == 80)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func themeModeDefaultsToSystemWhenUnset() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        #expect(await repository.themeMode == "system")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func setThemeModePersistsAndIsReadBack() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        await repository.setThemeMode("dark")
        #expect(await repository.themeMode == "dark")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func setNumberOfQuestionsPersistsAndIsReadBack() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        await repository.setNumberOfQuestions(25)
        #expect(await repository.numberOfQuestions == 25)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func setEvaluationTimeMinutesPersistsAndIsReadBack() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        await repository.setEvaluationTimeMinutes(15)
        #expect(await repository.evaluationTimeMinutes == 15)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func setPassPercentagePersistsAndIsReadBack() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        await repository.setPassPercentage(90)
        #expect(await repository.passPercentage == 90)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func recordStudySessionSetsStreakToOneOnFirstEverCall() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        await repository.recordStudySession()

        #expect(await repository.streak == 1)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func recordStudySessionIsANoOpWhenCalledAgainTheSameDay() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        await repository.recordStudySession()
        await repository.recordStudySession()
        await repository.recordStudySession()

        #expect(await repository.streak == 1)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func recordStudySessionIncrementsStreakOnConsecutiveDay() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(5, forKey: "current_streak")
        defaults.set(Self.epochDay(daysAgo: 1), forKey: "last_study_date")
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        await repository.recordStudySession()

        #expect(await repository.streak == 6)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func recordStudySessionResetsStreakToOneAfterAGapDay() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(9, forKey: "current_streak")
        defaults.set(Self.epochDay(daysAgo: 3), forKey: "last_study_date")
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        await repository.recordStudySession()

        #expect(await repository.streak == 1)

        defaults.removePersistentDomain(forName: suiteName)
    }

    /// Mirrors the private day-math inside UserDefaultsPreferencesRepository so tests can seed
    /// "yesterday" / "N days ago" without depending on wall-clock timing tricks.
    private static func epochDay(daysAgo: Int, calendar: Calendar = .current) -> Int {
        let target = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        let startOfDay = calendar.startOfDay(for: target)
        let epoch = Date(timeIntervalSince1970: 0)
        return calendar.dateComponents([.day], from: epoch, to: startOfDay).day ?? 0
    }
}
