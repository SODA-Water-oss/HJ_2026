import Foundation
import Supabase

struct PageLockManager {
    private static let ledgerEnabledKey = "page_lock_ledger_enabled"
    private static let analyticsEnabledKey = "page_lock_analytics_enabled"
    private static let ledgerPinKey = "page_lock_ledger_pin"
    private static let analyticsPinKey = "page_lock_analytics_pin"
    
    // MARK: - 锁模式
    static var ledgerLockMode: String {
        get { UserDefaults.standard.string(forKey: "ledger_lock_mode") ?? "pin" }
        set { UserDefaults.standard.set(newValue, forKey: "ledger_lock_mode") }
    }
    static var analyticsLockMode: String {
        get { UserDefaults.standard.string(forKey: "analytics_lock_mode") ?? "pin" }
        set { UserDefaults.standard.set(newValue, forKey: "analytics_lock_mode") }
    }
    
    static func lockMode(for target: String) -> String {
        target == "ledger" ? ledgerLockMode : analyticsLockMode
    }
    
    // MARK: - 账本页锁
    static var isLedgerLocked: Bool {
        UserDefaults.standard.bool(forKey: ledgerEnabledKey)
    }
    
    static func setLedgerLock(enabled: Bool, pin: String? = nil, mode: String = "pin") {
        UserDefaults.standard.set(enabled, forKey: ledgerEnabledKey)
        ledgerLockMode = mode
        if enabled, let pin = pin {
            KeychainHelper.saveCodable(pin, forKey: ledgerPinKey)
        }
        if !enabled {
            KeychainHelper.delete(key: ledgerPinKey)
        }
    }
    
    static func verifyLedgerPin(_ pin: String) -> Bool {
        guard let stored: String = KeychainHelper.loadCodable(String.self, forKey: ledgerPinKey) else { return false }
        return pin == stored
    }
    
    // MARK: - 分析页锁
    static var isAnalyticsLocked: Bool {
        UserDefaults.standard.bool(forKey: analyticsEnabledKey)
    }
    
    static func setAnalyticsLock(enabled: Bool, pin: String? = nil, mode: String = "pin") {
        UserDefaults.standard.set(enabled, forKey: analyticsEnabledKey)
        analyticsLockMode = mode
        if enabled, let pin = pin {
            KeychainHelper.saveCodable(pin, forKey: analyticsPinKey)
        }
        if !enabled {
            KeychainHelper.delete(key: analyticsPinKey)
        }
    }
    
    static func verifyAnalyticsPin(_ pin: String) -> Bool {
        guard let stored: String = KeychainHelper.loadCodable(String.self, forKey: analyticsPinKey) else { return false }
        return pin == stored
    }
    
    // MARK: - 解除所有锁（验证账户密码后清空）
    static func clearAllLocks() {
        UserDefaults.standard.set(false, forKey: ledgerEnabledKey)
        UserDefaults.standard.set(false, forKey: analyticsEnabledKey)
        UserDefaults.standard.removeObject(forKey: "ledger_lock_mode")
        UserDefaults.standard.removeObject(forKey: "analytics_lock_mode")
        KeychainHelper.delete(key: ledgerPinKey)
        KeychainHelper.delete(key: analyticsPinKey)
    }
}
