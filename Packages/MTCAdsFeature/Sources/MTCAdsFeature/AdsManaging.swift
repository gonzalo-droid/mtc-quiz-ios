import Foundation

/// Mirrors Android's `AdsManager` interface (core/data/ads/AdsManager.kt): interstitials for the
/// PDF and evaluation entry points, each with its own preload/frequency-cap/show/record cycle, plus
/// a banner ad unit id for `BannerAdView`. No `Activity`/`Context` parameters — iOS presents from
/// whatever the current root view controller is, resolved internally (see `RootViewController.swift`).
@MainActor
public protocol AdsManaging: AnyObject {
    var bannerAdUnitID: String { get }
    var isPremium: () -> Bool { get }

    /// Precarga el intersticial de PDF para tenerlo listo. Idempotente.
    func preloadPdfInterstitial()

    /// true si, según la regla de frecuencia (cada 3 descargas/vistas), corresponde mostrar
    /// el intersticial esta vez.
    func shouldShowPdfInterstitial() -> Bool

    /// Muestra el intersticial de PDF precargado. Si no está listo o falla, invoca `onDismiss`
    /// inmediatamente. Nunca bloquea. `adWasShown` dice si el anuncio llegó a verse: sirve para
    /// no ofrecer "quita los anuncios" cuando no hubo ninguno.
    func showPdfInterstitial(onDismiss: @escaping (_ adWasShown: Bool) -> Void)

    /// Incrementa el contador persistente. Se llama ANTES de decidir si mostrar el intersticial.
    func recordPdfDownload()

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
