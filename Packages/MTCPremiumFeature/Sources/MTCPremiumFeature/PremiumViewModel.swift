import MTCDomain
import Observation

@MainActor
@Observable
public final class PremiumViewModel {
    public private(set) var state = PremiumState()
    private let premiumRepository: PremiumRepository

    public init(premiumRepository: PremiumRepository) {
        self.premiumRepository = premiumRepository
    }

    public func load() async {
        async let premium = premiumRepository.isPremium
        async let plans = premiumRepository.loadAvailablePlans()
        state.isPremium = await premium
        state.availablePlans = await plans
    }

    public func selectPlan(_ plan: MTCDomain.SubscriptionPlan) {
        state.selectedPlan = plan
    }

    public func subscribe() async {
        guard let productId = state.selectedPlan?.productId else { return }
        state.isLoading = true
        let success = await premiumRepository.subscribe(productId: productId)
        state.isLoading = false
        if success {
            state.isPremium = await premiumRepository.isPremium
        }
    }

    public func restorePurchases() async {
        state.isLoading = true
        _ = await premiumRepository.restorePurchases()
        state.isPremium = await premiumRepository.isPremium
        state.isLoading = false
        state.restoreMessage = state.isPremium
            ? "Suscripción restaurada correctamente"
            : "No se encontró ninguna suscripción activa"
    }

    public func clearRestoreMessage() {
        state.restoreMessage = nil
    }
}
