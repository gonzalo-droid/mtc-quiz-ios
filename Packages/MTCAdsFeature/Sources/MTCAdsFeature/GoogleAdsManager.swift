import Foundation
import GoogleMobileAds

/// Real AdMob-backed implementation of `AdsManaging`. Ported from Android's `AdsManagerImpl`:
/// same frequency-cap rule (show every 3rd time, `count > 0 && count % 3 == 0`), same
/// preload-eagerly / show-if-ready-else-skip / reload-after-dismiss cycle, same premium gate.
@MainActor
public final class GoogleAdsManager: AdsManaging {
    public let bannerAdUnitID: String
    public let isPremium: () -> Bool

    private let interstitialAdUnitID: String
    private let defaults: UserDefaults

    private enum Keys {
        static let pdfDownloadCount = "ads_pdf_download_count"
        static let evaluationStartCount = "ads_evaluation_start_count"
    }

    private var pdfInterstitial: InterstitialAd?
    private var isLoadingPdfInterstitial = false
    private var pdfDelegate: InterstitialDelegate?

    private var evaluationInterstitial: InterstitialAd?
    private var isLoadingEvaluationInterstitial = false
    private var evaluationDelegate: InterstitialDelegate?

    public init(
        bannerAdUnitID: String,
        interstitialAdUnitID: String,
        isPremium: @escaping () -> Bool,
        defaults: UserDefaults = .standard
    ) {
        self.bannerAdUnitID = bannerAdUnitID
        self.interstitialAdUnitID = interstitialAdUnitID
        self.isPremium = isPremium
        self.defaults = defaults
    }

    public func preloadPdfInterstitial() {
        guard !isPremium(), pdfInterstitial == nil, !isLoadingPdfInterstitial else { return }
        isLoadingPdfInterstitial = true
        InterstitialAd.load(with: interstitialAdUnitID, request: Request()) { [weak self] ad, _ in
            self?.isLoadingPdfInterstitial = false
            self?.pdfInterstitial = ad
        }
    }

    public func shouldShowPdfInterstitial() -> Bool {
        guard !isPremium() else { return false }
        let count = defaults.integer(forKey: Keys.pdfDownloadCount)
        return count > 0 && count % 3 == 0
    }

    public func showPdfInterstitial(onDismiss: @escaping () -> Void) {
        guard !isPremium(), let ad = pdfInterstitial, let presenter = RootViewController.current() else {
            onDismiss()
            return
        }
        let delegate = InterstitialDelegate { [weak self] in
            self?.pdfInterstitial = nil
            self?.pdfDelegate = nil
            self?.preloadPdfInterstitial()
            onDismiss()
        }
        pdfDelegate = delegate
        ad.fullScreenContentDelegate = delegate
        ad.present(from: presenter)
    }

    public func recordPdfDownload() {
        defaults.set(defaults.integer(forKey: Keys.pdfDownloadCount) + 1, forKey: Keys.pdfDownloadCount)
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

    public func showEvaluationInterstitial(onDismiss: @escaping () -> Void) {
        guard !isPremium(), let ad = evaluationInterstitial, let presenter = RootViewController.current() else {
            onDismiss()
            return
        }
        let delegate = InterstitialDelegate { [weak self] in
            self?.evaluationInterstitial = nil
            self?.evaluationDelegate = nil
            self?.preloadEvaluationInterstitial()
            onDismiss()
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
/// "the ad is gone, let the caller proceed" (matches Android's `onDismiss`-on-either-path).
private final class InterstitialDelegate: NSObject, FullScreenContentDelegate {
    private let onFinished: () -> Void

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onFinished()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        onFinished()
    }
}
