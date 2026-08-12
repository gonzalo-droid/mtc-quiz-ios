import SwiftUI
import GoogleMobileAds

/// Loads and renders an adaptive banner for `adUnitID`, centered. Renders nothing when
/// `isPremium` is true. Mirrors Android's `BannerAdSlot.kt`.
public struct BannerAdView: View {
    private let adUnitID: String
    private let isPremium: Bool

    public init(adUnitID: String, isPremium: Bool) {
        self.adUnitID = adUnitID
        self.isPremium = isPremium
    }

    public var body: some View {
        if !isPremium {
            BannerAdRepresentable(adUnitID: adUnitID)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct BannerAdRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let width = UIScreen.main.bounds.width
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = RootViewController.current()
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
