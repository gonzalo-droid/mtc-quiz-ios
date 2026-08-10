import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct HistoryView: View {
    @State private var viewModel: HistoryViewModel
    private let onReviewErrors: () -> Void

    public init(viewModel: HistoryViewModel, onReviewErrors: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onReviewErrors = onReviewErrors
    }

    public var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.state.evaluations.isEmpty {
                emptyView
            } else {
                List(viewModel.state.evaluations, id: \.id) { evaluation in
                    EvaluationHistoryCard(evaluation: evaluation)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onReviewErrors) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .accessibilityLabel("Repasar errores")
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Aún no tienes evaluaciones")
                .font(MTCTypography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private let historyDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yyyy HH:mm"
    return formatter
}()

private struct EvaluationHistoryCard: View {
    let evaluation: MTCDomain.Evaluation

    private var isApproved: Bool { evaluation.outcome == .approved }
    private var statusColor: Color { isApproved ? .green : .red }
    private var statusText: String { isApproved ? "Aprobado" : "Desaprobado" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(evaluation.categoryTitle)
                        .font(MTCTypography.body.weight(.semibold))
                    Text(historyDateFormatter.string(from: evaluation.date))
                        .font(MTCTypography.caption)
                        .foregroundStyle(.secondary)
                    Text("\(evaluation.totalCorrect)/\(evaluation.totalQuestions) correctas")
                        .font(MTCTypography.body)
                }
                Spacer()
                Text(statusText)
                    .font(MTCTypography.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Con evaluaciones") {
    NavigationStack {
        HistoryView(
            viewModel: HistoryViewModel(evaluationRepository: PreviewEvaluationRepository(evaluations: [
                MTCDomain.Evaluation(
                    id: "1", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
                    totalCorrect: 9, totalIncorrect: 1, totalQuestions: 10,
                    outcome: .approved, date: Date()
                ),
                MTCDomain.Evaluation(
                    id: "2", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
                    totalCorrect: 4, totalIncorrect: 6, totalQuestions: 10,
                    outcome: .rejected, date: Date().addingTimeInterval(-86400)
                ),
            ])),
            onReviewErrors: {}
        )
    }
}

#Preview("Vacío") {
    NavigationStack {
        HistoryView(
            viewModel: HistoryViewModel(evaluationRepository: PreviewEvaluationRepository(evaluations: [])),
            onReviewErrors: {}
        )
    }
}
