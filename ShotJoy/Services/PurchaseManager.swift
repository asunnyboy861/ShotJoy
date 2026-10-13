import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published var isPro: Bool = false
    @Published var hasLifetime: Bool = false
    @Published var hasCloudAI: Bool = false
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var loadError: String?
    @Published var lastJWSRepresentation: String?

    static let monthlyID = "com.zzoutuo.shotjoy.pro.monthly"
    static let yearlyID = "com.zzoutuo.shotjoy.pro.yearly"
    static let lifetimeID = "com.zzoutuo.shotjoy.pro.lifetime"
    static let allIDs = [monthlyID, yearlyID, lifetimeID]

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts(); await checkPurchased() }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: Self.allIDs)
                .sorted { $0.price < $1.price }
            loadError = nil
        } catch {
            loadError = "Unable to load purchase options."
        }
        isLoading = false
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    captureJWS(verification.jwsRepresentation)
                    await checkPurchased()
                    await transaction.finish()
                    return true
                }
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            loadError = "Purchase failed: \(error.localizedDescription)"
        }
        return false
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkPurchased()
        } catch {
            loadError = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func checkPurchased() async {
        var pro = false
        var lifetime = false
        var cloud = false
        var newestJWS: String?
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                newestJWS = result.jwsRepresentation
                switch transaction.productID {
                case Self.monthlyID, Self.yearlyID:
                    if transaction.revocationDate == nil && !Self.isExpired(transaction) {
                        pro = true
                        cloud = true
                    }
                case Self.lifetimeID:
                    if transaction.revocationDate == nil {
                        lifetime = true
                        pro = true
                    }
                default:
                    break
                }
            }
        }
        isPro = pro
        hasLifetime = lifetime
        hasCloudAI = cloud
        if let j = newestJWS { lastJWSRepresentation = j }
    }

    nonisolated static func isExpired(_ transaction: Transaction) -> Bool {
        if let exp = transaction.expirationDate {
            return exp < Date()
        }
        return false
    }

    private func captureJWS(_ jws: String) {
        lastJWSRepresentation = jws
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    Task { @MainActor [weak self] in
                        await self?.checkPurchased()
                    }
                }
            }
        }
    }

    var yearlyProduct: Product? { products.first { $0.id == Self.yearlyID } }
    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeID } }
}
