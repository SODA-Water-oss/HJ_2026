import Foundation

/// 每日解析次数管理
struct DailyLimitManager {
    static let freeLimit = 10
    
    /// 当前用户每日限额（配置自己的智能体后不受次数限制）
    static var dailyLimit: Int {
        AgentConfigManager.cachedHasCustomAgent ? 9999 : freeLimit
    }
    
    /// 以 userID 和日期为键的 UserDefaults key
    private static func key(for userId: UUID) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return "parse_usage_\(df.string(from: Date()))_\(userId.uuidString)"
    }
    
    /// 当日已使用次数
    static func usedCount(for userId: UUID) -> Int {
        UserDefaults.standard.integer(forKey: key(for: userId))
    }
    
    /// 当日剩余次数
    static func remainingCount(for userId: UUID) -> Int {
        max(0, dailyLimit - usedCount(for: userId))
    }
    
    /// 是否有可用次数
    static func canParse(for userId: UUID) -> Bool {
        if AgentConfigManager.cachedHasCustomAgent { return true }
        return remainingCount(for: userId) > 0
    }
    
    /// 进账成功后调用：增加一次使用
    static func incrementUsage(for userId: UUID) {
        let k = key(for: userId)
        UserDefaults.standard.set(usedCount(for: userId) + 1, forKey: k)
    }
}
