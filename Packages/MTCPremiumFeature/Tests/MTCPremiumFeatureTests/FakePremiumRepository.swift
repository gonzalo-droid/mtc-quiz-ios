import MTCDomain

actor FakePremiumRepository: PremiumRepository {
    private(set) var subscribeCallCount = 0
    private(set) var restoreCallCount = 0
    private var plansToReturn: [MTCDomain.SubscriptionPlan] = []
    private var subscribeResult = false
    private var restoreResult = false
    private(set) var isPremium: Bool

    init(isPremium: Bool = false) {
        self.isPremium = isPremium
    }

    func setPlans(_ plans: [MTCDomain.SubscriptionPlan]) { plansToReturn = plans }
    func setSubscribeResult(_ value: Bool) { subscribeResult = value }
    func setRestoreResult(_ value: Bool) { restoreResult = value }

    func loadAvailablePlans() async -> [MTCDomain.SubscriptionPlan] { plansToReturn }

    func subscribe(productId: String) async -> Bool {
        subscribeCallCount += 1
        if subscribeResult { isPremium = true }
        return subscribeResult
    }

    func restorePurchases() async -> Bool {
        restoreCallCount += 1
        if restoreResult { isPremium = true }
        return restoreResult
    }

    func refreshPurchaseState() async {}
}
