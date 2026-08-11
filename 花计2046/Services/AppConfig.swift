import Foundation

/// 应用配置统一从 Info.plist 读取。
/// 真实密钥通过 xcconfig → INFOPLIST_KEY_* 注入，避免写入源码。
enum AppConfig {
    // MARK: - Feature Flag
    static let useMockServices: Bool = {
        #if DEBUG
        // Debug 下可通过 Xcode Build Settings 的 USE_MOCK_SERVICES 控制
        return Bundle.main.object(forInfoDictionaryKey: "USE_MOCK_SERVICES") as? String == "YES"
        #else
        return false
        #endif
    }()

    // MARK: - DeepSeek（仅 DEBUG 文字解析使用）
    static var deepSeekAPIKey: String {
        string(for: "DEEPSEEK_API_KEY")
    }

    // MARK: - Supabase
    static var supabaseURL: URL {
        url(for: "SUPABASE_URL")
    }

    static var supabaseAnonKey: String {
        string(for: "SUPABASE_ANON_KEY")
    }

    static var supabaseFunctionsURL: URL {
        url(for: "SUPABASE_FUNCTIONS_URL")
    }

    // MARK: - 密码重置深链
    /// 密码重置邮件的 redirect URL（自定义 scheme，需与 Info.plist 中的 CFBundleURLSchemes 一致）
    static var passwordResetRedirectURL: URL? {
        URL(string: "huaji2046://reset-password")
    }

    // MARK: - Helpers
    private static func string(for key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }

    private static func url(for key: String) -> URL {
        let raw = string(for: key)
        guard let url = URL(string: raw), !raw.isEmpty else {
            // 开发阶段缺失配置时给一个明显无效的占位 URL，避免可选类型污染全工程
            return URL(string: "https://example.com")!
        }
        return url
    }
}
