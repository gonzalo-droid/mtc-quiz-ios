import SwiftUI
import MTCData
import MTCHomeFeature
import MTCDetailFeature
import MTCPDFFeature
internal import MTCDomain

@main
struct mtcquizApp: App {
    private let categoryRepository = LocalCategoryRepository()
    private let preferencesRepository = UserDefaultsPreferencesRepository()

    var body: some Scene {
        WindowGroup {
            RootView(categoryRepository: categoryRepository, preferencesRepository: preferencesRepository)
        }
    }
}

private struct RootView: View {
    let categoryRepository: LocalCategoryRepository
    let preferencesRepository: UserDefaultsPreferencesRepository
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                viewModel: HomeViewModel(
                    categoryRepository: categoryRepository,
                    preferencesRepository: preferencesRepository
                ),
                onSelectCategory: { category in
                    path.append(Route.detail(categoryId: category.id))
                }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detail(let categoryId):
                    DetailView(
                        viewModel: DetailViewModel(categoryId: categoryId, categoryRepository: categoryRepository),
                        onStartEvaluation: {
                            // La navegación real a Evaluation llega en el sub-proyecto de Evaluation.
                        },
                        onStudy: {
                            // "Estudiar" (QuestionReview) queda fuera de alcance en esta pasada.
                        },
                        onDownloadPDF: {
                            path.append(Route.pdf(categoryId: categoryId))
                        }
                    )
                case .pdf(let categoryId):
                    PDFScreenView(
                        viewModel: PDFViewModel(categoryId: categoryId, categoryRepository: categoryRepository)
                    )
                }
            }
        }
    }
}
