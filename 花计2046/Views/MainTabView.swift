import SwiftUI
import Supabase

struct MainTabView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var selectedTab = 2
    @State private var showLockScreen = false
    @State private var lockTargetTab: Int? = nil
    @State private var lockVerified = false
   
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.white
        appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = UIColor(AppTheme.brandEnd)
        appearance.stackedLayoutAppearance.normal.badgeTextAttributes = [.foregroundColor: UIColor.white]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack {
        TabView(selection: $selectedTab) {
            ExpenseListView().tag(0)
                .tabItem {
                    Label("账本", systemImage: "list.clipboard")
                }
                .badge(supabaseService.unreadExpenseCount)
            
            AnalyticsView().tag(1)
                .tabItem {
                    Label("分析", systemImage: "chart.pie")
                }
            
            AddExpenseView().tag(2)
                .tabItem {
                    Label("录入", systemImage: "square.and.pencil")
                }
            
            SubscriptionView().tag(3)
                .tabItem {
                    Label("帮助", systemImage: "questionmark.circle")
                }
            
            ProfileView().tag(4)
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(AppTheme.brandStart)
        .task {
            try? await supabaseService.preloadAllRecords()
        }
        .onChange(of: selectedTab) { _, newTab in
            guard !lockVerified else { lockVerified = false; return }
            if newTab == 0 && PageLockManager.isLedgerLocked {
                lockTargetTab = 0
                showLockScreen = true
            } else if newTab == 1 && PageLockManager.isAnalyticsLocked {
                lockTargetTab = 1
                showLockScreen = true
            }
        }
        if supabaseService.isGloballyProcessing {
            globalProcessingOverlay
        }
        
        if showLockScreen {
            LockScreenView(
                pageName: lockTargetTab == 0 ? "账本页" : "分析页",
                mode: lockTargetTab == 0 ? PageLockManager.ledgerLockMode : PageLockManager.analyticsLockMode,
                onVerifyPin: { pin in
                    let ok = lockTargetTab == 0 ? PageLockManager.verifyLedgerPin(pin) : PageLockManager.verifyAnalyticsPin(pin)
                    if !ok { return false }
                    lockVerified = true
                    showLockScreen = false
                    return true
                },
                onVerifyPattern: { pattern in
                    let ok = lockTargetTab == 0 ? PageLockManager.verifyLedgerPin(pattern) : PageLockManager.verifyAnalyticsPin(pattern)
                    if !ok { return false }
                    lockVerified = true
                    showLockScreen = false
                    return true
                },
                onCancel: {
                    selectedTab = 2
                    showLockScreen = false
                }
            )
            .transition(.opacity)
            .zIndex(100)
            .ignoresSafeArea()
        }
        }
        .animation(.easeInOut(duration: 0.2), value: showLockScreen)
    }
    
    @ViewBuilder
    private var globalProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 20) {
                if let bp = supabaseService.batchProgress, bp.1 > 0 {
                    PawPrintProgress(current: bp.0, total: bp.1)
                }
                Text(supabaseService.globalProcessingMessage.isEmpty ? "处理中..." : supabaseService.globalProcessingMessage)
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        }
        .ignoresSafeArea()
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
}

struct ProfileView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    @State private var showLogoutAlert = false
    @State private var ledgerLockEnabled = PageLockManager.isLedgerLocked
    @State private var analyticsLockEnabled = PageLockManager.isAnalyticsLocked
    @State private var showSetPinAlert = false
    @State private var showPasswordVerifyAlert = false
    @State private var lockSettingTarget = ""
    @State private var newPin = ""
    @State private var passwordInput = ""
    @State private var showModePicker = false
    @State private var showPatternSetup = false
    @State private var patternSetupMode: PatternLockView.PatternMode = .set(first: nil)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 4)
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.brandStart)
                        
                        Text(supabaseService.currentUser?.email ?? "未知用户")
                            .font(.appTitle)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        HStack {
                            Circle().fill(AppTheme.brandGradient).frame(width: 8, height: 8)
                            Text("高级版")
                                .font(.appSmall)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 16)


                    Spacer(minLength: 24)
                    
                    VStack(spacing: 0) {
                        // 账本页锁
                        HStack {
                            Image(systemName: "list.clipboard")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(width: 24)
                            Text("账本页锁")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Button(action: {
                                if !ledgerLockEnabled {
                                    lockSettingTarget = "ledger"
                                    newPin = ""
                                    showModePicker = true
                                } else {
                                    lockSettingTarget = "ledger"
                                    passwordInput = ""
                                    showPasswordVerifyAlert = true
                                }
                            }) {
                                HStack(spacing: 0) {
                                    Text("关")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(ledgerLockEnabled ? AppTheme.textTertiary : .white)
                                        .frame(width: 28, height: 24)
                                        .background(ledgerLockEnabled ? Color.clear : AppTheme.brandStart)
                                        .cornerRadius(12)
                                    Text("开")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(ledgerLockEnabled ? .white : AppTheme.textTertiary)
                                        .frame(width: 28, height: 24)
                                        .background(ledgerLockEnabled ? AppTheme.brandStart : Color.clear)
                                        .cornerRadius(12)
                                }
                                .background(AppTheme.border)
                                .cornerRadius(12)
                            }
                        }
                        .padding(16)
                        
                        Divider().padding(.horizontal, 16)
                        
                        // 分析页锁
                        HStack {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(width: 24)
                            Text("分析页锁")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Button(action: {
                                if !analyticsLockEnabled {
                                    lockSettingTarget = "analytics"
                                    newPin = ""
                                    showModePicker = true
                                } else {
                                    lockSettingTarget = "analytics"
                                    passwordInput = ""
                                    showPasswordVerifyAlert = true
                                }
                            }) {
                                HStack(spacing: 0) {
                                    Text("关")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(analyticsLockEnabled ? AppTheme.textTertiary : .white)
                                        .frame(width: 28, height: 24)
                                        .background(analyticsLockEnabled ? Color.clear : AppTheme.brandStart)
                                        .cornerRadius(12)
                                    Text("开")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(analyticsLockEnabled ? .white : AppTheme.textTertiary)
                                        .frame(width: 28, height: 24)
                                        .background(analyticsLockEnabled ? AppTheme.brandStart : Color.clear)
                                        .cornerRadius(12)
                                }
                                .background(AppTheme.border)
                                .cornerRadius(12)
                            }
                        }
                        .padding(16)
                        
                        Divider().padding(.horizontal, 16)
                        
                        // 解除所有页面锁
                        Button(action: {
                            lockSettingTarget = "clear_all"
                            passwordInput = ""
                            showPasswordVerifyAlert = true
                        }) {
                            HStack {
                                Image(systemName: "lock.open")
                                    .font(.system(size: 17))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 24)
                                Text("解除所有页面锁")
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(16)
                        }
                        
                        Divider().padding(.horizontal, 16)
                        
                        // 操作日志
                        NavigationLink(destination: UserLogView().environmentObject(supabaseService)) {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 17))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 24)
                                Text("操作日志")
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(16)
                        }
                        
                        Divider().padding(.horizontal, 16)
                        
                        // 用户设置
                        NavigationLink(destination: UserSettingsView().environmentObject(supabaseService).environmentObject(authManager)) {
                            HStack {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 17))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 24)
                                Text("用户设置")
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(16)
                        }
                        
                        Divider().padding(.horizontal, 16)
                        
                        // 退出登录
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 17))
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                Text("退出登录")
                                    .font(.appBody)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(16)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .alert("退出登录", isPresented: $showLogoutAlert) {
                        Button("取消", role: .cancel) { }
                        Button("确认退出", role: .destructive) {
                            authManager.signOut()
                        }
                    } message: {
                        Text("是否确定退出当前登录？")
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("我的")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("设置页面锁密码", isPresented: $showSetPinAlert) {
                SecureField("输入4位数字密码", text: $newPin)
                    .keyboardType(.numberPad)
                Button("取消", role: .cancel) { }
                Button("确认") {
                    guard newPin.count == 4 else { return }
                    if lockSettingTarget == "ledger" {
                        PageLockManager.setLedgerLock(enabled: true, pin: newPin, mode: "pin")
                        ledgerLockEnabled = true
                    } else {
                        PageLockManager.setAnalyticsLock(enabled: true, pin: newPin, mode: "pin")
                        analyticsLockEnabled = true
                    }
                }
            } message: {
                Text("请设置4位数字密码")
            }
            .alert("验证账户密码", isPresented: $showPasswordVerifyAlert) {
                SecureField("输入APP登录密码", text: $passwordInput)
                Button("取消", role: .cancel) { }
                Button("确认") {
                    Task {
                        guard let email = supabaseService.currentUser?.email else { return }
                        do {
                            try await supabaseService.client.auth.signIn(email: email, password: passwordInput)
                           await MainActor.run {
                                if lockSettingTarget == "ledger" {
                                    PageLockManager.setLedgerLock(enabled: false)
                                    ledgerLockEnabled = false
                                } else if lockSettingTarget == "analytics" {
                                    PageLockManager.setAnalyticsLock(enabled: false)
                                    analyticsLockEnabled = false
                                } else if lockSettingTarget == "clear_all" {
                                    PageLockManager.clearAllLocks()
                                    ledgerLockEnabled = false
                                    analyticsLockEnabled = false
                                }
                            }
                        } catch {
                            // Wrong password - silently handle
                        }
                    }
                }
            } message: {
                Text("关闭页面锁需要验证账户密码")
            }
            .confirmationDialog("选择解锁方式", isPresented: $showModePicker, titleVisibility: .visible) {
                Button("4位数字密码") { showSetPinAlert = true }
                Button("连线图案") { showPatternSetup = true }
                Button("取消", role: .cancel) { }
            }
            .sheet(isPresented: $showPatternSetup) {
                PatternLockView(
                    mode: patternSetupMode,
                    onComplete: { result in
                        if result.hasPrefix("set_first:") {
                            let pattern = String(result.dropFirst(10))
                            patternSetupMode = .set(first: pattern)
                        } else if result.hasPrefix("set_confirm:") {
                            let pattern = String(result.dropFirst(13))
                            showPatternSetup = false
                            if lockSettingTarget == "ledger" {
                                PageLockManager.setLedgerLock(enabled: true, pin: pattern, mode: "pattern")
                                ledgerLockEnabled = true
                            } else {
                                PageLockManager.setAnalyticsLock(enabled: true, pin: pattern, mode: "pattern")
                                analyticsLockEnabled = true
                            }
                        }
                    },
                    onCancel: {
                        showPatternSetup = false
                        patternSetupMode = .set(first: nil)
                    }
                )
            }
        }
    }
}
