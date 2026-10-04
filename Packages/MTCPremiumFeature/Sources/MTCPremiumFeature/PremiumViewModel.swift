import MTCDomain
import Observation

@MainActor
@Observable
public final class PremiumViewModel {
    public private(set) var state = PremiumState()

    /// - Parameter isPremium: the same entitlement source the rest of the app reads (the app
    ///   shell's `isPremiumUser()`), so the paywall says "¡Eres Premium!" exactly when ads,
    ///   the Home crown and the Settings row also treat the user as premium.
    public init(isPremium: () -> Bool = { false }) {
        state.isPremium = isPremium()
    }

    public func selectPlan(_ plan: MTCDomain.SubscriptionPlan) {
        state.selectedPlan = plan
    }

    /// No real purchase backend in this scope — intentional no-op. The button this is wired to
    /// stays disabled in practice, since `state.selectedPlan` can never become non-nil through
    /// real user interaction while `availablePlans` is always empty. Kept as a real method for
    /// API parity with Android and as the natural hook for a future real-StoreKit pass.
    public func subscribe() {}

    public func restorePurchases() {
        state.restoreMessage = "No se encontró ninguna suscripción activa"
    }

    public func clearRestoreMessage() {
        state.restoreMessage = nil
    }
}
