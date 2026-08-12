import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct StatsView: View {
    @State private var viewModel: StatsViewModel

    public init(viewModel: StatsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.state.totalEvaluations == 0 {
                emptyView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryRow
                        approvalRateCard
                        questionsCard
                        if !viewModel.state.categoryStats.isEmpty {
                            Text("Rendimiento por categoría")
                                .font(MTCTypography.body.weight(.semibold))
                            ForEach(viewModel.state.categoryStats, id: \.categoryTitle) { stat in
                                CategoryStatCard(stat: stat)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Estadísticas")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Aún no tienes estadísticas")
                .font(MTCTypography.body.weight(.semibold))
            Text("Completa evaluaciones para ver tu progreso")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Evaluaciones", value: "\(viewModel.state.totalEvaluations)", icon: "doc.text.fill", color: MTCColor.primary)
            StatCard(title: "Aprobadas", value: "\(viewModel.state.totalApproved)", icon: "checkmark.circle.fill", color: .green)
            StatCard(title: "Reprobadas", value: "\(viewModel.state.totalRejected)", icon: "xmark.circle.fill", color: .red)
        }
    }

    private var approvalRateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasa de aprobación")
                .font(MTCTypography.body.weight(.semibold))
            ProgressView(value: viewModel.state.approvalRate)
                .tint(.green)
            Text("\(Int(viewModel.state.approvalRate * 100))%")
                .font(MTCTypography.title)
                .foregroundStyle(.green)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var questionsCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Preguntas respondidas")
                    .font(MTCTypography.body.weight(.semibold))
                Text("\(viewModel.state.totalQuestionsAnswered)")
                    .font(MTCTypography.title)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Correctas")
                    .font(MTCTypography.body.weight(.semibold))
                Text("\(viewModel.state.totalCorrectAnswers)")
                    .font(MTCTypography.title)
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(value)
                .font(MTCTypography.title)
                .foregroundStyle(color)
            Text(title)
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct CategoryStatCard: View {
    let stat: CategoryStat

    private var barColor: Color { stat.approvalRate >= 0.7 ? .green : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.categoryTitle)
                    .font(MTCTypography.body.weight(.medium))
                Spacer()
                Text("\(Int(stat.approvalRate * 100))%")
                    .font(MTCTypography.body.weight(.bold))
            }
            ProgressView(value: stat.approvalRate)
                .tint(barColor)
            Text("\(stat.evaluationCount) evaluaciones")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Con datos") {
    NavigationStack {
        StatsView(
            viewModel: StatsViewModel(evaluationRepository: PreviewEvaluationRepository(evaluations: [
                MTCDomain.Evaluation(
                    id: "1", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
                    totalCorrect: 9, totalIncorrect: 1, totalQuestions: 10,
                    outcome: .approved, date: Date()
                ),
                MTCDomain.Evaluation(
                    id: "2", categoryId: "2", categoryTitle: "CLASE A - CATEGORIA II-A",
                    totalCorrect: 4, totalIncorrect: 6, totalQuestions: 10,
                    outcome: .rejected, date: Date()
                ),
            ]))
        )
    }
}

#Preview("Vacío") {
    NavigationStack {
        StatsView(viewModel: StatsViewModel(evaluationRepository: PreviewEvaluationRepository(evaluations: [])))
    }
}
