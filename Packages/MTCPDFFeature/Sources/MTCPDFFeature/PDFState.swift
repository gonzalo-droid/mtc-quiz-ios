import Foundation

public struct PDFState: Equatable, Sendable {
    public var pdfURL: URL?
    public var categoryTitle: String
    public var isLoading: Bool
    /// "Descarga gratis con un anuncio": asks before the rewarded ad, as AdMob requires.
    public var isRewardPromptPresented = false
    /// The user closed the rewarded ad before earning the download.
    public var isRewardSkippedPresented = false
    public var isShareSheetPresented = false

    public init(pdfURL: URL? = nil, categoryTitle: String = "", isLoading: Bool = true) {
        self.pdfURL = pdfURL
        self.categoryTitle = categoryTitle
        self.isLoading = isLoading
    }
}
