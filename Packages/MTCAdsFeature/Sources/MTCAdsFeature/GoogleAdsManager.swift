import Foundation
import GoogleMobileAds

/// Real AdMob-backed implementation of `AdsManaging`. Ported from Android's `AdsManagerImpl`:
/// same evaluation frequency-cap rule (show every 3rd time, `count > 0 && count % 3 == 0`), same
/// preload-eagerly / show-if-ready-else-skip / reload-after-dismiss cycle, same premium gate. The
/// PDF download has no counter: every download goes through the rewarded ad when one is ready.
@MainActor
public final class GoogleAdsManager: AdsManaging {
    public let bannerAdUnitID: String
    public let isPremium: () -> Bool

    private let interstitialAdUnitID: String
    private let pdfRewardedAdUnitID: String
    private let defaults: UserDefaults

    /// `ads_pdf_download_count`, the old PDF interstitial's counter, is left behind in existing
    /// installs and no longer read.
    private enum Keys {
        static let evaluationStartCount = "ads_evaluation_start_count"
    }

    private var pdfRewarded: RewardedAd?
    private var isLoadingPdfRewarded = false
    private var pdfRewardedDelegate: RewardedDelegate?

    private var evaluationInterstitial: InterstitialAd?
    private var isLoadingEvaluationInterstitial = false
    private var evaluationDelegate: InterstitialDelegate?

    public init(
        bannerAdUnitID: String,
        interstitialAdUnitID: String,
        pdfRewardedAdUnitID: String,
        isPremium: @escaping () -> Bool,
        defaults: UserDefaults = .standard
    ) {
        self.bannerAdUnitID = bannerAdUnitID
        self.interstitialAdUnitID = interstitialAdUnitID
        self.pdfRewardedAdUnitID = pdfRewardedAdUnitID
        self.isPremium = isPremium
        self.defaults = defaults
    }

    public func preloadPdfRewarded() {
        guard !isPremium(), pdfRewarded == nil, !isLoadingPdfRewarded else { return }
        isLoadingPdfRewarded = true
        RewardedAd.load(with: pdfRewardedAdUnitID, request: Request()) { [weak self] ad, _ in
            self?.isLoadingPdfRewarded = false
            self?.pdfRewarded = ad
        }
    }

    public var isPdfRewardedReady: Bool { !isPremium() && pdfRewarded != nil }

    /// Waits for in-flight transitions first: it is shown from the button of the "Descarga gratis
    /// con un anuncio" alert, which is still dismissing at that moment.
    public func showPdfRewarded(onResult: @escaping (RewardedOutcome) -> Void) {
        guard !isPremium(), let ad = pdfRewarded else {
            onResult(.unavailable)
            return
        }
        RootViewController.whenSettled { [weak self] presenter in
            guard let self, let presenter else {
                onResult(.unavailable)
                return
            }
            let delegate = RewardedDelegate { [weak self] outcome in
                self?.pdfRewarded = nil
                self?.pdfRewardedDelegate = nil
                self?.preloadPdfRewarded()
                // The share sheet comes next: let the ad finish going away first.
                RootViewController.whenSettled { _ in onResult(outcome) }
            }
            self.pdfRewardedDelegate = delegate
            ad.fullScreenContentDelegate = delegate
            ad.present(from: presenter) { [weak delegate] in delegate?.rewardEarned = true }
        }
    }

    public func preloadEvaluationInterstitial() {
        guard !isPremium(), evaluationInterstitial == nil, !isLoadingEvaluationInterstitial else { return }
        isLoadingEvaluationInterstitial = true
        InterstitialAd.load(with: interstitialAdUnitID, request: Request()) { [weak self] ad, _ in
            self?.isLoadingEvaluationInterstitial = false
            self?.evaluationInterstitial = ad
        }
    }

    public func shouldShowEvaluationInterstitial() -> Bool {
        guard !isPremium() else { return false }
        let count = defaults.integer(forKey: Keys.evaluationStartCount)
        return count > 0 && count % 3 == 0
    }

    public func showEvaluationInterstitial(onDismiss: @escaping (_ adWasShown: Bool) -> Void) {
        guard !isPremium(), let ad = evaluationInterstitial, let presenter = RootViewController.current() else {
            onDismiss(false)
            return
        }
        let delegate = InterstitialDelegate { [weak self] adWasShown in
            self?.evaluationInterstitial = nil
            self?.evaluationDelegate = nil
            self?.preloadEvaluationInterstitial()
            onDismiss(adWasShown)
        }
        evaluationDelegate = delegate
        ad.fullScreenContentDelegate = delegate
        ad.present(from: presenter)
    }

    public func recordEvaluationStart() {
        defaults.set(defaults.integer(forKey: Keys.evaluationStartCount) + 1, forKey: Keys.evaluationStartCount)
    }
}

/// `FullScreenContentDelegate` can't be a closure, so this adapts one to the callback shape
/// `GoogleAdsManager` needs — fired on dismiss AND on failure-to-present, since both cases mean
/// "the ad is gone, let the caller proceed" (matches Android's `onDismiss`-on-either-path). The
/// flag separates the two: only a dismissal means the user actually sat through an ad.
private final class InterstitialDelegate: NSObject, FullScreenContentDelegate {
    private let onFinished: (_ adWasShown: Bool) -> Void

    init(onFinished: @escaping (_ adWasShown: Bool) -> Void) {
        self.onFinished = onFinished
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onFinished(true)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        onFinished(false)
    }
}

/// The rewarded counterpart of `InterstitialDelegate`. The reward arrives through `present`'s own
/// handler, before the ad is dismissed; the dismissal then reports whether it came. A failure to
/// present is `.unavailable`, so the caller lets the download through.
private final class RewardedDelegate: NSObject, FullScreenContentDelegate {
    var rewardEarned = false
    private let onFinished: (RewardedOutcome) -> Void

    init(onFinished: @escaping (RewardedOutcome) -> Void) {
        self.onFinished = onFinished
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onFinished(rewardEarned ? .earned : .skipped)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        onFinished(.unavailable)
    }
}
