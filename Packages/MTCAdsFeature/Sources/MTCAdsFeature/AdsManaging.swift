import Foundation

/// Mirrors Android's `AdsManager` interface (core/data/ads/AdsManager.kt): a rewarded ad for the
/// PDF download, an interstitial for the evaluation start with its preload/frequency-cap/show/record
/// cycle, plus a banner ad unit id for `BannerAdView`. No `Activity`/`Context` parameters — iOS presents from
/// whatever the current root view controller is, resolved internally (see `RootViewController.swift`).
@MainActor
public protocol AdsManaging: AnyObject {
    var bannerAdUnitID: String { get }
    var isPremium: () -> Bool { get }

    /// Precarga el anuncio con recompensa de la descarga del PDF. Idempotente.
    func preloadPdfRewarded()

    /// true si hay un anuncio con recompensa listo. Si es false (premium, sin consentimiento, sin
    /// red o sin inventario) la descarga sigue sin anuncio: nunca se bloquea un PDF por falta de
    /// anuncio.
    var isPdfRewardedReady: Bool { get }

    /// Muestra el anuncio con recompensa y avisa el resultado: `.earned` si lo vio completo,
    /// `.skipped` si lo cerró antes y `.unavailable` si no había anuncio o falló al mostrarse.
    func showPdfRewarded(onResult: @escaping (RewardedOutcome) -> Void)

    /// Precarga el intersticial de evaluación para tenerlo listo. Idempotente.
    func preloadEvaluationInterstitial()

    /// true si, según la regla de frecuencia (cada 3 evaluaciones), corresponde mostrar el
    /// intersticial al iniciar esta evaluación.
    func shouldShowEvaluationInterstitial() -> Bool

    /// Muestra el intersticial de evaluación precargado. Si no está listo o falla, invoca
    /// `onDismiss` inmediatamente. Nunca bloquea. `adWasShown` dice si el anuncio llegó a verse.
    func showEvaluationInterstitial(onDismiss: @escaping (_ adWasShown: Bool) -> Void)

    /// Incrementa el contador persistente. Se llama ANTES de decidir si mostrar el intersticial.
    func recordEvaluationStart()
}

/// Cómo terminó un anuncio con recompensa. Android: `RewardedOutcome`.
public enum RewardedOutcome: Equatable, Sendable {
    /// El usuario vio el anuncio completo y ganó la recompensa.
    case earned
    /// El usuario cerró el anuncio antes de ganar la recompensa.
    case skipped
    /// No había anuncio listo, o falló al mostrarse: el usuario no tiene la culpa.
    case unavailable
}
