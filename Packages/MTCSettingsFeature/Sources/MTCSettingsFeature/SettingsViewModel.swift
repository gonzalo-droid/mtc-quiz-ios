import MTCDomain
import Observation

@MainActor
@Observable
public final class SettingsViewModel {
    public private(set) var state = SettingsState()

    private let preferencesRepository: PreferencesRepository

    public init(preferencesRepository: PreferencesRepository) {
        self.preferencesRepository = preferencesRepository
    }

    public func load() async {
        state = SettingsState(themeMode: await preferencesRepository.themeMode, isLoading: false)
    }

    public func setThemeMode(_ mode: String) async {
        state.themeMode = mode
        await preferencesRepository.setThemeMode(mode)
    }
}
