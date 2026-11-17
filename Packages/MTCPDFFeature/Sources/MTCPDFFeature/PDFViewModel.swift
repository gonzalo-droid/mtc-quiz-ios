import Foundation
import MTCDomain
import Observation

@MainActor
@Observable
public final class PDFViewModel {
    public private(set) var state = PDFState()

    private let categoryId: String
    private let categoryRepository: CategoryRepository
    private let isRewardedAdReady: () -> Bool
    private let showRewardedAd: (_ completion: @escaping (_ mayDownload: Bool) -> Void) -> Void

    /// - Parameters:
    ///   - isRewardedAdReady: whether a rewarded ad is loaded. When it is false (premium, no
    ///     consent, no network, no inventory) "Descargar" opens the share sheet straight away: a
    ///     PDF is never blocked for lack of an ad.
    ///   - showRewardedAd: shows the ad and calls back once with whether the download may go on —
    ///     true when the reward was earned or the ad failed to show, false when the user closed
    ///     it early. The shell maps `MTCAdsFeature`'s `RewardedOutcome` onto it, since a feature
    ///     never depends on another.
    public init(
        categoryId: String,
        categoryRepository: CategoryRepository,
        isRewardedAdReady: @escaping () -> Bool = { false },
        showRewardedAd: @escaping (_ completion: @escaping (_ mayDownload: Bool) -> Void) -> Void = { $0(true) }
    ) {
        self.categoryId = categoryId
        self.categoryRepository = categoryRepository
        self.isRewardedAdReady = isRewardedAdReady
        self.showRewardedAd = showRewardedAd
    }

    public func load() async {
        guard let category = await categoryRepository.category(withId: categoryId) else {
            state.pdfURL = nil
            state.categoryTitle = ""
            state.isLoading = false
            return
        }

        let filename = (category.pdf as NSString).deletingPathExtension
        state.pdfURL = Bundle.module.url(forResource: filename, withExtension: "pdf")
        state.categoryTitle = category.category
        state.isLoading = false
    }

    /// "Descargar". Android's `PdfScreenViewModel.onDownloadClicked()`.
    public func downloadTapped() {
        if isRewardedAdReady() {
            state.isRewardPromptPresented = true
        } else {
            state.isShareSheetPresented = true
        }
    }

    /// "Ver anuncio y descargar" in the prompt.
    public func watchAdTapped() {
        state.isRewardPromptPresented = false
        showRewardedAd { [weak self] mayDownload in
            if mayDownload {
                self?.state.isShareSheetPresented = true
            } else {
                self?.state.isRewardSkippedPresented = true
            }
        }
    }

    public func setRewardPromptPresented(_ isPresented: Bool) {
        state.isRewardPromptPresented = isPresented
    }

    public func setRewardSkippedPresented(_ isPresented: Bool) {
        state.isRewardSkippedPresented = isPresented
    }

    public func setShareSheetPresented(_ isPresented: Bool) {
        state.isShareSheetPresented = isPresented
    }
}
