import Foundation
import Supabase
import Combine

// MARK: - 认证管理器（核心服务）
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    // MARK: - 发布属性
    @Published var authState: AuthState = .checking
    @Published var currentProfile: UserProfile?
    
    // 兼容旧代码的 isAuthenticated 属性
    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }
    
    // Keychain 存储 key
    private let sessionKey = "com.nsoft.gaode.auth_session"
    
    private init() {
        Log.info("AuthManager 初始化")
        restoreSession()
    }
    
    // MARK: - 启动时恢复会话
    func restoreSession() {
        Log.info("正在恢复会话...")
        
        // 1. 尝试从 Keychain 恢复
        if let session: AuthSession = KeychainHelper.loadCodable(AuthSession.self, forKey: sessionKey) {
            Log.info("Keychain 命中 userId=\(session.userId)")
            
            if AppConfig.useMockServices {
                let profile = UserProfile(
                    id: session.userId,
                    email: session.email,
                    isPremium: session.isPremium,
                    createdAt: session.createdAt
                )
                completeAuthentication(profile: profile)
            } else {
                // 云端模式：恢复 Supabase 会话
                Task {
                    do {
                        // 尝试用保存的 token 恢复会话，如果过期则重新登录
                        let _ = try await SupabaseService.shared.client.auth.session
                        let profile = UserProfile(
                            id: session.userId,
                            email: session.email,
                            isPremium: session.isPremium,
                            createdAt: session.createdAt
                        )
                        await MainActor.run { completeAuthentication(profile: profile) }
                    } catch {
                        Log.warn("云端会话恢复失败，需重新登录")
                        await MainActor.run { self.authState = .unauthenticated }
                    }
                }
                return
            }
            return
        }
        
        // 2. 无可持久会话 → 未登录
        Log.info("无持久会话，进入未登录状态")
        DispatchQueue.main.async {
            self.authState = .unauthenticated
        }
    }
    
    // MARK: - 登录
   func signIn(email: String, password: String) async throws {
       Log.info("AuthManager 登录 \(email)")
       
        // 1. 参数校验
       try validateCredentials(email: email, password: password)
       
       if AppConfig.useMockServices {
           try await mockAuthenticate(email: email, password: password)
       } else {
            // 2. Supabase 云端认证
            let session = try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
            let userId = session.user.id
            let isPremium = (email == "123456@126.com")
            let profile = UserProfile(id: userId, email: email, isPremium: isPremium, createdAt: Date())
            let authSession = AuthSession(userId: userId, email: email, token: session.accessToken, isPremium: isPremium, createdAt: profile.createdAt)
            KeychainHelper.saveCodable(authSession, forKey: sessionKey)
            await MainActor.run { completeAuthentication(profile: profile) }
            Log.info("云端登录成功 userId=\(userId)")
       }
   }
    
    // MARK: - 注册
    func signUp(email: String, password: String, confirmPassword: String) async throws {
        Log.info("AuthManager 注册 \(email)")
        
        // 1. 参数验证
        try validateCredentials(email: email, password: password)
        
        guard password == confirmPassword else {
            throw AuthError.passwordMismatch
        }
        
        // 2. 调用后端注册
        if AppConfig.useMockServices {
            try await mockAuthenticate(email: email, password: password, isNewUser: true)
        } else {
            let session = try await SupabaseService.shared.client.auth.signUp(email: email, password: password); let userId = session.user.id; let isPremium = (email == "123456@126.com"); let profile = UserProfile(id: userId, email: email, isPremium: isPremium, createdAt: Date()); let authSession = AuthSession(userId: userId, email: email, token: session.session?.accessToken ?? "", isPremium: isPremium, createdAt: profile.createdAt); KeychainHelper.saveCodable(authSession, forKey: sessionKey); await MainActor.run { completeAuthentication(profile: profile) }; Log.info("云端注册成功 userId=\(userId)")
        }
    }
    
    // MARK: - 重置密码
    func resetPassword(email: String) async {
        Log.info("AuthManager 重置密码 \(email)")
        
        if AppConfig.useMockServices {
            // Mock: 模拟发送邮件延迟
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            Log.info("Mock: 重置密码邮件已发送（模拟）到 \(email)")
        } else {
            // TODO: 调用后端发送重置密码邮件
            // try await supabaseService.resetPassword(email: email)
        }
    }
    
    // MARK: - 登出
    func signOut() {
        Log.info("AuthManager 登出")
        
        // 清除 Keychain
        KeychainHelper.delete(key: sessionKey)
        // 清除 SupabaseService 的登录状态
        Task { try? await SupabaseService.shared.signOut() }
        SupabaseService.shared.unreadExpenseCount = 0
        
        DispatchQueue.main.async {
            self.authState = .unauthenticated
            self.currentProfile = nil
        }
    }
    
    // MARK: - 内部逻辑
    
    private func validateCredentials(email: String, password: String) throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            throw AuthError.invalidEmail
        }
        
        guard password.count >= 6 else {
            throw AuthError.invalidPassword
        }
    }
    
    private func mockAuthenticate(email: String, password: String, isNewUser: Bool = false) async throws {
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 800_000_000)
        
        // 同邮箱始终用同一个 UUID，确保重新登录后数据不丢失
            let uidKey = "mock_uid_" + email
            let userId: UUID = {
                if let saved = UserDefaults.standard.string(forKey: uidKey),
                   let u = UUID(uuidString: saved) { return u }
                let u = UUID()
                UserDefaults.standard.set(u.uuidString, forKey: uidKey)
                return u
            }()
        let isPremium = (email == "123456@126.com")
        let profile = UserProfile(
            id: userId,
            email: email,
            isPremium: isPremium,
            createdAt: Date()
        )
        
        // 持久化会话到 Keychain
        let session = AuthSession(
            userId: userId,
            email: email,
            token: "mock_token_\(userId.uuidString)",
            isPremium: isPremium,
            createdAt: profile.createdAt
        )
        KeychainHelper.saveCodable(session, forKey: sessionKey)
        
        await MainActor.run {
            completeAuthentication(profile: profile)
        }
        
        Log.info("Mock 认证成功 email=\(email) isNew=\(isNewUser) premium=\(isPremium)")
    }
    
   private func completeAuthentication(profile: UserProfile) {
       self.currentProfile = profile
       self.authState = .authenticated(profile)
       
       // 同步到 SupabaseService（兼容旧代码）
       SupabaseService.shared.currentUser = SupabaseService.MockUser(
           id: profile.id,
           email: profile.email
       )
       SupabaseService.shared.userProfile = profile
       SupabaseService.shared.isAuthenticated = true
       
        // 登录时从磁盘重新加载数据，确保数据与当前用户匹配
        if AppConfig.useMockServices {
            SupabaseService.shared.loadExpensesFromDefaults()
        }
        
       NotificationCenter.default.post(name: Notification.Name("ExpensesDidUpdate"), object: nil)
   }
    
    // MARK: - 升级高级用户
    func upgradeToPremium() async {
        guard case .authenticated(let profile) = authState else {
            Log.warn("upgradeToPremium: 未登录")
            return
        }
        
        Log.info("升级高级用户 userId=\(profile.id)")
        
        // 更新 profile
        var updated = profile
        updated.isPremium = true
        
        // 更新 Keychain 会话
        if let stored: AuthSession = KeychainHelper.loadCodable(AuthSession.self, forKey: sessionKey) {
            var session = stored
            session.isPremium = true
            KeychainHelper.saveCodable(session, forKey: sessionKey)
        }
        
        await MainActor.run {
            completeAuthentication(profile: updated)
        }
        
        // 同步到 SupabaseService
        await SupabaseService.shared.upgradeToPremium()
    }
}
