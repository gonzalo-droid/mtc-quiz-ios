import Foundation

public struct Question: Equatable, Sendable, Identifiable {
    public let id: Int
    public let section: String?
    public let category: String?
    public let topic: String
    public let title: String
    public let answer: String
    public let argument: String
    public let options: [String]
    public let images: [String]

    public init(
        id: Int = 0,
        section: String? = "",
        category: String? = "",
        topic: String = "",
        title: String = "",
        answer: String = "",
        argument: String = "",
        options: [String] = [],
        images: [String] = []
    ) {
        self.id = id
        self.section = section
        self.category = category
        self.topic = topic
        self.title = title
        self.answer = answer
        self.argument = argument
        self.options = options
        self.images = images
    }

    /// Ported verbatim from Android's Question.isCorrectAnswer — unknown letters fall through to index 3 ("d"),
    /// not an explicit "d" check. Preserve this fallback exactly; it is Android's real, tested behavior.
    public func isCorrectAnswer(_ index: Int) -> Bool {
        let answerIndex: Int
        switch answer {
        case "a": answerIndex = 0
        case "b": answerIndex = 1
        case "c": answerIndex = 2
        default: answerIndex = 3
        }
        return index == answerIndex
    }

    public func option(for letter: String) -> String {
        let index: Int
        switch letter.lowercased() {
        case "a": index = 0
        case "b": index = 1
        case "c": index = 2
        case "d": index = 3
        default: index = -1
        }
        guard options.indices.contains(index) else { return "Opción no disponible" }
        return options[index]
    }
}

extension Question: Codable {
    enum CodingKeys: String, CodingKey {
        case id, section, category, topic, title, answer, options
        case argument = "fundamento"
        case images = "imagens"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        section = try container.decodeIfPresent(String.self, forKey: .section)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        topic = try container.decodeIfPresent(String.self, forKey: .topic) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        answer = try container.decodeIfPresent(String.self, forKey: .answer) ?? ""
        argument = try container.decodeIfPresent(String.self, forKey: .argument) ?? ""
        options = try container.decodeIfPresent([String].self, forKey: .options) ?? []
        images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
    }
}

/// Mirrors Android's QuestionResponse — every question JSON file is a single top-level
/// object `{ "data": [...] }`, not a bare array.
public struct QuestionResponse: Codable, Sendable {
    public let data: [Question]
}
