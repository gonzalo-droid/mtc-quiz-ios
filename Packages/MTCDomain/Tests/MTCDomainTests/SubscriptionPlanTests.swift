import Testing
@testable import MTCDomain

@Suite struct SubscriptionPlanTests {
    @Test func idIsTheProductId() {
        let plan = MTCDomain.SubscriptionPlan(productId: "mtcquiz_premium_monthly", billingPeriod: .monthly, formattedPrice: "S/ 9.90")
        #expect(plan.id == "mtcquiz_premium_monthly")
    }

    @Test func plansWithDifferentProductIdsAreNotEqual() {
        let monthly = MTCDomain.SubscriptionPlan(productId: "mtcquiz_premium_monthly", billingPeriod: .monthly, formattedPrice: "S/ 9.90")
        let annual = MTCDomain.SubscriptionPlan(productId: "mtcquiz_premium_annual", billingPeriod: .annual, formattedPrice: "S/ 29.90")
        #expect(monthly != annual)
    }
}
