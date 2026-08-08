import SwiftUI

public struct PDFScreenView: View {
    @State private var viewModel: PDFViewModel

    public init(viewModel: PDFViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if let url = viewModel.state.pdfURL {
                PDFKitView(url: url)
                    .navigationTitle(viewModel.state.categoryTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            ShareLink(item: url)
                        }
                    }
            } else if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No se encontró el PDF.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

import MTCDomain

private let previewCategory = MTCDomain.Category(
    id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
    description: "Es el más común...", pdf: "CLASE_A_I.pdf", pathJson: "a1_questions.json"
)

private struct PreviewCategoryRepository: CategoryRepository {
    func categories() async -> [MTCDomain.Category] { [previewCategory] }
    func category(withId id: String) async -> MTCDomain.Category? {
        id == previewCategory.id ? previewCategory : nil
    }
}

#Preview("PDF real") {
    NavigationStack {
        PDFScreenView(viewModel: PDFViewModel(categoryId: "1", categoryRepository: PreviewCategoryRepository()))
    }
}

#Preview("No encontrado") {
    NavigationStack {
        PDFScreenView(viewModel: PDFViewModel(categoryId: "no-existe", categoryRepository: PreviewCategoryRepository()))
    }
}
