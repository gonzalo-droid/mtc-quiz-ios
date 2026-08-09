// Packages/MTCDetailFeature/Sources/MTCDetailFeature/DetailView.swift
import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct DetailView: View {
    @State private var viewModel: DetailViewModel
    private let onStartEvaluation: () -> Void
    private let onStudy: () -> Void
    private let onDownloadPDF: () -> Void

    public init(
        viewModel: DetailViewModel,
        onStartEvaluation: @escaping () -> Void,
        onStudy: @escaping () -> Void,
        onDownloadPDF: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onStartEvaluation = onStartEvaluation
        self.onStudy = onStudy
        self.onDownloadPDF = onDownloadPDF
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let category = viewModel.state.category {
                    content(for: category)
                } else if viewModel.state.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    Text("No se encontró la categoría.")
                        .font(MTCTypography.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
            }
            .padding(16)
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func content(for category: MTCDomain.Category) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.classType)
                        .font(MTCTypography.caption)
                        .foregroundStyle(MTCColor.primary)
                    Text(category.category)
                        .font(MTCTypography.largeTitle)
                        .foregroundStyle(MTCColor.primary)
                }
                Spacer()
                VehicleIllustration(examId: category.examId)
                    .frame(width: 160, height: 120)
            }

            Text(category.description)
                .font(MTCTypography.body)
                .padding(.top, 16)

            Text("* Licencia de conducir para conductores no profesionales")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))

        VStack(spacing: 12) {
            Button(action: onStartEvaluation) {
                Text("Iniciar evalución")
                    .font(MTCTypography.headline)
                    .foregroundStyle(MTCColor.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(MTCColor.primary)
            .clipShape(Capsule())

            // "Estudiar" (modo repaso/QuestionReview) no está construido en este port — deshabilitado
            // en vez de retirado, para no perder la fidelidad visual con Android mientras no exista
            // el destino real.
            Button(action: onStudy) {
                Label("Estudiar (próximamente)", systemImage: "car.fill")
                    .font(MTCTypography.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .overlay(Capsule().stroke(Color.secondary, lineWidth: 1.3))
            .disabled(true)

            Button(action: onDownloadPDF) {
                Label("Descargar PDF", systemImage: "book.fill")
                    .font(MTCTypography.body)
                    .foregroundStyle(MTCColor.primary)
            }
        }
        .padding(.top, 24)
    }
}

private let previewCategory = MTCDomain.Category(
    id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
    description: "Es el más común y te permite manejar carros como sedanes, coupé, hatchback, convertibles, station wagon, SUV, Areneros, Pickup y furgones. Es necesaria para obtener las demás licencias de Clase A.",
    pdf: "CLASE_A_I.pdf", pathJson: "a1_questions.json"
)

private struct PreviewCategoryRepository: CategoryRepository {
    func categories() async -> [MTCDomain.Category] { [previewCategory] }
    func category(withId id: String) async -> MTCDomain.Category? {
        id == previewCategory.id ? previewCategory : nil
    }
}

#Preview("Con categoría") {
    DetailView(
        viewModel: DetailViewModel(categoryId: "1", categoryRepository: PreviewCategoryRepository()),
        onStartEvaluation: {},
        onStudy: {},
        onDownloadPDF: {}
    )
}

#Preview("Categoría no encontrada") {
    DetailView(
        viewModel: DetailViewModel(categoryId: "no-such-id", categoryRepository: PreviewCategoryRepository()),
        onStartEvaluation: {},
        onStudy: {},
        onDownloadPDF: {}
    )
}
