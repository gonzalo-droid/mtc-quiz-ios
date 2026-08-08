import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private let onSelectCategory: (MTCDomain.Category) -> Void

    public init(viewModel: HomeViewModel, onSelectCategory: @escaping (MTCDomain.Category) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectCategory = onSelectCategory
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Título de barra en Android (TopAppBar, R.string.test_evaluation) — sin NavigationStack
                // todavía en esta fase, así que se muestra como texto en el flujo, mismo texto exacto.
                Text("Simulacro de evaluación - Perú 🇵🇪")
                    .font(MTCTypography.headline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Preparate para tu evaluación")
                        .font(MTCTypography.largeTitle)
                    Text("Evaluación de conocimientos para postulantes a licencias de conducir.")
                        .font(MTCTypography.body)
                        .foregroundStyle(.secondary)
                }

                if viewModel.state.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(MTCColor.amber)
                        Text("\(viewModel.state.streak) día\(viewModel.state.streak > 1 ? "s" : "")")
                            .font(MTCTypography.headline)
                            .foregroundStyle(MTCColor.amber)
                    }
                }

                VStack(spacing: 12) {
                    ForEach(viewModel.state.categories) { category in
                        CategoryCard(category: category) {
                            onSelectCategory(category)
                        }
                    }
                }
            }
            .padding(16)
        }
        .task {
            await viewModel.load()
        }
    }
}

/// Repositorio de preview: no toca UserDefaults ni el JSON real bundleado, así el canvas de Xcode
/// no depende de nada externo. Vive solo acá, no se comparte con los fakes de test (esos están en
/// el target de tests, que este target no puede importar).
private struct PreviewCategoryRepository: CategoryRepository {
    let categoriesToReturn: [MTCDomain.Category]

    func categories() async -> [MTCDomain.Category] {
        categoriesToReturn
    }
}

private struct PreviewPreferencesRepository: PreferencesRepository {
    let streakToReturn: Int
    var streak: Int {
        get async { streakToReturn }
    }
    var userName: String {
        get async { "Gonzalo" }
    }
}

private let previewCategories: [MTCDomain.Category] = [
    MTCDomain.Category(
        id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
        description: "Es el más común y te permite manejar carros como sedanes, coupé, hatchback, convertibles, station wagon, SUV, Areneros, Pickup y furgones.",
        pdf: "CLASE_A_I.pdf", pathJson: "a1_questions.json"
    ),
    MTCDomain.Category(
        id: "2", title: "CLASE A - CATEGORIA II-A", category: "A-IIa", classType: "CLASE A",
        description: "Los mismos que A-1 y también carros oficiales de transporte de pasajeros como Taxis, Buses, Ambulancias y Transporte Interprovincial.",
        pdf: "CLASE_A_IIA.pdf", pathJson: "a2a_questions.json"
    ),
    MTCDomain.Category(
        id: "8", title: "CLASE B - CATEGORIA II-A", category: "B-IIa", classType: "CLASE B",
        description: "Bicimotos para transportar pasajeros o mercancías.",
        pdf: "CLASE_B_IIA.pdf", pathJson: "b2a_questions.json"
    ),
]

#Preview("Con racha") {
    HomeView(
        viewModel: HomeViewModel(
            categoryRepository: PreviewCategoryRepository(categoriesToReturn: previewCategories),
            preferencesRepository: PreviewPreferencesRepository(streakToReturn: 5)
        ),
        onSelectCategory: { _ in }
    )
}

#Preview("Sin racha") {
    HomeView(
        viewModel: HomeViewModel(
            categoryRepository: PreviewCategoryRepository(categoriesToReturn: previewCategories),
            preferencesRepository: PreviewPreferencesRepository(streakToReturn: 0)
        ),
        onSelectCategory: { _ in }
    )
}
