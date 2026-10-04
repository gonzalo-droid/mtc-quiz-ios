import Testing
@testable import MTCAdsFeature

/// Hand-written fake: records the order of calls and lets each test decide whether an ad is due
/// and whether showing it actually put one on screen.
@MainActor
private final class FakeAdsManager: AdsManaging {
    let bannerAdUnitID = "test-banner"
    let isPremium: () -> Bool = { false }
    var isDue = false
    var adActuallyShows = true
    private(set) var calls: [String] = []

    func preloadPdfInterstitial() { calls.append("preloadPdf") }
    func shouldShowPdfInterstitial() -> Bool { calls.append("shouldPdf"); return isDue }
    func showPdfInterstitial(onDismiss: @escaping (Bool) -> Void) {
        calls.append("showPdf"); onDismiss(adActuallyShows)
    }
    func recordPdfDownload() { calls.append("recordPdf") }

    func preloadEvaluationInterstitial() { calls.append("preloadEvaluation") }
    func shouldShowEvaluationInterstitial() -> Bool { calls.append("shouldEvaluation"); return isDue }
    func showEvaluationInterstitial(onDismiss: @escaping (Bool) -> Void) {
        calls.append("showEvaluation"); onDismiss(adActuallyShows)
    }
    func recordEvaluationStart() { calls.append("recordEvaluation") }
}

@MainActor
@Suite struct AdsGateTests {
    @Test func pdfDownloadCountsBeforeDecidingAndProceedsWithoutAnAdWhenNoneIsDue() {
        let ads = FakeAdsManager()
        var results: [Bool] = []

        ads.gatePdfDownload { results.append($0) }

        #expect(ads.calls == ["recordPdf", "shouldPdf"])
        #expect(results == [false])
    }

    @Test(arguments: [true, false])
    func pdfDownloadShowsTheAdWhenDueAndReportsWhetherItRan(adActuallyShows: Bool) {
        let ads = FakeAdsManager()
        ads.isDue = true
        ads.adActuallyShows = adActuallyShows
        var results: [Bool] = []

        ads.gatePdfDownload { results.append($0) }

        #expect(ads.calls == ["recordPdf", "shouldPdf", "showPdf"])
        #expect(results == [adActuallyShows])
    }

    @Test func pdfGateNeverTouchesTheEvaluationCounter() {
        let ads = FakeAdsManager()
        ads.isDue = true

        ads.gatePdfDownload { _ in }

        #expect(!ads.calls.contains { $0.contains("Evaluation") })
    }

    @Test(arguments: [false, true])
    func evaluationStartFollowsTheSameOrder(isDue: Bool) {
        let ads = FakeAdsManager()
        ads.isDue = isDue
        var results: [Bool] = []

        ads.gateEvaluationStart { results.append($0) }

        #expect(ads.calls == (isDue
            ? ["recordEvaluation", "shouldEvaluation", "showEvaluation"]
            : ["recordEvaluation", "shouldEvaluation"]))
        #expect(results == [isDue])
    }
}
