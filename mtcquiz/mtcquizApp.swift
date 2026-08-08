import SwiftUI
import MTCData
import MTCHomeFeature
internal import MTCDomain

@main
struct mtcquizApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView(
                viewModel: HomeViewModel(
                    categoryRepository: LocalCategoryRepository(),
                    preferencesRepository: UserDefaultsPreferencesRepository()
                ),
                onSelectCategory: { category in
                    // La navegación real a Detail llega en el sub-proyecto 2.
                    print("Selected category: \(category.category)")
                }
            )
        }
    }
}
