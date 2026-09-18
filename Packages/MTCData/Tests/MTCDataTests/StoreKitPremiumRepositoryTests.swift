import Testing
import Foundation
import StoreKitTest
@testable import MTCData
import MTCDomain

/// Runs against the repo-root `Configuration.storekit` file via `SKTestSession`, which lets
/// StoreKit2 purchase flows run headlessly (no real App Store, no human confirmation) —
/// requires `xcodebuild test` on an iOS Simulator destination; plain `swift test` targets
/// macOS and can't run this.
///
/// `.serialized`: each test spins up its own `SKTestSession` against the same simulator's
/// StoreKit test daemon. Swift Testing parallelizes `@Test`s in a suite by default, and
/// concurrent sessions fight over that daemon ("Error saving configuration file",
/// intermittent crashes) — serializing avoids the contention.
@Suite(.serialized) final class StoreKitPremiumRepositoryTests {
    private let session: SKTestSession
    private let repository: StoreKitPremiumRepository
    private let defaults: UserDefaults

    init() throws {
        let configURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // StoreKitPremiumRepositoryTests.swift
            .deletingLastPathComponent() // MTCDataTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // MTCData
            .deletingLastPathComponent() // Packages
            .appendingPathComponent("Configuration.storekit")
        session = try SKTestSession(contentsOf: configURL)
        session.disableDialogs = true
        session.clearTransactions()

        let suiteName = "StoreKitPremiumRepositoryTests"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        repository = StoreKitPremiumRepository(userDefaults: defaults)
    }

    deinit {
        session.clearTransactions()
    }

    @Test func loadAvailablePlansReturnsBothSubscriptionsFromTheConfiguration() async {
        let plans = await repository.loadAvailablePlans()

        #expect(plans.count == 2)
        #expect(plans.contains { $0.productId == StoreKitPremiumRepository.productIDMonthly && $0.billingPeriod == .monthly })
        #expect(plans.contains { $0.productId == StoreKitPremiumRepository.productIDAnnual && $0.billingPeriod == .annual })
    }

    @Test func isPremiumIsFalseWithNoPriorPurchase() async {
        let isPremium = await repository.isPremium
        #expect(isPremium == false)
    }

    @Test func subscribeToMonthlyPlanMarksIsPremiumTrue() async {
        _ = await repository.loadAvailablePlans()

        let success = await repository.subscribe(productId: StoreKitPremiumRepository.productIDMonthly)

        #expect(success == true)
        let isPremium = await repository.isPremium
        #expect(isPremium == true)
    }

    @Test func subscribeToAnUnknownProductIdFails() async {
        let success = await repository.subscribe(productId: "not_a_real_product")
        #expect(success == false)
    }

    @Test func restorePurchasesWithNothingToRestoreStaysFalse() async {
        let restored = await repository.restorePurchases()
        #expect(restored == false)
    }

    @Test func restorePurchasesAfterASubscriptionFindsIt() async {
        _ = await repository.loadAvailablePlans()
        _ = await repository.subscribe(productId: StoreKitPremiumRepository.productIDAnnual)

        let restored = await repository.restorePurchases()

        #expect(restored == true)
    }
}
