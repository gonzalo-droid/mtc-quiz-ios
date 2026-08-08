import Foundation
import MTCDomain

public final class LocalQuestionImageResolver: QuestionImageResolver {
    public init() {}

    public func url(forImageName name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "webp", subdirectory: "Images")
    }
}
