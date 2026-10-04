import Foundation

/// The one ordering both interstitial entry points follow, kept in one place so neither call site
/// can drift from it: count the action first, then ask the frequency rule, then show the ad if it
/// is due — the same `record…()` → `should…()` → `show…()` sequence as Android's view models.
/// `proceed` always runs exactly once, after the ad closes or right away when none is due, and
/// says whether an ad was actually on screen (which is what earns the premium upsell).
@MainActor
public extension AdsManaging {
    /// Gate for the PDF screen's "Descargar" action. Opening the PDF does not count — only the
    /// download does, as on Android's `PdfScreenViewModel.onDownloadClicked()`.
    func gatePdfDownload(then proceed: @escaping (_ adWasShown: Bool) -> Void) {
        recordPdfDownload()
        guard shouldShowPdfInterstitial() else {
            proceed(false)
            return
        }
        showPdfInterstitial(onDismiss: proceed)
    }

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
