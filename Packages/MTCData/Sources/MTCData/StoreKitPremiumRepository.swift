import Foundation
import StoreKit
import MTCDomain

/// Real StoreKit2-backed `PremiumRepository`. Mirrors Android's `PremiumRepositoryImpl`:
/// query live product details, launch the purchase flow, cache the resulting entitlement
/// locally for instant reads, and keep it in sync via `Transaction.updates` (renewals,
/// revocations, purchases made on another device).
public actor StoreKitPremiumRepository: PremiumRepository {
    public static let productIDMonthly = "com.gonzadev.mtcquiz.premium.monthly"
    public static let productIDAnnual = "com.gonzadev.mtcquiz.premium.annual"
    private static let productIDs = [productIDMonthly, productIDAnnual]

    /// Cache key for the last-known entitlement state, `UserDefaults.standard`-backed so
    /// synchronous call sites (e.g. ad-gating, which can't `await` an actor mid-render) can
    /// read it directly instead of going through this actor.
    public static let cachedIsPremiumKey = "cached_is_premium"

    private let defaults: UserDefaults
    private var productsCache: [String: Product] = [:]
    private var isPremiumCached: Bool
    private var updatesTask: Task<Void, Never>?

    public init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        self.isPremiumCached = userDefaults.bool(forKey: Self.cachedIsPremiumKey)
        Task { await self.startListeningForTransactionUpdates() }
    }

    deinit {
        updatesTask?.cancel()
    }

    public var isPremium: Bool {
        isPremiumCached
    }

    public func loadAvailablePlans() async -> [SubscriptionPlan] {
        do {
            let products = try await Product.products(for: Self.productIDs)
            var plans: [SubscriptionPlan] = []
            for product in products {
                productsCache[product.id] = product
                guard let period = Self.billingPeriod(for: product.id) else { continue }
                plans.append(
                    SubscriptionPlan(productId: product.id, billingPeriod: period, formattedPrice: product.displayPrice)
                )
            }
            return plans
        } catch {
            return []
        }
    }

    public func subscribe(productId: String) async -> Bool {
        let product: Product?
        if let cached = productsCache[productId] {
            product = cached
        } else {
            product = try? await Product.products(for: [productId]).first
        }
        guard let product else { return false }
        productsCache[product.id] = product

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                updateIsPremium(true)
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    public func restorePurchases() async -> Bool {
        try? await AppStore.sync()
        await refreshPurchaseState()
        return isPremiumCached
    }

    public func refreshPurchaseState() async {
        var hasActiveSubscription = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.productIDs.contains(transaction.productID), transaction.revocationDate == nil {
                hasActiveSubscription = true
            }
        }
        updateIsPremium(hasActiveSubscription)
    }

    private func updateIsPremium(_ value: Bool) {
        isPremiumCached = value
        defaults.set(value, forKey: Self.cachedIsPremiumKey)
    }

    private func startListeningForTransactionUpdates() {
        updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshPurchaseState()
            }
        }
    }

    private static func billingPeriod(for productId: String) -> BillingPeriod? {
        switch productId {
        case productIDMonthly: .monthly
        case productIDAnnual: .annual
        default: nil
        }
    }
}
