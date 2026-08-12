import Foundation
import StoreKit

/// 買い切り課金（非消費型）で有料機能（外部アンカリング・バックアップエクスポート）を解放する。
@MainActor
@Observable
final class PurchaseManager {
    static let anchoringProductID = "com.gourcuff.yubikiri.anchoring.lifetime"

    private(set) var products: [Product] = []
    private(set) var isPremiumUnlocked = false
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }


    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.anchoringProductID])
        } catch {
            products = []
        }
    }

    func purchasePremium() async throws {
        guard let product = products.first(where: { $0.id == Self.anchoringProductID }) else {
            throw PurchaseError.productUnavailable
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            await refreshEntitlements()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? result.payloadValue else { continue }
            if transaction.productID == Self.anchoringProductID {
                unlocked = true
            }
        }
        isPremiumUnlocked = unlocked
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard let transaction = try? result.payloadValue else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }
}

enum PurchaseError: Error {
    case productUnavailable
}

private extension VerificationResult where SignedType == Transaction {
    var payloadValue: Transaction {
        get throws {
            switch self {
            case .verified(let transaction): return transaction
            case .unverified: throw PurchaseError.productUnavailable
            }
        }
    }
}
