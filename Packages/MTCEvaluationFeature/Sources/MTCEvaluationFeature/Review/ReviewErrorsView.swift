import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct ReviewErrorsView: View {
    @State private var viewModel: ReviewErrorsViewModel

    public init(viewModel: ReviewErrorsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.state.frequentErrors.isEmpty {
                emptyView
            } else {
                List {
                    Section {
                        Text("\(viewModel.state.frequentErrors.count) preguntas frecuentes — desliza para descartar")
                            .font(MTCTypography.caption)
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(viewModel.state.frequentErrors) { error in
                        FrequentErrorCard(error: error)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    Task { await viewModel.dismissQuestion(error.questionId) }
                                } label: {
                                    Label("Aprendida", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Repaso de errores")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("¡No tienes errores frecuentes!")
                .font(MTCTypography.body.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Las preguntas que falles 3 o más veces aparecerán aquí.\nDesliza para descartar las que ya aprendiste.")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FrequentErrorCard: View {
    let error: FrequentError

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(error.question)
                    .font(MTCTypography.body.weight(.medium))
                Spacer()
                Text("\(error.failCount)x")
                    .font(MTCTypography.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !error.lastWrongAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tu respuesta")
                        .font(MTCTypography.caption)
                        .foregroundStyle(.red.opacity(0.7))
                    Text(error.lastWrongAnswer)
                        .font(MTCTypography.caption)
                        .foregroundStyle(.red)
                }
            }

            if !error.correctAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Respuesta correcta")
                        .font(MTCTypography.caption)
                        .foregroundStyle(.green.opacity(0.7))
                    Text(error.correctAnswer)
                        .font(MTCTypography.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct PreviewEvaluationRepository: EvaluationRepository {
    let evaluations: [MTCDomain.Evaluation]
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { nil }
    func allEvaluations() async -> [MTCDomain.Evaluation] { evaluations }
}

private struct PreviewDismissedQuestionRepository: DismissedQuestionRepository {
    func dismiss(questionId: Int) async {}
    func dismissedQuestionIds() async -> Set<Int> { [] }
}

private func previewFrequentErrorEvaluation() -> MTCDomain.Evaluation {
    MTCDomain.Evaluation(
        id: UUID().uuidString, categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
        totalCorrect: 0, totalIncorrect: 1, totalQuestions: 1, outcome: .rejected,
        date: Date(),
        questionResults: [
            MTCDomain.QuestionResult(
                id: UUID().uuidString, questionId: 5, question: "¿Pregunta frecuente?",
                option: "a) Incorrecta", isCorrect: false, correctAnswer: "c) Correcta"
            ),
        ]
    )
}

#Preview("Con errores frecuentes") {
    NavigationStack {
        ReviewErrorsView(
            viewModel: ReviewErrorsViewModel(
                evaluationRepository: PreviewEvaluationRepository(evaluations: [
                    // 3 separate evaluations, each with one failed result for the same
                    // questionId: 5 — the 3-fail threshold needs 3 across evaluations, not
                    // 3 within one, matching how the real app records one Evaluation per quiz.
                    previewFrequentErrorEvaluation(),
                    previewFrequentErrorEvaluation(),
                    previewFrequentErrorEvaluation(),
                ]),
                dismissedQuestionRepository: PreviewDismissedQuestionRepository()
            )
        )
    }
}

#Preview("Vacío") {
    NavigationStack {
        ReviewErrorsView(
            viewModel: ReviewErrorsViewModel(
                evaluationRepository: PreviewEvaluationRepository(evaluations: []),
                dismissedQuestionRepository: PreviewDismissedQuestionRepository()
            )
        )
    }
}
