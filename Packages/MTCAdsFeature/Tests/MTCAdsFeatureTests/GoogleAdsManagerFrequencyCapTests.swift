import Testing
import Foundation
@testable import MTCAdsFeature

/// Exercises only the frequency-cap counter logic (`record*`/`shouldShow*`), which is pure
/// UserDefaults bookkeeping — the actual ad load/present calls hit the network and aren't
/// covered here, same limitation Android's equivalent unit tests have for `AdsManagerImpl`.
@MainActor
@Suite struct GoogleAdsManagerFrequencyCapTests {
    private func makeManager(suiteName: String, isPremium: Bool = false) -> GoogleAdsManager {
        let defaults = UserDefaults(suiteName: suiteName)!
        return GoogleAdsManager(
            bannerAdUnitID: "test-banner",
            interstitialAdUnitID: "test-interstitial",
            isPremium: { isPremium },
            defaults: defaults
        )
    }

    @Test func doesNotShowBeforeThirdDownload() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let manager = makeManager(suiteName: suiteName)

        manager.recordPdfDownload()
        #expect(manager.shouldShowPdfInterstitial() == false)
        manager.recordPdfDownload()
        #expect(manager.shouldShowPdfInterstitial() == false)

        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    @Test func showsOnEveryThirdDownload() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let manager = makeManager(suiteName: suiteName)

        for _ in 1...3 { manager.recordPdfDownload() }
        #expect(manager.shouldShowPdfInterstitial() == true)

        for _ in 1...2 { manager.recordPdfDownload() }
        #expect(manager.shouldShowPdfInterstitial() == false)

        manager.recordPdfDownload()
        #expect(manager.shouldShowPdfInterstitial() == true)

        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    @Test func neverShowsWhenPremium() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let manager = makeManager(suiteName: suiteName, isPremium: true)

        for _ in 1...3 { manager.recordPdfDownload() }
        #expect(manager.shouldShowPdfInterstitial() == false)
        #expect(manager.shouldShowEvaluationInterstitial() == false)

        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    @Test func evaluationCounterIsIndependentOfPdfCounter() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let manager = makeManager(suiteName: suiteName)

        for _ in 1...3 { manager.recordPdfDownload() }
        #expect(manager.shouldShowPdfInterstitial() == true)
        #expect(manager.shouldShowEvaluationInterstitial() == false)

        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }
}
