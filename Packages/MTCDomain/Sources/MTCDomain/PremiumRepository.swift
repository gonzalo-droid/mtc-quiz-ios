public protocol PremiumRepository: Sendable {
    /// Reads current entitlement state. Backed by StoreKit2 transaction verification, cached
    /// locally for instant reads on cold start — call `refreshPurchaseState()` to force a
    /// re-check against the store.
    var isPremium: Bool { get async }

    /// Queries the store for the subscription products this app offers and their live prices.
    /// Returns an empty list if the store can't be reached or no products are configured.
    func loadAvailablePlans() async -> [SubscriptionPlan]

    /// Starts the purchase flow for `productId` and awaits its result. Returns `true` only if
    /// the purchase completed and was verified; `false` on cancellation, failure, or an
    /// unverified transaction.
    func subscribe(productId: String) async -> Bool

    /// Re-syncs with the store (StoreKit's `AppStore.sync()`) and refreshes local entitlement
    /// state from it. Returns the resulting `isPremium` value.
    func restorePurchases() async -> Bool

    /// Re-checks current entitlements against the store without a full sync, updating the
    /// cached `isPremium` value.
    func refreshPurchaseState() async
}
