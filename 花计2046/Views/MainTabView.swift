import SwiftUI
import Supabase

struct MainTabView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @ObservedObject private var userSettings = UserSettingsManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 2
    @State private var showLockScreen = false
    @State private var lockTargetTab: Int? = nil
    @State private var ledgerLockVerified = false
    @State private var analyticsLockVerified = false
    @State private var dueBillCount = 0
    @State private var ledgerLockEnabled = UserSettingsManager.shared.ledgerLockEnabled
    @State private var analyticsLockEnabled = UserSettingsManager.shared.analyticsLockEnabled
    
    private var tabBinding: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == 0 && userSettings.ledgerLockEnabled && !ledgerLockVerified {
                    lockTargetTab = 0
                    showLockScreen = true
                } else if newValue == 1 && userSettings.analyticsLockEnabled && !analyticsLockVerified {
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
        let purple = UIColor(AppTheme.brandEnd)
        // 三种布局 x 两种状态都设为标准紫色角标（避免部分布局回退系统红色）
        for layout in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            layout.normal.badgeBackgroundColor = purple
            layout.normal.badgeTextAttributes = [.foregroundColor: UIColor.white]
            layout.selected.badgeBackgroundColor = purple
            layout.selected.badgeTextAttributes = [.foregroundColor: UIColor.white]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBarItem.appearance().badgeColor = purple
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
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                ledgerLockEnabled = userSettings.ledgerLockEnabled
                analyticsLockEnabled = userSettings.analyticsLockEnabled
                updateDueBillCount()
                clearAppIconBadge()
            }
            .task {
                try? await UNUserNotificationCenter.current().setBadgeCount(0)
                await supabaseService.fetchProfile()
                try? await supabaseService.preloadAllRecords()
                await userSettings.loadFromCloud()
                ledgerLockEnabled = userSettings.ledgerLockEnabled
                analyticsLockEnabled = userSettings.analyticsLockEnabled
                updateDueBillCount()
            }

            .onChange(of: scenePhase) { _, phase in
                if phase == .background || phase == .inactive {
                    ledgerLockVerified = false
                    analyticsLockVerified = false
                    
                }
                if phase == .active {
                    updateDueBillCount()
                    clearAppIconBadge()
                }
            }
            
            if supabaseService.isGloballyProcessing {
                globalProcessingOverlay
            }
            
            if showLockScreen {
                LockScreenView(
                    pageName: lockTargetTab == 0 ? "账本" : "分析",
                    mode: lockTargetTab == 0 ? userSettings.ledgerLockMode : userSettings.analyticsLockMode,
                    onVerifyPin: { pin in
                        let ok = lockTargetTab == 0 ? userSettings.verifyLedgerPin(pin) : userSettings.verifyAnalyticsPin(pin)
                        if !ok { return false }
                        if lockTargetTab == 0 { ledgerLockVerified = true }
                        else { analyticsLockVerified = true }
                        selectedTab = lockTargetTab ?? 2
                        showLockScreen = false
                        return true
                    },
                    onVerifyPattern: { pattern in
                        let ok = lockTargetTab == 0 ? userSettings.verifyLedgerPin(pattern) : userSettings.verifyAnalyticsPin(pattern)
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

    
    
    /// 清除 App 图标数字角标（通知角标是"未读提醒"语义，进入/操作后即清零）
    private func clearAppIconBadge() {
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
    }
    
    private func updateDueBillCount() {
        guard let data = UserDefaults.standard.data(forKey: "bill_reminders_cache"),
              let bills = try? JSONDecoder().decode([BillItem].self, from: data) else {
            dueBillCount = 0
            return
        }
        let now = Date()
        // 严格按提醒时刻：到期日+提醒时间已到（且未付）才显示角标，不做提前 3 天预警
        dueBillCount = bills.filter { bill in
            guard bill.isEnabled, !bill.isPaidThisPeriod, !bill.isCompleted, !bill.isExpiredOnce,
                  let dueMoment = bill.dueMoment else { return false }
            return dueMoment <= now
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
    @ObservedObject private var userSettings = UserSettingsManager.shared
    @ObservedObject private var agentManager = AgentConfigManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var authManager: AuthManager
    @State private var ledgerLockEnabled = UserSettingsManager.shared.ledgerLockEnabled
    @State private var analyticsLockEnabled = UserSettingsManager.shared.analyticsLockEnabled
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
    @State private var showNameEdit = false
    @State private var nameInput = ""
    @State private var currencyPickerStep = 0
    @State private var selectedCurrency: (name: String, symbol: String)? = nil
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountConfirmAlert = false
    @State private var isDeletingAccount = false
    @State private var showAgentConfig = false
    private let currencyOptions: [(name: String, symbol: String)] = [("人民币", "¥"), ("美元", "$"), ("欧元", "€"), ("英镑", "£")]
    
    private var nicknameDisplay: String {
        if let n = supabaseService.userProfile?.name, !n.isEmpty { return n }
        return "设置昵称"
    }
    
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
    @State private var showLegalDocument = false
    @State private var legalDocumentType: LegalDocumentType?
    
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
                        
                        // 昵称（点击编辑，用于最近收支评价等个性化称呼）
                        Button(action: {
                            nameInput = supabaseService.userProfile?.name ?? ""
                            showNameEdit = true
                        }) {
                            HStack(spacing: 8) {
                                Text("昵称")
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textSecondary)
                                Text(nicknameDisplay)
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.brandStart)
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.background)
                            .cornerRadius(8)
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
                        
                        Divider().padding(.horizontal, 16)
                        
                        // 智能体配置
                        Button(action: { showAgentConfig = true }) {
                            HStack {
                                Image(systemName: "cpu")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("智能体配置")
                                        .font(.appBody)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text(agentManager.hasCustomAgent ? agentManager.config?.displayName ?? "已配置" : "未配置，使用默认智能体")
                                        .font(.appSmall)
                                        .foregroundColor(agentManager.hasCustomAgent ? Color(hex: "#10B981") : AppTheme.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
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
                        
                        // 操作记录
                        NavigationLink(destination: UserLogView().environmentObject(supabaseService)) {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 32)
                                Text("操作记录")
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
                        
                        // 隐私政策
                        Button(action: {
                            legalDocumentType = .privacyPolicy
                            showLegalDocument = true
                        }) {
                            HStack {
                                Image(systemName: "hand.raised")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 32)
                                Text("隐私政策")
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
                        
                        // 服务条款
                        Button(action: {
                            legalDocumentType = .termsOfService
                            showLegalDocument = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 32)
                                Text("服务条款")
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
                    
                    Spacer(minLength: 10)
                    
                    // Card: 注销账号
                    VStack(spacing: 0) {
                        Button(action: { showDeleteAccountAlert = true }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.xmark")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "#EF4444"))
                                    .frame(width: 32)
                                Text("注销账号")
                                    .font(.appBody)
                                    .foregroundColor(Color(hex: "#EF4444"))
                                Spacer()
                            }
                            .padding(16)
                        }
                        .disabled(isDeletingAccount)
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .onAppear {
                Task {
                    await userSettings.loadFromCloud()
                    await MainActor.run {
                        ledgerLockEnabled = userSettings.ledgerLockEnabled
                        analyticsLockEnabled = userSettings.analyticsLockEnabled
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
            .overlay {
                if showUnlockMethodSheet {
                    unlockMethodSheetOverlay
                }
            }
            .sheet(isPresented: $showPinSetup) {
                PinSetupView(newPin: $newPin, onConfirm: {
                    if lockSettingTarget == "ledger" {
                        userSettings.ledgerLockEnabled = true
                        userSettings.ledgerLockMode = "pin"
                        userSettings.setLedgerPin(newPin)
                        ledgerLockEnabled = true
                        Task { await userSettings.saveToCloud() }
                    } else {
                        userSettings.analyticsLockEnabled = true
                        userSettings.analyticsLockMode = "pin"
                        userSettings.setAnalyticsPin(newPin)
                        analyticsLockEnabled = true
                        Task { await userSettings.saveToCloud() }
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
                            userSettings.ledgerLockEnabled = true
                            userSettings.ledgerLockMode = "pattern"
                            userSettings.setLedgerPin(pattern)
                            ledgerLockEnabled = true
                            Task { await userSettings.saveToCloud() }
                        } else {
                            userSettings.analyticsLockEnabled = true
                            userSettings.analyticsLockMode = "pattern"
                            userSettings.setAnalyticsPin(pattern)
                            analyticsLockEnabled = true
                            Task { await userSettings.saveToCloud() }
                        }
                    },
                    onCancel: {
                        showPatternSetup = false
                    }
                )
            }
        }
        .sheet(isPresented: $showAgentConfig) {
            AgentConfigSheet()
        }
        .sheet(item: $legalDocumentType) { type in
            NavigationView {
                LegalDocumentView(documentType: type)
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
        .alert("修改昵称", isPresented: $showNameEdit) {
            TextField("昵称", text: $nameInput)
            Button("取消", role: .cancel) { }
            Button("保存") {
                let trimmed = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                Task {
                    try? await supabaseService.updateProfileName(trimmed)
                }
            }
        } message: {
            Text("昵称将用于最近收支评价等个性化称呼")
        }
        .alert("确认切换货币", isPresented: $showCurrencyConfirm) {
            Button("取消", role: .cancel) {
                pendingCurrencyName = ""
            }
            Button("确认") {
                currencySymbol = pendingCurrencyName
                userSettings.currencySymbol = pendingCurrencyName
                Task { await userSettings.saveToCloud() }
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
        .alert("注销账号", isPresented: $showDeleteAccountAlert) {
            Button("取消", role: .cancel) { }
            Button("继续", role: .destructive) {
                showDeleteAccountConfirmAlert = true
            }
        } message: {
            Text("注销账号将删除您的所有记账数据、设置和账号信息，且无法恢复。")
        }
        .alert("确认注销", isPresented: $showDeleteAccountConfirmAlert) {
            Button("取消", role: .cancel) { }
            Button("确认注销", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    do {
                        try await authManager.deleteAccount()
                    } catch {
                        Log.error("注销账号失败: \(error.localizedDescription)")
                    }
                    isDeletingAccount = false
                }
            }
        } message: {
            Text("此操作不可恢复，确定要永久注销账号吗？")
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
                                                userSettings.ledgerLockEnabled = false
                                                userSettings.setLedgerPin(nil)
                                                ledgerLockEnabled = false
                                                Task { await userSettings.saveToCloud() }
                                            } else if lockSettingTarget == "analytics" {
                                                userSettings.analyticsLockEnabled = false
                                                userSettings.setAnalyticsPin(nil)
                                                analyticsLockEnabled = false
                                                Task { await userSettings.saveToCloud() }
                                            } else if lockSettingTarget == "clear_all" {
                                                userSettings.ledgerLockEnabled = false
                                                userSettings.analyticsLockEnabled = false
                                                userSettings.ledgerLockMode = "pin"
                                                userSettings.analyticsLockMode = "pin"
                                                userSettings.setLedgerPin(nil)
                                                userSettings.setAnalyticsPin(nil)
                                                ledgerLockEnabled = false
                                                analyticsLockEnabled = false
                                                Task { await userSettings.saveToCloud() }
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
