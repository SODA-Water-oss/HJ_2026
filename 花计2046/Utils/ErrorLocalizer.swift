import Foundation

/// 错误信息中文化工具
/// 将 SDK / 网络等英文错误映射为面向用户的中文提示。
/// 我们的自定义错误（AuthError / IAPError / BackendAPIError）本身已是中文，直接透传。
extension Error {
    /// 面向用户显示的中文错误描述（未知错误不暴露英文原文，避免用户困惑）
    var userFriendlyDescription: String {
        // 自定义错误：本身是中文
        if let auth = self as? AuthError { return auth.localizedDescription }
        if let iap = self as? IAPError { return iap.localizedDescription }
        if let api = self as? BackendAPIError { return api.errorDescription ?? "请求失败，请稍后重试" }

        // URLSession 网络错误
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "网络连接失败，请检查网络设置"
            case .timedOut:
                return "请求超时，请稍后重试"
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "无法连接服务器，请检查网络"
            case .networkConnectionLost:
                return "网络连接已断开，请重试"
            default:
                return "网络请求失败，请稍后重试"
            }
        }

        // 其他错误（Supabase SDK 等）：按关键词映射为中文
        return Self.map(localizedDescription)
    }

    private static func map(_ msg: String) -> String {
        let low = msg.lowercased()
        if low.contains("rate limit") {
            return "操作过于频繁，请稍后再试"
        }
        if low.contains("already registered") || low.contains("already exists") || low.contains("user already") {
            return "该邮箱已注册，请直接登录"
        }
        if low.contains("invalid email") || low.contains("email_address_invalid") || low.contains("email not allowed") {
            return "邮箱格式不正确或不允许注册"
        }
        if low.contains("password") && low.contains("weak") {
            return "密码强度不足，请使用更复杂的密码"
        }
        if low.contains("invalid login") || low.contains("invalid credentials") || low.contains("invalidpassword") || low.contains("invalid password") {
            return "邮箱或密码错误"
        }
        if low.contains("user not found") || low.contains("no user") {
            return "用户不存在"
        }
        if low.contains("unexpected error") {
            return "服务器响应异常，请稍后重试"
        }
        if low.contains("not connected") || low.contains("network") || low.contains("internet") {
            return "网络连接失败，请检查网络"
        }
        if low.contains("timeout") || low.contains("timed out") {
            return "请求超时，请稍后重试"
        }
        if low.contains("unauthorized") || (low.contains("session") && low.contains("expired")) {
            return "登录已过期，请重新登录"
        }
        if low.contains("forbidden") {
            return "没有权限执行该操作"
        }
        if low.contains("not found") {
            return "请求的内容不存在"
        }
        if low.contains("server error") || low.contains("500") || low.contains("502") || low.contains("503") {
            return "服务器开小差了，请稍后重试"
        }
        return "操作失败，请稍后重试"
    }
}
