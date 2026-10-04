import SwiftUI

public struct PDFScreenView: View {
    @State private var viewModel: PDFViewModel
    @State private var isSharing = false
    private let onDownload: (_ presentShareSheet: @escaping () -> Void) -> Void
    private let onShareSheetDismissed: () -> Void

    /// - Parameters:
    ///   - onDownload: runs when "Descargar" is tapped and must call `presentShareSheet` exactly
    ///     once when the share sheet may appear — the app shell runs the PDF interstitial gate
    ///     here, as Android does on its download action (never on opening the screen).
    ///   - onShareSheetDismissed: runs after the share sheet closes; the shell uses it to offer
    ///     premium when an ad interrupted the download.
    public init(
        viewModel: PDFViewModel,
        onDownload: @escaping (_ presentShareSheet: @escaping () -> Void) -> Void = { $0() },
        onShareSheetDismissed: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onDownload = onDownload
        self.onShareSheetDismissed = onShareSheetDismissed
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
                                onDownload { isSharing = true }
                            } label: {
                                Label("Descargar", systemImage: "square.and.arrow.down")
                            }
                            .accessibilityLabel("Descargar")
                        }
                    }
                    .sheet(isPresented: $isSharing, onDismiss: onShareSheetDismissed) {
                        ShareSheet(items: [url])
                            .presentationDetents([.medium, .large])
                            .ignoresSafeArea()
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
