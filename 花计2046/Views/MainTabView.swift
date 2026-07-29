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
    @State private var dueBillCount = 0
    
    private var tabBinding: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == 0 && PageLockManager.isLedgerLocked && !ledgerLockVerified {
                    lockTargetTab = 0
                    showLockScreen = true
                } else if newValue == 1 && PageLockManager.isAnalyticsLocked && !analyticsLockVerified {
                    lockTargetTab = 1
                    showLockScreen = true
                } else {
                    selectedTab = newValue
                }
            }
        )
    }
    


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
            TabView(selection: tabBinding) {
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
                    .badge(dueBillCount)
                
                ProfileView().tag(4)
                    .tabItem {
                        Label("我的", systemImage: "person.crop.circle")
                    }
            }
            .tint(AppTheme.brandStart)
            .task {
                try? await UNUserNotificationCenter.current().setBadgeCount(0)
                try? await supabaseService.preloadAllRecords()
            }

            .onChange(of: scenePhase) { _, phase in
                if phase == .background || phase == .inactive {
                    ledgerLockVerified = false
                    analyticsLockVerified = false
                    
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
                        selectedTab = lockTargetTab ?? 2
                        showLockScreen = false
                        return true
                    },
                    onVerifyPattern: { pattern in
                        let ok = lockTargetTab == 0 ? PageLockManager.verifyLedgerPin(pattern) : PageLockManager.verifyAnalyticsPin(pattern)
                        if !ok { return false }
                        if lockTargetTab == 0 { ledgerLockVerified = true }
                        else { analyticsLockVerified = true }
                        selectedTab = lockTargetTab ?? 2
                        showLockScreen = false
                        return true
                    },
                    onCancel: {
                        showLockScreen = false
                    }
                )
                .transition(.opacity)
                .zIndex(100)
                .ignoresSafeArea()
            }

    }
        }

    
    
    private func updateDueBillCount() {
        guard let data = UserDefaults.standard.data(forKey: "bill_reminders"),
              let bills = try? JSONDecoder().decode([BillItem].self, from: data) else {
            dueBillCount = 0
            return
        }
        let now = Date()
        dueBillCount = bills.filter { bill in
            guard bill.isEnabled, let due = bill.nextDueDate else { return false }
            let daysLeft = Calendar.current.dateComponents([.day], from: now, to: due).day ?? 999
            return daysLeft >= 0 && daysLeft <= 3
        }.count
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
    @AppStorage("page_lock_ledger_enabled") private var ledgerLockEnabled = false
    @AppStorage("page_lock_analytics_enabled") private var analyticsLockEnabled = false
    @State private var showPinSetup = false
    @State private var showPasswordVerifyAlert = false
    @State private var lockSettingTarget = ""
    @State private var newPin = ""
    @State private var passwordInput = ""
    @State private var passwordError = ""
    @State private var showUnlockMethodSheet = false
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    @State private var showCurrencyPicker = false
    @State private var pendingCurrencyName = ""
    @State private var showCurrencyConfirm = false
    @State private var currencyPickerStep = 0
    @State private var selectedCurrency: (name: String, symbol: String)? = nil
    @State private var showLogoutAlert = false
    private let currencyOptions: [(name: String, symbol: String)] = [("人民币", "¥"), ("美元", "$"), ("欧元", "€"), ("英镑", "£")]
    
    @ViewBuilder
    private var currencyLabel: some View {
        HStack(spacing: 8) {
            if let current = currencyOptions.first(where: { $0.symbol == currencySymbol }) {
                Text(current.name + " " + current.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.brandStart)
            } else {
                Text(currencySymbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.brandStart)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(AppTheme.background)
        .cornerRadius(8)
    }
    
    @State private var showPatternSetup = false
    @State private var showPasswordText = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 16)
                    
                    // User card
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
                    
                    Spacer(minLength: 10)
                    
                    // Card 1: 安全
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
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(ledgerLockEnabled ? AppTheme.textTertiary : .white)
                                        .frame(width: 34, height: 28)
                                        .background(ledgerLockEnabled ? Color.clear : AppTheme.textTertiary)
                                        .cornerRadius(12)
                                    Text("开")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(ledgerLockEnabled ? .white : AppTheme.textTertiary)
                                        .frame(width: 34, height: 28)
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
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(analyticsLockEnabled ? AppTheme.textTertiary : .white)
                                        .frame(width: 34, height: 28)
                                        .background(analyticsLockEnabled ? Color.clear : AppTheme.textTertiary)
                                        .cornerRadius(12)
                                    Text("开")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(analyticsLockEnabled ? .white : AppTheme.textTertiary)
                                        .frame(width: 34, height: 28)
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
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 10)
                    
                    // Card 2: 偏好
                    VStack(spacing: 0) {
                        NavigationLink(destination: CategoryView().environmentObject(supabaseService)) {
                            HStack {
                                Image(systemName: "tag")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 32)
                                Text("收支类别")
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
                        
                        // 货币设置
                        HStack {
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(width: 32)
                            Text("货币设置")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text(currencyOptions.first(where: { $0.symbol == currencySymbol }).map { $0.name + " " + $0.symbol } ?? currencySymbol)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.brandStart)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(AppTheme.background)
                                .cornerRadius(8)
                                .onTapGesture { pendingCurrencyName = currencySymbol; showCurrencyPicker = true }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .padding(16)
                        
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 10)
                    
                    // Card 3: 其他
                    VStack(spacing: 0) {
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
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    Spacer(minLength: 10)
                    
                    // Card: 退出登录
                    VStack(spacing: 0) {
                        // 退出登录
                        Button(action: { showLogoutAlert = true }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 32)
                                Text("退出登录")
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.brandStart)
                                Spacer()
                            }
                            .padding(16)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
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
                        UserSettingsSync.syncToCloud(supabaseService: supabaseService)
                    } else {
                        PageLockManager.setAnalyticsLock(enabled: true, pin: newPin, mode: "pin")
                        analyticsLockEnabled = true
                        UserSettingsSync.syncToCloud(supabaseService: supabaseService)
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
                            UserSettingsSync.syncToCloud(supabaseService: supabaseService)
                        } else {
                            PageLockManager.setAnalyticsLock(enabled: true, pin: pattern, mode: "pattern")
                            analyticsLockEnabled = true
                            UserSettingsSync.syncToCloud(supabaseService: supabaseService)
                        }
                    },
                    onCancel: {
                        showPatternSetup = false
                    }
                )
            }
        }
        .sheet(isPresented: $showCurrencyPicker, onDismiss: {
            if !pendingCurrencyName.isEmpty, pendingCurrencyName != currencySymbol {
                showCurrencyConfirm = true
            }
        }) {
            CurrencyEditPicker(selection: $pendingCurrencyName, options: currencyOptions)
                .presentationDetents([.height(260)])
        }
        .alert("确认切换货币", isPresented: $showCurrencyConfirm) {
            Button("取消", role: .cancel) {
                pendingCurrencyName = ""
            }
            Button("确认") {
                currencySymbol = pendingCurrencyName
                pendingCurrencyName = ""
            }
        } message: {
            if let cur = currencyOptions.first(where: { $0.symbol == pendingCurrencyName }) {
                Text("是否确认后续使用" + cur.name + "（" + cur.symbol + "）记账？")
            } else {
                Text("是否确认后续使用" + pendingCurrencyName + "记账？")
            }
        }
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




// MARK: - 自定义解锁方式选择菜单


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
                        .padding(.bottom, 16)
                    
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(AppTheme.background)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    if !passwordError.isEmpty {
                        Text(passwordError)
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.brandStart)
                            .padding(.bottom, 12)
                    }
                    
                    Divider().padding(.horizontal, 24)
                    
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showPasswordVerifyAlert = false
                                passwordInput = ""
                                passwordError = ""
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
                                                UserSettingsSync.syncToCloud(supabaseService: supabaseService)
                                            } else if lockSettingTarget == "analytics" {
                                                PageLockManager.setAnalyticsLock(enabled: false)
                                                analyticsLockEnabled = false
                                                UserSettingsSync.syncToCloud(supabaseService: supabaseService)
                                            } else if lockSettingTarget == "clear_all" {
                                                PageLockManager.clearAllLocks()
                                                ledgerLockEnabled = false
                                                analyticsLockEnabled = false
                                                UserSettingsSync.syncToCloud(supabaseService: supabaseService)
                                            }
                                            showPasswordVerifyAlert = false
                                            passwordInput = ""
                                            passwordError = ""
                                        }
                                    }
                                } catch {
                                    await MainActor.run {
                                        passwordError = "密码录入错误！"
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
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: -4)
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
                
                Spacer()
            }
        }
        .transition(.opacity)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showUnlockMethodSheet)
    }
}
