public enum BillingPeriod: Sendable, Equatable {
    case monthly
    case annual
}

public struct SubscriptionPlan: Identifiable, Equatable, Sendable {
    public var id: String { productId }
    public let productId: String
    public let billingPeriod: BillingPeriod
    public let formattedPrice: String

    public init(productId: String, billingPeriod: BillingPeriod, formattedPrice: String) {
        self.productId = productId
        self.billingPeriod = billingPeriod
        self.formattedPrice = formattedPrice
    }
}
