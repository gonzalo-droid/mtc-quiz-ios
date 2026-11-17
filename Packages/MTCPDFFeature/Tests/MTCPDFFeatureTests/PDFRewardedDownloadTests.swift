import Testing
import MTCDomain
@testable import MTCPDFFeature

/// "Descargar" goes through the rewarded ad when one is ready, and never blocks the PDF when there
/// is none. Same rules as Android's `PdfScreenViewModel`.
@Suite @MainActor struct PDFRewardedDownloadTests {
    private func makeViewModel(
        adReady: Bool,
        mayDownload: Bool = true,
        onShow: @escaping () -> Void = {}
    ) -> PDFViewModel {
        PDFViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: []),
            isRewardedAdReady: { adReady },
            showRewardedAd: { completion in
                onShow()
                completion(mayDownload)
            }
        )
    }

    @Test func withoutAnAdTheShareSheetOpensStraightAway() {
        var shown = 0
        let viewModel = makeViewModel(adReady: false, onShow: { shown += 1 })

        viewModel.downloadTapped()

        #expect(viewModel.state.isShareSheetPresented)
        #expect(!viewModel.state.isRewardPromptPresented)
        #expect(shown == 0)
    }

    @Test func withAnAdItAsksFirstAndShowsNothingYet() {
        var shown = 0
        let viewModel = makeViewModel(adReady: true, onShow: { shown += 1 })

        viewModel.downloadTapped()

        #expect(viewModel.state.isRewardPromptPresented)
        #expect(!viewModel.state.isShareSheetPresented)
        #expect(shown == 0)
    }

    @Test func watchingTheAdToTheEndOpensTheShareSheet() {
        let viewModel = makeViewModel(adReady: true, mayDownload: true)

        viewModel.downloadTapped()
        viewModel.watchAdTapped()

        #expect(!viewModel.state.isRewardPromptPresented)
        #expect(viewModel.state.isShareSheetPresented)
        #expect(!viewModel.state.isRewardSkippedPresented)
    }

    @Test func closingTheAdEarlyExplainsWhyAndDoesNotDownload() {
        let viewModel = makeViewModel(adReady: true, mayDownload: false)

        viewModel.downloadTapped()
        viewModel.watchAdTapped()

        #expect(!viewModel.state.isShareSheetPresented)
        #expect(viewModel.state.isRewardSkippedPresented)
    }

    @Test func cancellingThePromptDoesNothing() {
        var shown = 0
        let viewModel = makeViewModel(adReady: true, onShow: { shown += 1 })

        viewModel.downloadTapped()
        viewModel.setRewardPromptPresented(false)

        #expect(!viewModel.state.isShareSheetPresented)
        #expect(shown == 0)
    }

    @Test func theDefaultsDownloadWithoutAnyAd() {
        let viewModel = PDFViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [])
        )

        viewModel.downloadTapped()

        #expect(viewModel.state.isShareSheetPresented)
    }
}
