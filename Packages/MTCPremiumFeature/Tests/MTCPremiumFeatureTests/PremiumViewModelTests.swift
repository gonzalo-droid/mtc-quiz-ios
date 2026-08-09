import Testing
import MTCDomain
@testable import MTCPremiumFeature

@Suite @MainActor struct PremiumViewModelTests {
    @Test func initialStateMatchesAndroidsDefaults() {
        let viewModel = PremiumViewModel()
        #expect(viewModel.state.isPremium == false)
        #expect(viewModel.state.isLoading == false)
        #expect(viewModel.state.availablePlans.isEmpty)
        #expect(viewModel.state.selectedPlan == nil)
        #expect(viewModel.state.restoreMessage == nil)
    }

    @Test func selectPlanUpdatesSelectedPlan() {
        let viewModel = PremiumViewModel()
        let plan = MTCDomain.SubscriptionPlan(productId: "mtcquiz_premium_annual", billingPeriod: .annual, formattedPrice: "S/ 29.90")

        viewModel.selectPlan(plan)

        #expect(viewModel.state.selectedPlan == plan)
    }

    @Test func restorePurchasesSetsTheNotFoundMessage() {
        // No real purchase backend exists in this scope, so restoring always resolves to the
        // same "not found" outcome Android's own restore flow produces with no real purchase to find.
        let viewModel = PremiumViewModel()

        viewModel.restorePurchases()

        #expect(viewModel.state.restoreMessage == "No se encontró ninguna suscripción activa")
    }

    @Test func clearRestoreMessageResetsItToNil() {
        let viewModel = PremiumViewModel()
        viewModel.restorePurchases()

        viewModel.clearRestoreMessage()

        #expect(viewModel.state.restoreMessage == nil)
    }
}
