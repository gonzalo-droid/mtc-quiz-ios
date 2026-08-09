import MTCDomain

public struct PremiumState: Equatable, Sendable {
    public var isPremium: Bool
    public var isLoading: Bool
    public var availablePlans: [MTCDomain.SubscriptionPlan]
    public var selectedPlan: MTCDomain.SubscriptionPlan?
    public var restoreMessage: String?

    public init(
        isPremium: Bool = false,
        isLoading: Bool = false,
        availablePlans: [MTCDomain.SubscriptionPlan] = [],
        selectedPlan: MTCDomain.SubscriptionPlan? = nil,
        restoreMessage: String? = nil
    ) {
        self.isPremium = isPremium
        self.isLoading = isLoading
        self.availablePlans = availablePlans
        self.selectedPlan = selectedPlan
        self.restoreMessage = restoreMessage
    }
}
