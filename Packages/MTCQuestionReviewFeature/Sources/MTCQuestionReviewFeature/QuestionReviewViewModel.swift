import MTCDomain
import Observation

@MainActor
@Observable
public final class QuestionReviewViewModel {
    public private(set) var state = QuestionReviewState()

    private let categoryId: String
    private let categoryRepository: CategoryRepository
    private let questionRepository: QuestionRepository

    public init(
        categoryId: String,
        categoryRepository: CategoryRepository,
        questionRepository: QuestionRepository
    ) {
        self.categoryId = categoryId
        self.categoryRepository = categoryRepository
        self.questionRepository = questionRepository
    }

    /// All questions of the category, no randomization, no limit — mirrors Android's
    /// QuestionsScreenViewModel, which is deliberately a different data path than Evaluation's
    /// (which does respect the user's numberOfQuestions preference).
    public func load() async {
        let category = await categoryRepository.category(withId: categoryId)
        guard let category else {
            state = QuestionReviewState(category: nil, questions: [], searchText: state.searchText, isLoading: false)
            return
        }

        let questions = await questionRepository.questions(pathJson: category.pathJson, limit: nil)
        state = QuestionReviewState(category: category, questions: questions, searchText: state.searchText, isLoading: false)
    }

    public func updateSearchText(_ text: String) {
        state.searchText = text
    }

    public var filteredQuestions: [MTCDomain.Question] {
        guard !state.searchText.isEmpty else { return state.questions }
        let normalizedQuery = state.searchText.normalizedForSearch()
        return state.questions.filter { $0.title.normalizedForSearch().contains(normalizedQuery) }
    }
}
