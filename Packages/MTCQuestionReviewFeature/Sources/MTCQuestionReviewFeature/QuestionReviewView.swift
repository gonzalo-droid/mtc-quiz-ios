import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct QuestionReviewView: View {
    @State private var viewModel: QuestionReviewViewModel
    private let imageResolver: QuestionImageResolver

    public init(viewModel: QuestionReviewViewModel, imageResolver: QuestionImageResolver) {
        _viewModel = State(initialValue: viewModel)
        self.imageResolver = imageResolver
    }

    public var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.state.category == nil {
                Text("No se encontró la categoría.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                QuestionListContent(viewModel: viewModel, imageResolver: imageResolver)
            }
        }
        .navigationTitle(viewModel.state.category?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: Binding(
                get: { viewModel.state.searchText },
                set: { viewModel.updateSearchText($0) }
            ),
            prompt: "Buscar"
        )
        .task {
            await viewModel.load()
        }
    }
}

/// Split out from `QuestionReviewView` so it can read `@Environment(\.isSearching)` — that
/// environment value is only visible to descendants of the view carrying `.searchable`, not to
/// the view applying the modifier itself.
private struct QuestionListContent: View {
    @Environment(\.isSearching) private var isSearching
    @State private var visibleIndices: Set<Int> = []

    let viewModel: QuestionReviewViewModel
    let imageResolver: QuestionImageResolver

    var body: some View {
        let filtered = viewModel.filteredQuestions

        VStack(spacing: 8) {
            if !isSearching, !filtered.isEmpty {
                progressBar(total: filtered.count)
            }

            if filtered.isEmpty {
                emptyResultsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(filtered.enumerated()), id: \.offset) { index, question in
                            QuestionAnswerCard(
                                title: "\(question.id).- \(question.title)",
                                options: answerOptions(for: question),
                                imageURLs: question.images.compactMap(imageResolver.url(forImageName:)),
                                onSelectOption: { _ in }
                            )
                            .allowsHitTesting(false)
                            .onAppear { visibleIndices.insert(index) }
                            .onDisappear { visibleIndices.remove(index) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    /// Mirrors Android's LinearProgressComponent math exactly: numerator is
    /// `firstVisibleItem + 2` (not +1 — a real, intentional-looking Android quirk, ported as-is),
    /// denominator/progress-fraction both use the filtered count (equal to the full question
    /// count here since the bar is hidden while `isSearching`, at which point filtered == all).
    @ViewBuilder
    private func progressBar(total: Int) -> some View {
        let firstVisible = visibleIndices.min() ?? 0
        let lastVisible = visibleIndices.max() ?? 0
        let progress = total > 1 ? Double(lastVisible) / Double(total - 1) : 0

        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: progress)
            Text("\(firstVisible + 2)/\(total)")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var emptyResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Sin resultados encontrados")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    /// No interaction/verification here (read-only review mode) — every option's state is
    /// already final: correct answer revealed, everything else unselected. Matches Android's
    /// QuestionsScreen, which renders `AnswerOptionState.RevealedCorrect` unconditionally too.
    private func answerOptions(for question: MTCDomain.Question) -> [AnswerOption] {
        question.options.enumerated().map { index, rawOption in
            let letter = Character(UnicodeScalar(65 + index)!)
            let text = rawOption.strippingOptionLetterPrefix()
            let state: AnswerOptionState = question.isCorrectAnswer(index) ? .revealedCorrect : .unselected
            return AnswerOption(letter: String(letter), text: text, state: state)
        }
    }
}

private let previewCategory = MTCDomain.Category(
    id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
    description: "d", pdf: "p.pdf", pathJson: "a1_questions.json"
)

private let previewQuestions: [MTCDomain.Question] = [
    MTCDomain.Question(
        id: 1, topic: "t", title: "Está permitido en la vía:", answer: "c",
        options: [
            "a) Recoger o dejar pasajeros o carga en cualquier lugar",
            "b) Dejar animales sueltos",
            "c) Recoger o dejar pasajeros en lugares autorizados",
            "d) Ejercer el comercio ambulatorio",
        ]
    ),
    MTCDomain.Question(
        id: 2, topic: "t", title: "Respecto de los dispositivos de control:", answer: "b",
        options: [
            "a) Solo los peatones están obligados a su obediencia",
            "b) Los conductores y los peatones están obligados a su obediencia",
            "c) Solo los conductores están obligados a su obediencia",
            "d) Nadie está obligado a su obediencia",
        ]
    ),
]

private struct PreviewCategoryRepository: CategoryRepository {
    func categories() async -> [MTCDomain.Category] { [previewCategory] }
    func category(withId id: String) async -> MTCDomain.Category? {
        id == previewCategory.id ? previewCategory : nil
    }
}

private struct PreviewQuestionRepository: QuestionRepository {
    func questions(pathJson: String, limit: Int?) async -> [MTCDomain.Question] { previewQuestions }
}

private struct PreviewImageResolver: QuestionImageResolver {
    func url(forImageName name: String) -> URL? { nil }
}

#Preview("Lista completa") {
    NavigationStack {
        QuestionReviewView(
            viewModel: QuestionReviewViewModel(
                categoryId: "1",
                categoryRepository: PreviewCategoryRepository(),
                questionRepository: PreviewQuestionRepository()
            ),
            imageResolver: PreviewImageResolver()
        )
    }
}
