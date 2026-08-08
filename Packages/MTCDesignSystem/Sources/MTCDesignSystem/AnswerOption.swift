import Foundation

public enum AnswerOptionState: Sendable, Equatable {
    case unselected
    case selected
    case revealedCorrect
    case revealedIncorrect
    case correctAnswerHint
}

public struct AnswerOption: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let letter: String
    public let text: String
    public let state: AnswerOptionState

    public init(id: UUID = UUID(), letter: String, text: String, state: AnswerOptionState) {
        self.id = id
        self.letter = letter
        self.text = text
        self.state = state
    }
}
