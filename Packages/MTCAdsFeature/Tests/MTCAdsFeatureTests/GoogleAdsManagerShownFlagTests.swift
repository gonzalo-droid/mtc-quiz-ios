import Testing
import Foundation
@testable import MTCAdsFeature

/// The callback reports whether an ad was actually presented, which is what decides if the premium
/// upsell is offered. Only the "nothing was shown" paths are reachable without the network: with no
/// preloaded ad, or for a premium user, the manager must call back with `false` rather than
/// pretending an ad ran. (Android calls its dismiss callback in both cases with no such flag, which
/// is why it offers "¿Cansado de los anuncios?" after showing none.)
///
/// The PDF's rewarded ad reports the same way: with nothing loaded it is `.unavailable`, which
/// lets the download through instead of blocking it.
@MainActor
@Suite struct GoogleAdsManagerShownFlagTests {
    private func makeManager(isPremium: Bool = false) -> GoogleAdsManager {
        GoogleAdsManager(
            bannerAdUnitID: "test-banner",
            interstitialAdUnitID: "test-interstitial",
            pdfRewardedAdUnitID: "test-rewarded",
            isPremium: { isPremium },
            defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        )
    }

    @Test func reportsNoAdShownWhenNoneIsLoaded() async {
        let manager = makeManager()
        var reported: Bool?
        manager.showEvaluationInterstitial { reported = $0 }
        #expect(reported == false)
    }

    @Test func reportsNoAdShownForAPremiumUser() async {
        let manager = makeManager(isPremium: true)
        var reported: Bool?
        manager.showEvaluationInterstitial { reported = $0 }
        #expect(reported == false)
    }

    @Test(arguments: [false, true])
    func rewardedIsUnavailableWhenNoneIsLoaded(isPremium: Bool) async {
        let manager = makeManager(isPremium: isPremium)
        #expect(manager.isPdfRewardedReady == false)

        var outcome: RewardedOutcome?
        manager.showPdfRewarded { outcome = $0 }
        #expect(outcome == .unavailable)
    }

    @Test func premiumUserNeverRequestsARewardedAd() async {
        let manager = makeManager(isPremium: true)
        // Without the guard this would start a network load; with it, nothing is requested.
        manager.preloadPdfRewarded()
        #expect(manager.isPdfRewardedReady == false)
    }
}
