import Foundation
import StoreKit
import Combine

/// IAP 错误类型
enum IAPError: LocalizedError {
    case productNotFound
    case purchaseFailed(String)
    case verificationFailed
    case syncFailed(String)
    case userCancelled
    case pending
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .productNotFound: return "未找到订阅商品"
        case .purchaseFailed(let msg): return "购买失败: \(msg)"
        case .verificationFailed: return "交易验证失败"
        case .syncFailed(let msg): return "同步订阅状态失败: \(msg)"
        case .userCancelled: return "用户取消购买"
        case .pending: return "购买待处理，请稍后再试"
        case .unknown: return "未知错误"
        }
    }
}

/// StoreKit 2 订阅管理器
@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    /// UserDefaults key，用于跨隔离域快速读取订阅状态
    private static let premiumKey = "com.nsoft.huaji2046.is_premium"
    
    // MARK: - 配置
    /// 订阅商品 ID，与 App Store Connect 中配置一致
    static let productIDs: [String] = [
        "com.nsoft.huaji2046.premium.monthly",
        "com.nsoft.huaji2046.premium.yearly"
    ]
    
    // MARK: - 发布状态
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: IAPError?
    
    /// 当前用户是否拥有有效高级版订阅
    @Published private(set) var isPremium: Bool {
        didSet {
            UserDefaults.standard.set(isPremium, forKey: Self.premiumKey)
        }
    }
    
    // MARK: - 初始化
    private init() {
        isPremium = UserDefaults.standard.bool(forKey: Self.premiumKey)
        Task {
            await observeTransactionUpdates()
        }
    }
    
    /// 非隔离域快速读取本地缓存的订阅状态（用于 DailyLimitManager 等）
    nonisolated static func cachedIsPremium() -> Bool {
        UserDefaults.standard.bool(forKey: premiumKey)
    }
    
    // MARK: - 加载商品
    /// 从 App Store 加载可售商品
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 沙盒/弱网环境下 Product.products 可能长时间不返回，加超时避免界面一直转圈
            products = try await withTimeout(seconds: 8) {
                try await Product.products(for: Self.productIDs)
            }
            products.sort { $0.price < $1.price }
            Log.info("IAP 商品加载成功: \(products.map { $0.displayName }.joined(separator: ", "))")
        } catch {
            if let timeout = error as? TimeoutError {
                Log.error("加载 IAP 商品超时")
            } else {
                lastError = .purchaseFailed(error.localizedDescription)
                Log.error("加载 IAP 商品失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 带超时的异步执行（超时抛 TimeoutError）
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private struct TimeoutError: Error {}
    
    // MARK: - 购买
    /// 购买指定商品
    func purchase(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try verify(verification)
            await transaction.finish()
            let premium = isTransactionActive(transaction)
            await updatePremiumStatus(premium, transaction: transaction)
            Log.info("IAP 购买成功: \(product.id), premium=\(premium)")
            
        case .userCancelled:
            lastError = .userCancelled
            throw IAPError.userCancelled
            
        case .pending:
            lastError = .pending
            throw IAPError.pending
            
        @unknown default:
            lastError = .unknown
            throw IAPError.unknown
        }
    }
    
    // MARK: - 恢复购买
    /// 恢复用户历史购买（Apple 要求必须提供）
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        
        var activePremium = false
        var latestTransaction: Transaction?
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                Log.warn("IAP entitlement 验证未通过")
                continue
            }
            
            if isTransactionActive(transaction) {
                activePremium = true
                latestTransaction = transaction
            }
        }
        
        await updatePremiumStatus(activePremium, transaction: latestTransaction)
        Log.info("IAP 恢复购买完成: premium=\(activePremium)")
    }
    
    // MARK: - 监听交易更新
    /// 监听 StoreKit 交易状态变化（续订、退款、过期等）
    private func observeTransactionUpdates() async {
        for await verificationResult in Transaction.updates {
            guard case .verified(let transaction) = verificationResult else {
                Log.warn("收到未验证的 StoreKit 交易更新")
                continue
            }
            
            await transaction.finish()
            let premium = isTransactionActive(transaction)
            await updatePremiumStatus(premium, transaction: transaction)
            Log.info("IAP 交易更新处理完成: \(transaction.productID), premium=\(premium)")
        }
    }
    
    // MARK: - 状态判断
    /// 判断交易是否处于有效订阅期
    private func isTransactionActive(_ transaction: Transaction) -> Bool {
        // 自动续期订阅：未撤销且未过期
        guard transaction.productType == .autoRenewable else { return false }
        guard transaction.revocationDate == nil else { return false }
        
        if let expirationDate = transaction.expirationDate {
            return expirationDate > Date()
        }
        return false
    }
    
    /// 校验 Apple 签名的交易
    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            Log.error("IAP 交易验证失败: \(error.localizedDescription)")
            throw IAPError.verificationFailed
        }
    }
    
    // MARK: - 服务端同步
    /// 把订阅状态同步到 Supabase 后端
    private func updatePremiumStatus(_ premium: Bool, transaction: Transaction?) async {
        isPremium = premium
        
        guard !AppConfig.useMockServices else { return }
        
        do {
            if let transaction = transaction {
                try await syncTransactionToServer(transaction, isActive: premium)
            } else {
                // 无交易对象时（例如恢复后无有效订阅），只更新 profiles.is_premium
                try await SupabaseService.shared.updatePremiumStatus(premium)
            }
        } catch {
            // 本地状态已更新，服务端同步失败不阻塞用户体验
            Log.error("同步订阅状态到服务端失败: \(error.localizedDescription)")
        }
    }
    
    /// 调用后端 Edge Function 保存交易并更新订阅状态
    private func syncTransactionToServer(_ transaction: Transaction, isActive: Bool) async throws {
        let payload = IAPSyncRequest(
            productId: transaction.productID,
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            expirationDate: transaction.expirationDate?.iso8601,
            purchaseDate: transaction.purchaseDate.iso8601,
            isActive: isActive
        )
        
        let _: IAPSyncResponse = try await BackendAPI.shared.post(
            path: "verify-transaction",
            body: payload
        )
    }
}

// MARK: - 网络请求模型
private struct IAPSyncRequest: Encodable {
    let productId: String
    let transactionId: String
    let originalTransactionId: String
    let expirationDate: String?
    let purchaseDate: String
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case transactionId = "transaction_id"
        case originalTransactionId = "original_transaction_id"
        case expirationDate = "expiration_date"
        case purchaseDate = "purchase_date"
        case isActive = "is_active"
    }
}

private struct IAPSyncResponse: Decodable {
    let isPremium: Bool
    
    enum CodingKeys: String, CodingKey {
        case isPremium = "is_premium"
    }
}

// MARK: - Date 扩展
private extension Date {
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }
}
