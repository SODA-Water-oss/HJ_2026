import SwiftUI
import Supabase

struct MainTabView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 2
    @State private var showLockScreen = false
    @State private var lockTargetTab: Int? = nil
    @State private var ledgerLockVerified = false
    @State private var analyticsLockVerified = false
   
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
            
            ToolsView().tag(3)
                .tabItem {
                    Label("工具", systemImage: "wrench.and.screwdriver")
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
            if newTab == 0 && PageLockManager.isLedgerLocked && !ledgerLockVerified {
                lockTargetTab = 0
                showLockScreen = true
            } else if newTab == 1 && PageLockManager.isAnalyticsLocked && !analyticsLockVerified {
                lockTargetTab = 1
                showLockScreen = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                ledgerLockVerified = false
                analyticsLockVerified = false
                selectedTab = 2
            }
        }
              
            if supabaseService.isGloballyProcessing {
                globalProcessingOverlay
            }
            
            if showLockScreen {
                LockScreenView(
                    pageName: lockTargetTab == 0 ? "账本" : "分析",
                    mode: lockTargetTab == 0 ? PageLockManager.ledgerLockMode : PageLockManager.analyticsLockMode,
                    onVerifyPin: { pin in
                        let ok = lockTargetTab == 0 ? PageLockManager.verifyLedgerPin(pin) : PageLockManager.verifyAnalyticsPin(pin)
                        if !ok { return false }
                        if lockTargetTab == 0 { ledgerLockVerified = true }
                        else { analyticsLockVerified = true }
                        showLockScreen = false
                        return true
                    },
                    onVerifyPattern: { pattern in
                        let ok = lockTargetTab == 0 ? PageLockManager.verifyLedgerPin(pattern) : PageLockManager.verifyAnalyticsPin(pattern)
                        if !ok { return false }
                        if lockTargetTab == 0 { ledgerLockVerified = true }
                        else { analyticsLockVerified = true }
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
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var authManager: AuthManager
    @State private var ledgerLockEnabled = PageLockManager.isLedgerLocked
    @State private var analyticsLockEnabled = PageLockManager.isAnalyticsLocked
    @State private var showPinSetup = false
    @State private var showPasswordVerifyAlert = false
    @State private var lockSettingTarget = ""
    @State private var newPin = ""
    @State private var passwordInput = ""
    @State private var showUnlockMethodSheet = false
    @State private var showPatternSetup = false
    @State private var showPasswordText = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 4)
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
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
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 16)


                    Spacer(minLength: 8)
                    
                    VStack(spacing: 0) {
                        // 账本锁
                        HStack {
                            Image(systemName: "list.clipboard")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(width: 32)
                            Text("账本锁")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Button(action: {
                                if !ledgerLockEnabled {
                                    lockSettingTarget = "ledger"
                                    showPinSetup = false; newPin = ""
                                    showUnlockMethodSheet = true
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
                                        .background(ledgerLockEnabled ? Color.clear : AppTheme.textTertiary)
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
                        
                        // 分析锁
                        HStack {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(width: 32)
                            Text("分析锁")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Button(action: {
                                if !analyticsLockEnabled {
                                    lockSettingTarget = "analytics"
                                    showPinSetup = false; newPin = ""
                                    showUnlockMethodSheet = true
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
                                        .background(analyticsLockEnabled ? Color.clear : AppTheme.textTertiary)
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
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 32)
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
                        
                        
                        // 使用帮助
                        NavigationLink(destination: HelpView()) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 32)
                                Text("使用帮助")
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
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 32)
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
                        
                        // 意见反馈
                        Button(action: {
                            if let url = URL(string: "mailto:poundszero@126.com?subject=花计2046意见反馈") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "envelope")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "#7C3AED"))
                                    .frame(width: 32)
                                Text("意见反馈")
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
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 32)
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
                        

                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)

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
            .overlay {
                if showUnlockMethodSheet {
                    unlockMethodSheetOverlay
                }
            }
            .sheet(isPresented: $showPinSetup) {
                PinSetupView(newPin: $newPin, onConfirm: {
                    if lockSettingTarget == "ledger" {
                        PageLockManager.setLedgerLock(enabled: true, pin: newPin, mode: "pin")
                        ledgerLockEnabled = true
                    } else {
                        PageLockManager.setAnalyticsLock(enabled: true, pin: newPin, mode: "pin")
                        analyticsLockEnabled = true
                    }
                    showPinSetup = false; newPin = ""
                }, onCancel: {
                    showPinSetup = false; newPin = ""
                })
            }
            .overlay {
                if showPasswordVerifyAlert {
                    passwordVerifyOverlay
                }
            }
            .sheet(isPresented: $showPatternSetup) {
                PatternLockView(
                    isVerifyMode: false,
                    onComplete: { pattern in
                        showPatternSetup = false
                        if lockSettingTarget == "ledger" {
                            PageLockManager.setLedgerLock(enabled: true, pin: pattern, mode: "pattern")
                            ledgerLockEnabled = true
                        } else {
                            PageLockManager.setAnalyticsLock(enabled: true, pin: pattern, mode: "pattern")
                            analyticsLockEnabled = true
                        }
                    },
                    onCancel: {
                        showPatternSetup = false
                    }
                )
            }
        }
    }
}

// MARK: - 自定义解锁方式选择菜单 (替换系统 confirmationDialog)
extension ProfileView {
    @ViewBuilder
    var passwordVerifyOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showPasswordVerifyAlert = false
                        passwordInput = ""
                    }
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    Text("验证账户密码")
                        .font(.appTitle)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                    
                    Text("关闭页面锁需要验证账户密码")
                        .font(.appBody)
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.bottom, 20)
                    HStack(spacing: 10) {
                        if showPasswordText {
                            TextField("输入APP登录密码", text: $passwordInput)
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("输入APP登录密码", text: $passwordInput)
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                                .textContentType(.password)
                        }
                        Button(action: { showPasswordText.toggle() }) {
                            Image(systemName: showPasswordText ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.background)
                    .cornerRadius(10)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.background)
                        .cornerRadius(10)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    
                    Divider().padding(.horizontal, 24)
                    
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showPasswordVerifyAlert = false
                                passwordInput = ""
                            }
                        }) {
                            Text("取消")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider().frame(height: 44)
                        
                        Button(action: {
                            Task {
                                guard let email = supabaseService.currentUser?.email else { return }
                                do {
                                    try await supabaseService.client.auth.signIn(email: email, password: passwordInput)
                                   await MainActor.run {
                                        withAnimation(.easeOut(duration: 0.2)) {
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
                                            showPasswordVerifyAlert = false
                                            passwordInput = ""
                                        }
                                    }
                                } catch {
                                   await MainActor.run {
                                        showPasswordVerifyAlert = false
                                        passwordInput = ""
                                    }
                                }
                            }
                        }) {
                            Text("确认")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: -4)
                )
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .transition(.opacity)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showPasswordVerifyAlert)
    }
    @ViewBuilder
    var unlockMethodSheetOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showUnlockMethodSheet = false
                    }
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // 标题区
                    Text("选择解锁方式")
                        .font(.appTitle)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                    
                    Divider().padding(.horizontal, 16)
                    
                    // 4位数字密码
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showUnlockMethodSheet = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showPinSetup = true
                        }
                    }) {
                        HStack(spacing: 14) {
                            Image(systemName: "square.grid.3x3.square")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(width: 24)
                            Text("4位数字密码")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider().padding(.horizontal, 16)
                    
                    // 连线图案
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showUnlockMethodSheet = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showPatternSetup = true
                        }
                    }) {
                        HStack(spacing: 14) {
                            Image(systemName: "hand.point.up.fill")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(width: 24)
                            Text("连线图案")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider().padding(.horizontal, 16)
                    
                    // 取消
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showUnlockMethodSheet = false
                        }
                    }) {
                        Text("取消")
                            .font(.appBody)
                            .foregroundColor(AppTheme.textTertiary)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, 20)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: -4)
                )
                .padding(.horizontal, 20)
                
                .transition(.opacity)
                Spacer()
            }
        }
        .transition(.opacity)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showUnlockMethodSheet)
    }
}
