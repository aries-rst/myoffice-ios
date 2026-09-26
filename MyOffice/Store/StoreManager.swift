import Foundation
import StoreKit

/// The three real App Store Connect In-App Purchase product identifiers for
/// MyOffice. Must exactly match what was entered in App Store Connect.
enum ProductID: String, CaseIterable {
    case pro = "com.aries_rst.myoffice.app.pro35"
    case max = "com.aries_rst.myoffice.app.maxunlimited"

    var tier: Tier {
        switch self {
        case .pro: return .pro
        case .max: return .max
        }
    }
}

enum StoreError: LocalizedError {
    case failedVerification
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Purchase could not be verified by the App Store."
        case .productNotFound:
            return "This product isn't available right now. Please try again later."
        }
    }
}

/// Owns all real StoreKit 2 interaction: loading products, purchasing,
/// restoring, and keeping AppState.tier in sync with what the App Store
/// actually says the user owns. AppState itself no longer decides the tier —
/// it just reflects whatever this class determines from real entitlements.
@MainActor
final class StoreManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published var isPurchasing = false
    @Published var lastError: String?
    @Published var statusMessage: String?

    private var updatesTask: Task<Void, Never>?
    private weak var appState: AppState?

    /// Call once, right after both AppState and StoreManager exist (see
    /// MyOfficeApp). Starts listening for transaction updates (purchases made
    /// via Ask to Buy, or restored on another device) and does an initial
    /// products load + entitlement check so the tier reflects reality even if
    /// the app was reinstalled.
    func start(appState: AppState) {
        self.appState = appState
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: ProductID.allCases.map(\.rawValue))
        } catch {
            lastError = "Couldn't load prices from the App Store: \(error.localizedDescription)"
        }
    }

    func product(for id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    /// Buys the given product. On success, updates AppState.tier immediately
    /// (the transaction listener would also catch it, but this avoids any lag
    /// in the UI). Safe to call repeatedly; guarded by isPurchasing.
    func purchase(_ id: ProductID) async {
        guard !isPurchasing else { return }
        lastError = nil
        statusMessage = nil
        guard let product = product(for: id) else {
            // Products may not have loaded yet (e.g. cold launch with a slow
            // network) — try once more before giving up.
            await loadProducts()
            guard let product = product(for: id) else {
                lastError = StoreError.productNotFound.errorDescription
                return
            }
            await purchase(product: product, id: id)
            return
        }
        await purchase(product: product, id: id)
    }

    private func purchase(product: Product, id: ProductID) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                appState?.applyEntitlement(for: transaction)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                // e.g. Ask to Buy — will resolve later via Transaction.updates.
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Re-syncs with the App Store and re-checks entitlements. Used both by
    /// the explicit "Restore purchases" button and automatically at launch.
    func restore() async {
        guard !isPurchasing else { return }
        lastError = nil
        statusMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = "Purchases restored."
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Walks every currently-owned (non-revoked) transaction and derives the
    /// highest tier the user actually owns, then tells AppState. This is the
    /// single source of truth for `tier` — it's what makes the purchase
    /// survive reinstalls, device changes, and Ask to Buy approvals.
    func refreshEntitlements() async {
        var highestTier: Tier = .free
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if let id = ProductID(rawValue: transaction.productID) {
                if id.tier == .max {
                    highestTier = .max
                } else if id.tier == .pro && highestTier != .max {
                    highestTier = .pro
                }
            }
        }
        appState?.setTierFromEntitlements(highestTier)
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(transactionResult) else { return }
        appState?.applyEntitlement(for: transaction)
        await transaction.finish()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
