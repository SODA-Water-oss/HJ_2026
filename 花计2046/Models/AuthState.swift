import Foundation

// MARK: - 认证状态（状态机）
enum AuthState: Equatable {
    /// 启动时正在检查本地会话
    case checking
    /// 未登录
    case unauthenticated
    /// 已登录
    case authenticated(UserProfile)
    /// 发生错误
    case error(AuthError)
}

// MARK: - 认证错误类型
enum AuthError: Error, Equatable, Identifiable {
    case invalidEmail
    case invalidPassword
    case passwordMismatch
    case networkError(String)
    case serverError(String)
    case sessionExpired
    case unknown(String)
    
    var id: String { localizedDescription }
    
    var localizedDescription: String {
        switch self {
        case .invalidEmail: return "请输入有效的邮箱地址"
        case .invalidPassword: return "密码长度至少为6位"
        case .passwordMismatch: return "两次输入的密码不一致"
        case .networkError(let msg): return "网络连接失败：\(msg)"
        case .serverError(let msg): return msg
        case .sessionExpired: return "登录已过期，请重新登录"
        case .unknown(let msg): return msg
        }
    }
}

// MARK: - 认证会话（可持久化）
struct AuthSession: Codable {
    let userId: UUID
    let email: String
    let token: String
    var isPremium: Bool
    let createdAt: Date
}
