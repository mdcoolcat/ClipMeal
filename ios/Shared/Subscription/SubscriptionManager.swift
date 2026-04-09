import Foundation
import StoreKit

@MainActor
@Observable
final class SubscriptionManager {
    var isSubscribed: Bool = false
    private(set) var products: [Product] = []
    private(set) var isPurchasing: Bool = false
    var errorMessage: String?
    var pendingMessage: String?

    private var transactionListener: Task<Void, Error>? {
        willSet { transactionListener?.cancel() }
    }
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults? = nil) {
        self.userDefaults = userDefaults ?? UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
        self.isSubscribed = self.userDefaults.bool(forKey: SubscriptionConstants.subscriptionStatusKey)
    }

    // MARK: - Lifecycle

    func start() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await refreshSubscriptionStatus()
        }
    }

    // MARK: - Products

    func loadProducts() async {
        print("[SubscriptionManager] loadProducts called, requesting IDs: \(SubscriptionConstants.allProductIDs)")
        do {
            let storeProducts = try await Product.products(for: SubscriptionConstants.allProductIDs)
            print("[SubscriptionManager] loaded \(storeProducts.count) products: \(storeProducts.map { $0.id })")
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("[SubscriptionManager] loadProducts error: \(error)")
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product, using purchaseAction: PurchaseAction) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await purchaseAction(product)
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                await refreshSubscriptionStatus()
            case .userCancelled:
                break
            case .pending:
                pendingMessage = "Your purchase is pending approval. You'll be notified when it's complete."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Subscription Status

    func refreshSubscriptionStatus() async {
        var hasActiveSubscription = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? Self.checkVerified(result),
               SubscriptionConstants.allProductIDs.contains(transaction.productID) {
                hasActiveSubscription = true
                break
            }
        }
        isSubscribed = hasActiveSubscription
        cacheSubscriptionStatus(hasActiveSubscription)
    }

    // MARK: - Convenience

    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionConstants.monthlyProductID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionConstants.yearlyProductID }
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? SubscriptionManager.checkVerified(result) {
                    await transaction.finish()
                    await self?.refreshSubscriptionStatus()
                }
            }
        }
    }

    private nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private func cacheSubscriptionStatus(_ isSubscribed: Bool) {
        userDefaults.set(isSubscribed, forKey: SubscriptionConstants.subscriptionStatusKey)
    }
}
