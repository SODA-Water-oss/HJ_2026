import Foundation

enum AppConfig {
    // MARK: - Feature Flag for Test Builds
   static let useMockServices: Bool = {
        // 已切换到 Supabase 云端存储
        // 用户数据通过 Supabase Auth + RLS 隔离
        return false
   }()

    // MARK: - DeepSeek API
    // 替换为你的 DeepSeek API Key
    static let deepSeekAPIKey: String = "sk-d28d949ce07e4bc4bc5ce0a47da0f52e"

    // MARK: - Hardcoded Configuration (bypasses Info.plist)
    static let supabaseURL: URL = URL(string: "https://iivroltxdlqzmscliuqw.supabase.co")!
    static let supabaseAnonKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlpdnJvbHR4ZGxxem1zY2xpdXF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4MDAwMzIsImV4cCI6MjA5MTM3NjAzMn0.mFPtu9tP2vANBG30wAycfbgdpNVAGud3o4y2x6pRtbc"
    static let supabaseFunctionsURL: URL = URL(string: "https://iivroltxdlqzmscliuqw.functions.supabase.co/functions/v1")!
    static let stripePublishableKey: String = "pk_test_REPLACE_ME"
}
