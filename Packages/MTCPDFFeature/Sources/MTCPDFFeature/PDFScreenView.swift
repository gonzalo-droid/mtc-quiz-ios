import SwiftUI

public struct PDFScreenView: View {
    @State private var viewModel: PDFViewModel
    private let onGoToPremium: (() -> Void)?

    /// - Parameter onGoToPremium: adds "Descargar sin anuncios con Premium" to the rewarded-ad
    ///   prompt. The shell passes `nil` while the app offers no Premium.
    public init(viewModel: PDFViewModel, onGoToPremium: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onGoToPremium = onGoToPremium
    }

    public var body: some View {
        Group {
            if let url = viewModel.state.pdfURL {
                PDFKitView(url: url)
                    .navigationTitle(viewModel.state.categoryTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            // Android's "Descargar" action. iOS has no Downloads folder an app
                            // writes to directly: the share sheet's "Guardar en Archivos" is the
                            // native way to keep a copy, and it also offers every other target.
                            Button {
                                viewModel.downloadTapped()
                            } label: {
                                Label("Descargar", systemImage: "square.and.arrow.down")
                            }
                            .accessibilityLabel("Descargar")
                        }
                    }
                    .sheet(isPresented: binding(\.isShareSheetPresented, viewModel.setShareSheetPresented)) {
                        ShareSheet(items: [url])
                            .presentationDetents([.medium, .large])
                            .ignoresSafeArea()
                    }
                    // AdMob requires the user to choose the rewarded ad and know what it earns.
                    .alert(
                        "Descarga gratis con un anuncio",
                        isPresented: binding(\.isRewardPromptPresented, viewModel.setRewardPromptPresented)
                    ) {
                        Button("Ver anuncio y descargar") { viewModel.watchAdTapped() }
                        if let onGoToPremium {
                            Button("Descargar sin anuncios con Premium", action: onGoToPremium)
                        }
                        Button("Cancelar", role: .cancel) {}
                    } message: {
                        Text("Mira un anuncio corto y podrás guardar el balotario en Archivos o compartirlo.")
                    }
                    .alert(
                        "Mira el anuncio completo para descargar el PDF",
                        isPresented: binding(\.isRewardSkippedPresented, viewModel.setRewardSkippedPresented)
                    ) {
                        Button("Entendido", role: .cancel) {}
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

    private func binding(
        _ keyPath: KeyPath<PDFState, Bool>,
        _ set: @escaping (Bool) -> Void
    ) -> Binding<Bool> {
        Binding(get: { viewModel.state[keyPath: keyPath] }, set: set)
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
