import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct SummaryView: View {
    @State private var viewModel: SummaryViewModel
    private let onFinish: () -> Void

    @State private var animatedPercentage: Double = 0

    public init(viewModel: SummaryViewModel, onFinish: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinish = onFinish
    }

    public var body: some View {
        Group {
            if let evaluation = viewModel.state.evaluation {
                content(for: evaluation)
            } else if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No se encontró el resultado de la evaluación.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func content(for evaluation: MTCDomain.Evaluation) -> some View {
        let isApproved = evaluation.outcome == .approved
        let percentage = evaluation.totalQuestions > 0
            ? Int((Double(evaluation.totalCorrect) / Double(evaluation.totalQuestions)) * 100)
            : 0

        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: animatedPercentage / 100)
                        .stroke(
                            isApproved ? Color.green : Color.red,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.0), value: animatedPercentage)
                    Text("\(Int(animatedPercentage))%")
                        .font(MTCTypography.largeTitle)
                }
                .frame(width: 160, height: 160)
                .task { animatedPercentage = Double(percentage) }

                Label(
                    isApproved ? "Aprobado" : "Rechazado",
                    systemImage: isApproved ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(MTCTypography.headline)
                .foregroundStyle(isApproved ? .green : .red)

                Text(evaluation.date.formatted(date: .long, time: .omitted))
                    .font(MTCTypography.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    statCard(value: evaluation.totalCorrect, label: "Correctas")
                    statCard(value: evaluation.totalIncorrect, label: "Incorrectas")
                    statCard(value: evaluation.totalQuestions, label: "Preguntas")
                }

                Text(
                    isApproved
                        ? "¡Felicidades! Estás listo para rendir el examen del MTC."
                        : "Sigue practicando. Repasa tus errores frecuentes para mejorar."
                )
                .font(MTCTypography.body)
                .multilineTextAlignment(.center)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button(action: onFinish) {
                    Text("Finalizar evaluación")
                        .font(MTCTypography.headline)
                        .foregroundStyle(MTCColor.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .background(MTCColor.primary)
                .clipShape(Capsule())
            }
            .padding(16)
        }
    }

    private func statCard(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(MTCTypography.title)
            Text(label)
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct PreviewCategoryRepository: CategoryRepository {
    func categories() async -> [MTCDomain.Category] { [] }
    func category(withId id: String) async -> MTCDomain.Category? { nil }
}

private struct PreviewEvaluationRepository: EvaluationRepository {
    let evaluationToReturn: MTCDomain.Evaluation?
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { evaluationToReturn }
    func allEvaluations() async -> [MTCDomain.Evaluation] { [] }
}

#Preview("Aprobado") {
    NavigationStack {
        SummaryView(
            viewModel: SummaryViewModel(
                categoryId: "1", evaluationId: "eval-1",
                categoryRepository: PreviewCategoryRepository(),
                evaluationRepository: PreviewEvaluationRepository(
                    evaluationToReturn: MTCDomain.Evaluation(
                        id: "eval-1", totalCorrect: 9, totalIncorrect: 1, totalQuestions: 10,
                        outcome: .approved
                    )
                )
            ),
            onFinish: {}
        )
    }
}

#Preview("Rechazado") {
    NavigationStack {
        SummaryView(
            viewModel: SummaryViewModel(
                categoryId: "1", evaluationId: "eval-2",
                categoryRepository: PreviewCategoryRepository(),
                evaluationRepository: PreviewEvaluationRepository(
                    evaluationToReturn: MTCDomain.Evaluation(
                        id: "eval-2", totalCorrect: 3, totalIncorrect: 7, totalQuestions: 10,
                        outcome: .rejected
                    )
                )
            ),
            onFinish: {}
        )
    }
}
