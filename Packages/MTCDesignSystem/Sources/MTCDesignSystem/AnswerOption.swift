public enum AnswerOptionState: Sendable, Equatable {
    case unselected
    case selected
    case revealedCorrect
    case revealedIncorrect
    case correctAnswerHint
}

public struct AnswerOption: Identifiable, Sendable, Equatable {
    public let letter: String
    public let text: String
    public let state: AnswerOptionState

    public init(letter: String, text: String, state: AnswerOptionState) {
        self.letter = letter
        self.text = text
        self.state = state
    }

    /// Derived from the option's letter rather than a fresh UUID, so `ForEach(..., id: \.element.id)`
    /// in `QuestionAnswerCard` sees stable identities across repeated per-second view-body rebuilds
    /// (e.g. driven by `QuizView`'s countdown timer) instead of tearing down/rebuilding every row.
    public var id: String { letter }
}
