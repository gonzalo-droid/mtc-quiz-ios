import Foundation

/// The ordering the evaluation interstitial follows, kept in one place so the call site can't
/// drift from it: count the action first, then ask the frequency rule, then show the ad if it
/// is due — the same `record…()` → `should…()` → `show…()` sequence as Android's view models.
/// `proceed` always runs exactly once, after the ad closes or right away when none is due, and
/// says whether an ad was actually on screen (which is what earns the premium upsell).
@MainActor
public extension AdsManaging {
    /// Gate for "Iniciar evaluación" on Detail.
    func gateEvaluationStart(then proceed: @escaping (_ adWasShown: Bool) -> Void) {
        recordEvaluationStart()
        guard shouldShowEvaluationInterstitial() else {
            proceed(false)
            return
        }
        showEvaluationInterstitial(onDismiss: proceed)
    }
}
