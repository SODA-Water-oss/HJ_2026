import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLogin = true
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var resetMessage = ""
    @State private var isResetting = false
    @FocusState private var focusedField: Field?
    
    enum Field { case email, password, confirmPassword }
    
    var body: some View {
        ZStack {
            // 背景
            AppTheme.background.ignoresSafeArea()
            
            // 顶部渐变装饰
            VStack(spacing: 0) {
                AppTheme.brandGradient
                    .frame(height: 300)
                    .clipShape(RoundedCorner(radius: 32, corners: [.bottomLeft, .bottomRight]))
                    .ignoresSafeArea(edges: .top)
                Spacer()
            }
            
            // 内容
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)
                    
                    // ---- 品牌头部 ----
                    VStack(spacing: 14) {
                        // APP 图标
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(.white)
                                .frame(width: 72, height: 72)
                                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
                            
                            VStack(spacing: 2) {
                                Image(systemName: "yensign.circle.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(AppTheme.brandStart)
                                Text("花记")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(AppTheme.brandStart)
                            }
                        }
                        
                        Text("张佩")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("智能记账系统")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 8)
                    
                    // ---- 登录/注册卡片 ----
                    VStack(spacing: 20) {
                        // 分段选择器
                        HStack(spacing: 0) {
                            segmentButton("登录", selected: isLogin) {
                                withAnimation(.easeInOut(duration: 0.25)) { isLogin = true; errorMessage = "" }
                            }
                            segmentButton("注册", selected: !isLogin) {
                                withAnimation(.easeInOut(duration: 0.25)) { isLogin = false; errorMessage = "" }
                            }
                        }
                        .padding(4)
                        .background(AppTheme.background)
                        .cornerRadius(10)
                        .padding(.bottom, 4)
                        
                        // 邮箱输入框
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 17))
                                .foregroundColor(focusedField == .email ? AppTheme.brandStart : AppTheme.textTertiary)
                                .frame(width: 20)
                            TextField("邮箱", text: $email)
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .focused($focusedField, equals: .email)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                            focusedField == .email ? AppTheme.brandStart : AppTheme.border,
                            lineWidth: focusedField == .email ? 1.5 : 1
                        ))
                        
                        // 密码输入框
                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 17))
                                .foregroundColor(focusedField == .password ? AppTheme.brandStart : AppTheme.textTertiary)
                                .frame(width: 20)
                            SecureField("密码", text: $password)
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                                .focused($focusedField, equals: .password)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                            focusedField == .password ? AppTheme.brandStart : AppTheme.border,
                            lineWidth: focusedField == .password ? 1.5 : 1
                        ))
                        
                        // 确认密码（仅注册模式）
                        if !isLogin {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(focusedField == .confirmPassword ? AppTheme.brandStart : AppTheme.textTertiary)
                                    .frame(width: 20)
                                SecureField("确认密码", text: $confirmPassword)
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .focused($focusedField, equals: .confirmPassword)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                                focusedField == .confirmPassword ? AppTheme.brandStart : AppTheme.border,
                                lineWidth: focusedField == .confirmPassword ? 1.5 : 1
                            ))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // 错误提示
                        if !errorMessage.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 15))
                                Text(errorMessage)
                                    .font(.system(size: 15))
                            }
                            .foregroundColor(Color(hex: "#EF4444"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#FEF2F2"))
                            .cornerRadius(8)
                            .transition(.opacity)
                        }
                        
                        // 主按钮
                        Button(action: authenticate) {
                            Text(isLoading ? (isLogin ? "登录中..." : "注册中...") : (isLogin ? "登录" : "注册"))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(isLoading || !isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.5)
                        .padding(.top, 4)
                        
                        // 忘记密码（仅登录模式）
                        if isLogin {
                            Button(action: { showForgotPassword = true }) {
                                Text("忘记密码？")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(.top, -4)
                            .sheet(isPresented: $showForgotPassword) {
                                ForgotPasswordView(
                                    isPresented: $showForgotPassword,
                                    resetEmail: $resetEmail,
                                    resetMessage: $resetMessage,
                                    isResetting: $isResetting,
                                    onReset: { email in
                                        Task {
                                            await authManager.resetPassword(email: email)
                                            await MainActor.run {
                                                isResetting = false
                                                resetMessage = "重置密码邮件已发送，请检查邮箱"
                                            }
                                        }
                                    }
                                )
                                .presentationDetents([.height(280)])
                            }
                        }
                    }
                    .padding(28)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: AppTheme.cardShadow, radius: 16, x: 0, y: 8)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLogin)
        .animation(.easeInOut(duration: 0.25), value: errorMessage)
        .onChange(of: isLogin) { _ in
            errorMessage = ""
            confirmPassword = ""
            focusedField = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focusedField = nil }
                    .foregroundColor(AppTheme.brandStart)
            }
        }
    }
    
    // MARK: - 分段按钮
    @ViewBuilder
    func segmentButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? .white : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? AppTheme.brandStart : Color.clear)
                )
        }
    }
    
    // MARK: - 表单验证
    var isFormValid: Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else { return false }
        if !isLogin {
            guard !confirmPassword.isEmpty,
                  password == confirmPassword else { return false }
        }
        return true
    }
    
    // MARK: - 认证
    func authenticate() {
        guard isFormValid else { return }
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                if isLogin {
                    try await authManager.signIn(email: email, password: password)
                } else {
                    try await authManager.signUp(email: email, password: password, confirmPassword: confirmPassword)
                }
                await MainActor.run { isLoading = false }
            } catch let error as AuthError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - 圆角裁剪形状
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}


// MARK: - 忘记密码视图
struct ForgotPasswordView: View {
    @Binding var isPresented: Bool
    @Binding var resetEmail: String
    @Binding var resetMessage: String
    @Binding var isResetting: Bool
    let onReset: (String) -> Void
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { isPresented = false }
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("重置密码")
                    .font(.appBody.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button("发送") {
                    guard resetEmail.contains("@"), resetEmail.contains(".") else {
                        resetMessage = "请输入有效的邮箱地址"
                        return
                    }
                    isResetting = true
                    resetMessage = ""
                    onReset(resetEmail)
                }
                .foregroundColor(AppTheme.brandStart)
                .fontWeight(.semibold)
                .disabled(isResetting || resetEmail.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            VStack(spacing: 16) {
                Text("请输入注册邮箱，我们将发送重置密码链接")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 17))
                        .foregroundColor(focused ? AppTheme.brandStart : AppTheme.textTertiary)
                    TextField("注册邮箱", text: $resetEmail)
                        .font(.appBody)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .focused($focused)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                    focused ? AppTheme.brandStart : AppTheme.border, lineWidth: focused ? 1.5 : 1))
                .padding(.horizontal, 16)
                
                if !resetMessage.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: isResetting ? "envelope.fill" : "checkmark.circle.fill")
                            .font(.system(size: 15))
                        Text(resetMessage)
                            .font(.system(size: 15))
                    }
                    .foregroundColor(Color(hex: "#10B981"))
                    .padding(.horizontal, 16)
                }
            }
            Spacer()
        }
        .background(.ultraThinMaterial)
    }
}
