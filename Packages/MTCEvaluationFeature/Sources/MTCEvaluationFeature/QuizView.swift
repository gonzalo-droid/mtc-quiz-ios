import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct QuizView: View {
    @State private var viewModel: QuizViewModel
    private let imageResolver: QuestionImageResolver
    private let preferencesRepository: PreferencesRepository
    private let onCancel: () -> Void
    private let onFinished: (String) -> Void

    @State private var secondsRemaining: Int = 0
    @State private var showCancelConfirmation = false
    @State private var showTimeUpDialog = false

    public init(
        viewModel: QuizViewModel,
        imageResolver: QuestionImageResolver,
        preferencesRepository: PreferencesRepository,
        onCancel: @escaping () -> Void,
        onFinished: @escaping (String) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.imageResolver = imageResolver
        self.preferencesRepository = preferencesRepository
        self.onCancel = onCancel
        self.onFinished = onFinished
    }

    public var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.state.questions.isEmpty {
                Text("No se encontraron preguntas para esta categoría.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showCancelConfirmation = true
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .task {
            await viewModel.load()
            viewModel.onFinished = onFinished
        }
        .alert("¿Cancelar evaluación?", isPresented: $showCancelConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Salir", role: .destructive) { onCancel() }
        } message: {
            Text("Perderás el progreso de esta evaluación.")
        }
        .alert("Tiempo terminado", isPresented: $showTimeUpDialog) {
            Button("Finalizar") {
                Task { await viewModel.finishQuiz() }
            }
        } message: {
            Text("Se acabó el tiempo para esta evaluación.")
        }
        .task(id: viewModel.state.isLoading) {
            guard !viewModel.state.isLoading else { return }
            let minutes = await preferencesRepository.evaluationTimeMinutes
            guard minutes > 0 else { return }
            secondsRemaining = minutes * 60
            while secondsRemaining > 0 && !viewModel.state.isFinishing {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                secondsRemaining -= 1
            }
            // Only surface the time's-up dialog if the loop exited because time actually ran
            // out — not because the quiz already finished (e.g. QuizView is still alive
            // underneath a pushed Summary screen; see Finding 2 in the final review).
            if !viewModel.state.isFinishing {
                showTimeUpDialog = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Pregunta \(viewModel.state.currentIndex + 1) de \(viewModel.state.questions.count)")
                    .font(MTCTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedTime(secondsRemaining))
                    .font(MTCTypography.headline)
                    .foregroundStyle(MTCColor.primary)
            }

            ScrollView {
                QuestionAnswerCard(
                    title: viewModel.state.currentQuestion.title,
                    options: answerOptions,
                    imageURLs: viewModel.state.currentQuestion.images.compactMap(imageResolver.url(forImageName:)),
                    onSelectOption: { viewModel.selectOption(at: $0) }
                )
            }

            Button(action: primaryAction) {
                Text(primaryButtonLabel)
                    .font(MTCTypography.headline)
                    .foregroundStyle(MTCColor.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(MTCColor.primary)
            .clipShape(Capsule())
            .disabled(viewModel.state.selectedOptionIndex == nil || viewModel.state.isFinishing)
        }
        .padding(16)
    }

    private var answerOptions: [AnswerOption] {
        let question = viewModel.state.currentQuestion
        let selected = viewModel.state.selectedOptionIndex
        let verified = viewModel.state.isAnswerVerified

        return question.options.enumerated().map { index, rawOption in
            let letter = Character(UnicodeScalar(65 + index)!)
            let text = rawOption.strippingOptionLetterPrefix()

            let state: AnswerOptionState
            if verified {
                let isCorrectIndex = question.isCorrectAnswer(index)
                if index == selected, isCorrectIndex {
                    state = .revealedCorrect
                } else if index == selected {
                    state = .revealedIncorrect
                } else if isCorrectIndex {
                    state = .correctAnswerHint
                } else {
                    state = .unselected
                }
            } else if index == selected {
                state = .selected
            } else {
                state = .unselected
            }

            return AnswerOption(letter: String(letter), text: text, state: state)
        }
    }

    private var primaryButtonLabel: String {
        if !viewModel.state.isAnswerVerified { return "Verificar" }
        return viewModel.isLastQuestion ? "Finalizar" : "Siguiente"
    }

    private func primaryAction() {
        if !viewModel.state.isAnswerVerified {
            viewModel.verifyAnswer()
        } else if viewModel.isLastQuestion {
            Task { await viewModel.finishQuiz() }
        } else {
            viewModel.nextQuestion()
        }
    }

    private func formattedTime(_ totalSeconds: Int) -> String {
        String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private let previewCategory = MTCDomain.Category(
    id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
    description: "d", pdf: "p.pdf", pathJson: "a1_questions.json"
)

private let previewQuestions: [MTCDomain.Question] = [
    MTCDomain.Question(
        id: 1, topic: "t", title: "¿Está permitido en la vía?", answer: "c",
        options: [
            "a) Recoger o dejar pasajeros en cualquier lugar", "b) Dejar animales sueltos",
            "c) Recoger o dejar pasajeros en lugares autorizados", "d) Ejercer el comercio ambulatorio",
        ]
    ),
]

private struct PreviewCategoryRepository: CategoryRepository {
    func categories() async -> [MTCDomain.Category] { [previewCategory] }
    func category(withId id: String) async -> MTCDomain.Category? { previewCategory }
}

private struct PreviewQuestionRepository: QuestionRepository {
    func questions(pathJson: String, limit: Int?) async -> [MTCDomain.Question] { previewQuestions }
}

private struct PreviewEvaluationRepository: EvaluationRepository {
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { nil }
    func allEvaluations() async -> [MTCDomain.Evaluation] { [] }
}

private struct PreviewPreferencesRepository: PreferencesRepository {
    var streak: Int { get async { 0 } }
    var userName: String { get async { "" } }
    var numberOfQuestions: Int { get async { 1 } }
    var evaluationTimeMinutes: Int { get async { 40 } }
    var passPercentage: Int { get async { 80 } }
    var themeMode: String { get async { "system" } }

    func setThemeMode(_ mode: String) async {}
    func setNumberOfQuestions(_ value: Int) async {}
    func setEvaluationTimeMinutes(_ value: Int) async {}
    func setPassPercentage(_ value: Int) async {}
}

private struct PreviewImageResolver: QuestionImageResolver {
    func url(forImageName name: String) -> URL? { nil }
}

#Preview("Evaluación") {
    NavigationStack {
        QuizView(
            viewModel: QuizViewModel(
                categoryId: "1",
                categoryRepository: PreviewCategoryRepository(),
                questionRepository: PreviewQuestionRepository(),
                evaluationRepository: PreviewEvaluationRepository(),
                preferencesRepository: PreviewPreferencesRepository()
            ),
            imageResolver: PreviewImageResolver(),
            preferencesRepository: PreviewPreferencesRepository(),
            onCancel: {},
            onFinished: { _ in }
        )
    }
}
