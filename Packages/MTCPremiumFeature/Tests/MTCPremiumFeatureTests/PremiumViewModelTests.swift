import Testing
import MTCDomain
@testable import MTCPremiumFeature

@Suite @MainActor struct PremiumViewModelTests {
    @Test func initialStateMatchesAndroidsDefaults() {
        let viewModel = PremiumViewModel(premiumRepository: FakePremiumRepository())
        #expect(viewModel.state.isPremium == false)
        #expect(viewModel.state.isLoading == false)
        #expect(viewModel.state.availablePlans.isEmpty)
        #expect(viewModel.state.selectedPlan == nil)
        #expect(viewModel.state.restoreMessage == nil)
    }

    @Test func selectPlanUpdatesSelectedPlan() {
        let viewModel = PremiumViewModel(premiumRepository: FakePremiumRepository())
        let plan = MTCDomain.SubscriptionPlan(productId: "mtcquiz_premium_annual", billingPeriod: .annual, formattedPrice: "S/ 29.90")

        viewModel.selectPlan(plan)

        #expect(viewModel.state.selectedPlan == plan)
    }

    @Test func loadPopulatesAvailablePlansAndIsPremiumFromTheRepository() async {
        let repository = FakePremiumRepository(isPremium: true)
        let plan = MTCDomain.SubscriptionPlan(productId: "mtcquiz_premium_monthly", billingPeriod: .monthly, formattedPrice: "S/ 9.90")
        await repository.setPlans([plan])
        let viewModel = PremiumViewModel(premiumRepository: repository)

        await viewModel.load()

        #expect(viewModel.state.isPremium == true)
        #expect(viewModel.state.availablePlans == [plan])
    }

    @Test func subscribeWithNoSelectedPlanDoesNothing() async {
        let repository = FakePremiumRepository()
        let viewModel = PremiumViewModel(premiumRepository: repository)

        await viewModel.subscribe()

        let callCount = await repository.subscribeCallCount
        #expect(callCount == 0)
    }

    @Test func subscribeSuccessUpdatesIsPremium() async {
        let repository = FakePremiumRepository()
        await repository.setSubscribeResult(true)
        let viewModel = PremiumViewModel(premiumRepository: repository)
        viewModel.selectPlan(MTCDomain.SubscriptionPlan(productId: "mtcquiz_premium_monthly", billingPeriod: .monthly, formattedPrice: "S/ 9.90"))

        await viewModel.subscribe()

        #expect(viewModel.state.isPremium == true)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func subscribeFailureLeavesIsPremiumFalse() async {
        let repository = FakePremiumRepository()
        let viewModel = PremiumViewModel(premiumRepository: repository)
        viewModel.selectPlan(MTCDomain.SubscriptionPlan(productId: "mtcquiz_premium_monthly", billingPeriod: .monthly, formattedPrice: "S/ 9.90"))

        await viewModel.subscribe()

        #expect(viewModel.state.isPremium == false)
    }

    @Test func restorePurchasesWithNoActiveSubscriptionSetsTheNotFoundMessage() async {
        // Mirrors Android's own restore flow, which produces the same "not found" outcome
        // when there's nothing to restore.
        let viewModel = PremiumViewModel(premiumRepository: FakePremiumRepository())

        await viewModel.restorePurchases()

        #expect(viewModel.state.restoreMessage == "No se encontró ninguna suscripción activa")
    }

    @Test func restorePurchasesWithAnActiveSubscriptionSetsTheSuccessMessage() async {
        let repository = FakePremiumRepository()
        await repository.setRestoreResult(true)
        let viewModel = PremiumViewModel(premiumRepository: repository)

        await viewModel.restorePurchases()

        #expect(viewModel.state.isPremium == true)
        #expect(viewModel.state.restoreMessage == "Suscripción restaurada correctamente")
    }

    @Test func clearRestoreMessageResetsItToNil() async {
        let viewModel = PremiumViewModel(premiumRepository: FakePremiumRepository())
        await viewModel.restorePurchases()

        viewModel.clearRestoreMessage()

        #expect(viewModel.state.restoreMessage == nil)
    }
}
