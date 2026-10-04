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
        // Android shows the category title, small and bold, in its top bar; the inline title is
        // iOS's version of that.
        .navigationTitle(viewModel.state.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showCancelConfirmation = true
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Cancelar evaluación")
            }
            if !viewModel.state.isLoading, !viewModel.state.questions.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text(formattedTime(secondsRemaining))
                        .font(MTCTypography.headline)
                        .monospacedDigit()
                        .foregroundStyle(MTCColor.primary)
                        .accessibilityLabel("Tiempo restante \(formattedTime(secondsRemaining))")
                }
            }
        }
        .task {
            await viewModel.load()
            viewModel.onFinished = onFinished
        }
        // Copy shared with Android's EvaluationScreen, word for word.
        .alert("¿Cancelar evaluación?", isPresented: $showCancelConfirmation) {
            Button("No", role: .cancel) {}
            Button("Sí, cancelar", role: .destructive) { onCancel() }
        } message: {
            Text("Si cancelas ahora, se perderá todo el progreso de tu evaluación.")
        }
        .alert("Tiempo finalizado", isPresented: $showTimeUpDialog) {
            Button("Finalizar evaluación") {
                Task { await viewModel.finishQuiz() }
            }
        } message: {
            Text("Tu tiempo ha terminado. La evaluación se ha finalizado.")
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
            // Same header as Android's LinearProgressComponent: the bar with its "n/total" count
            // beside it. The bar itself is hidden from VoiceOver, which reads the count instead.
            HStack(spacing: 12) {
                ProgressView(value: viewModel.state.progress)
                    .tint(MTCColor.primary)
                    .animation(.easeInOut, value: viewModel.state.progress)
                    .accessibilityHidden(true)
                Text(viewModel.state.positionText)
                    .font(MTCTypography.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Pregunta \(viewModel.state.currentIndex + 1) de \(viewModel.state.questions.count)")
            }

            ScrollView {
                QuestionAnswerCard(
                    title: viewModel.state.numberedQuestionTitle,
                    options: answerOptions,
                    imageURLs: viewModel.state.currentQuestion.images.compactMap(imageResolver.url(forImageName:)),
                    onSelectOption: { viewModel.selectOption(at: $0) }
                )
            }

            Button(action: primaryAction) {
                Text(viewModel.state.primaryButtonTitle)
                    .font(MTCTypography.headline)
                    .foregroundStyle(MTCColor.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            // The background is drawn outside the Button, so SwiftUI's own disabled styling never
            // reached it: the button stayed fully coloured while doing nothing. Dim it instead.
            .background(MTCColor.primary.opacity(viewModel.state.canSubmit ? 1 : 0.35))
            .clipShape(Capsule())
            .disabled(!viewModel.state.canSubmit)
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
    func recordStudySession() async {}
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
