import MTCDomain
import Observation

@MainActor
@Observable
public final class PremiumViewModel {
    public private(set) var state = PremiumState()

    public init() {}

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
