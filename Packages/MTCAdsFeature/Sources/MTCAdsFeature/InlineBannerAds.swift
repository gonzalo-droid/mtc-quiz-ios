import SwiftUI
import GoogleMobileAds

/// The banners of one list screen, one per slot. A lazy stack drops a row's platform view as it
/// scrolls off screen; keeping each `BannerView` here means scrolling back shows the same ad
/// instead of requesting a new one every time. Each slot's ad is requested once, when the slot is
/// first built. Mirrors Android's `InlineBannerAds`.
///
/// Hold one per screen visit through `InlineBannerAdsHost`, which drops them all when the screen
/// goes away.
@MainActor
public final class InlineBannerAds {
    private let adUnitID: String
    /// Anchored-adaptive size: a fixed height known before loading, so the list does not jump
    /// when the ad arrives.
    let adSize: AdSize
    private var bannerViews: [Int: BannerView] = [:]

    /// - Parameter horizontalInset: the list's total side padding. The banner is sized to the
    ///   width it really gets, or its right edge would be clipped.
    public init(adUnitID: String, horizontalInset: CGFloat = 0) {
        self.adUnitID = adUnitID
        self.adSize = currentOrientationAnchoredAdaptiveBanner(
            width: UIScreen.main.bounds.width - horizontalInset
        )
    }

    var height: CGFloat { adSize.size.height }

    func bannerView(for slot: Int) -> BannerView {
        if let existing = bannerViews[slot] { return existing }
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = RootViewController.current()
        bannerView.load(Request())
        bannerViews[slot] = bannerView
        return bannerView
    }
}

/// Keeps one `InlineBannerAds` alive for as long as `content` is on screen and hands it down.
public struct InlineBannerAdsHost<Content: View>: View {
    @State private var banners: InlineBannerAds
    private let content: (InlineBannerAds) -> Content

    public init(
        adUnitID: String,
        horizontalInset: CGFloat = 0,
        @ViewBuilder content: @escaping (InlineBannerAds) -> Content
    ) {
        _banners = State(initialValue: InlineBannerAds(adUnitID: adUnitID, horizontalInset: horizontalInset))
        self.content = content
    }

    public var body: some View {
        content(banners)
    }
}

/// One banner between the rows of a list. Reserves the banner's height up front, so an empty
/// slot (no inventory, no network) leaves a gap rather than a jump. Callers decide whether a
/// premium user gets a slot at all.
public struct InlineBannerAdSlot: View {
    private let banners: InlineBannerAds
    private let slot: Int

    public init(banners: InlineBannerAds, slot: Int) {
        self.banners = banners
        self.slot = slot
    }

    public var body: some View {
        InlineBannerRepresentable(bannerView: banners.bannerView(for: slot))
            .frame(width: banners.adSize.size.width, height: banners.height)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Publicidad")
    }
}

/// Wraps the cached banner in a fresh container each time the row is rebuilt. A view has a single
/// superview, so the banner is moved out of the container of the row it last belonged to.
private struct InlineBannerRepresentable: UIViewRepresentable {
    let bannerView: BannerView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        attach(to: container)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        if bannerView.superview !== container { attach(to: container) }
    }

    private func attach(to container: UIView) {
        bannerView.removeFromSuperview()
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
    }
}
