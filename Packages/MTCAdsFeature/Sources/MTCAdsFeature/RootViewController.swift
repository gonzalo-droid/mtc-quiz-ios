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
}
