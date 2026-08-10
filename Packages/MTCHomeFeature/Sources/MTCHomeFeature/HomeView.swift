import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private let onSelectCategory: (MTCDomain.Category) -> Void
    private let onOpenSettings: () -> Void
    private let onOpenPremium: () -> Void

    public init(
        viewModel: HomeViewModel,
        onSelectCategory: @escaping (MTCDomain.Category) -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenPremium: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectCategory = onSelectCategory
        self.onOpenSettings = onOpenSettings
        self.onOpenPremium = onOpenPremium
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                            .accessibilityHidden(true)
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
        .navigationTitle("Simulacro de evaluación - Perú 🇵🇪")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onOpenPremium) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Color(red: 1.0, green: 0.702, blue: 0.0)) // matches PremiumView's premiumGold
                }
                .accessibilityLabel("Premium")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityLabel("Configuraciones")
            }
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

    func category(withId id: String) async -> MTCDomain.Category? {
        categoriesToReturn.first { $0.id == id }
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
    var numberOfQuestions: Int {
        get async { 40 }
    }
    var evaluationTimeMinutes: Int {
        get async { 40 }
    }
    var passPercentage: Int {
        get async { 80 }
    }
    var themeMode: String {
        get async { "system" }
    }

    func setThemeMode(_ mode: String) async {}
    func setNumberOfQuestions(_ value: Int) async {}
    func setEvaluationTimeMinutes(_ value: Int) async {}
    func setPassPercentage(_ value: Int) async {}
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
        onSelectCategory: { _ in },
        onOpenSettings: {},
        onOpenPremium: {}
    )
}

#Preview("Sin racha") {
    HomeView(
        viewModel: HomeViewModel(
            categoryRepository: PreviewCategoryRepository(categoriesToReturn: previewCategories),
            preferencesRepository: PreviewPreferencesRepository(streakToReturn: 0)
        ),
        onSelectCategory: { _ in },
        onOpenSettings: {},
        onOpenPremium: {}
    )
}
