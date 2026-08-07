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
                Text("Evaluación de prueba")
                    .font(MTCTypography.largeTitle)

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
