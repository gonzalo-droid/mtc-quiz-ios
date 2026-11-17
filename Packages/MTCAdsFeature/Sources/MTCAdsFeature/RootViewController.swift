import UIKit

@MainActor
enum RootViewController {
    /// The topmost presented view controller of the key window's root — where a full-screen
    /// interstitial (or a banner's hosting `rootViewController`) should be presented from.
    static func current() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            ?? scenes.first as? UIWindowScene
        guard let root = windowScene?.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    /// `current()`, once any presentation or dismissal in flight has finished. A full-screen ad
    /// started from an alert's button would otherwise be presented on the alert while it is still
    /// going away; when the ad later closes, the next sheet SwiftUI presents never appears.
    static func whenSettled(_ action: @escaping (UIViewController?) -> Void) {
        guard let top = current(), let coordinator = top.transitionCoordinator else {
            action(current())
            return
        }
        coordinator.animate(alongsideTransition: nil) { _ in
            action(current())
        }
    }
}
