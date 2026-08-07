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
}
