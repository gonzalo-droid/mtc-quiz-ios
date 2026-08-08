import Foundation

public struct PDFState: Equatable, Sendable {
    public var pdfURL: URL?
    public var categoryTitle: String
    public var isLoading: Bool

    public init(pdfURL: URL? = nil, categoryTitle: String = "", isLoading: Bool = true) {
        self.pdfURL = pdfURL
        self.categoryTitle = categoryTitle
        self.isLoading = isLoading
    }
}
