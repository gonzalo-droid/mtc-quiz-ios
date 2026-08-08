import Foundation

public protocol QuestionImageResolver: Sendable {
    /// `name` is a bare image name with no extension, e.g. "q4_a_a2a" (matches Question.images entries).
    func url(forImageName name: String) -> URL?
}
