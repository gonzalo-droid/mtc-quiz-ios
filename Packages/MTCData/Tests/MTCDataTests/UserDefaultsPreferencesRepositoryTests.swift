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
}
