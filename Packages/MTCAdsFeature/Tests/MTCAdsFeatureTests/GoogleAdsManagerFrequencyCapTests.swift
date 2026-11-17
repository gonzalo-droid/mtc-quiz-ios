import Testing
import Foundation
@testable import MTCAdsFeature

/// Exercises only the frequency-cap counter logic (`record*`/`shouldShow*`), which is pure
/// UserDefaults bookkeeping — the actual ad load/present calls hit the network and aren't
/// covered here, same limitation Android's equivalent unit tests have for `AdsManagerImpl`.
/// Only the evaluation interstitial has a counter: the PDF download uses a rewarded ad every time.
@MainActor
@Suite struct GoogleAdsManagerFrequencyCapTests {
    private func makeManager(suiteName: String, isPremium: Bool = false) -> GoogleAdsManager {
        let defaults = UserDefaults(suiteName: suiteName)!
        return GoogleAdsManager(
            bannerAdUnitID: "test-banner",
            interstitialAdUnitID: "test-interstitial",
            pdfRewardedAdUnitID: "test-rewarded",
            isPremium: { isPremium },
            defaults: defaults
        )
    }

    @Test func doesNotShowBeforeThirdEvaluation() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let manager = makeManager(suiteName: suiteName)

        manager.recordEvaluationStart()
        #expect(manager.shouldShowEvaluationInterstitial() == false)
        manager.recordEvaluationStart()
        #expect(manager.shouldShowEvaluationInterstitial() == false)

        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    @Test func showsOnEveryThirdEvaluation() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let manager = makeManager(suiteName: suiteName)

        for _ in 1...3 { manager.recordEvaluationStart() }
        #expect(manager.shouldShowEvaluationInterstitial() == true)

        for _ in 1...2 { manager.recordEvaluationStart() }
        #expect(manager.shouldShowEvaluationInterstitial() == false)

        manager.recordEvaluationStart()
        #expect(manager.shouldShowEvaluationInterstitial() == true)

        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    @Test func neverShowsWhenPremium() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let manager = makeManager(suiteName: suiteName, isPremium: true)

        for _ in 1...3 { manager.recordEvaluationStart() }
        #expect(manager.shouldShowEvaluationInterstitial() == false)

        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }
}
