import MTCDomain

final class FakePreferencesRepository: PreferencesRepository {
    var streakToReturn: Int
    var userNameToReturn: String

    init(streakToReturn: Int = 0, userNameToReturn: String = "") {
        self.streakToReturn = streakToReturn
        self.userNameToReturn = userNameToReturn
    }

    var streak: Int {
        get async { streakToReturn }
    }

    var userName: String {
        get async { userNameToReturn }
    }
}
