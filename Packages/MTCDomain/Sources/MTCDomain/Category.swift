public struct Category: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let category: String
    public let classType: String
    public let description: String
    public let pdf: String
    public let pathJson: String

    public init(
        id: String,
        title: String,
        category: String,
        classType: String,
        description: String,
        pdf: String,
        pathJson: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.classType = classType
        self.description = description
        self.pdf = pdf
        self.pathJson = pathJson
    }

    /// Mirrors `Category.examId` in Android's core:domain — derived from `pathJson`,
    /// never stored, so there's exactly one place that can drift from the questions file name.
    public var examId: String {
        let suffix = "_questions.json"
        guard pathJson.hasSuffix(suffix) else { return pathJson }
        return String(pathJson.dropLast(suffix.count))
    }
}
