import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var selectedTab = 2
   
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
                    Label("升级", systemImage: "star.fill")
                }
            
            ProfileView().tag(4)
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(AppTheme.brandStart)
        .task {
            // 后台异步预加载账本和分析数据
            try? await supabaseService.preloadAllRecords()
        }
        if supabaseService.isGloballyProcessing {
            globalProcessingOverlay
        }
        }
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
    @State private var showLogs = false
    @State private var logContent = ""
    @State private var showLogoutAlert = false
    
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
                            Text(supabaseService.userProfile?.isPremium == true ? "高级版已激活" : "标准版用户")
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
                    
                    if showLogs {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("系统日志")
                                    .font(.appTitle)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Button(action: {
                                    try? "".write(to: Log.logFile, atomically: true, encoding: .utf8)
                                    logContent = ""
                                    Log.info("日志已清除")
                                }) {
                                    Text("清除").font(.appSmall).foregroundColor(.red)
                                }
                            }
                            
                            ScrollView {
                                Text(logContent.isEmpty ? "暂无日志" : logContent)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                            }
                            .frame(maxHeight: 300)
                            .background(AppTheme.rowHighlight)
                            .cornerRadius(8)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer(minLength: 24)
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            showLogs.toggle()
                            if showLogs { logContent = Log.readLogFile() }
                        }) {
                            Text(showLogs ? "隐藏日志" : "查看日志")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            Text("退出登录")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .alert("退出登录", isPresented: $showLogoutAlert) {
                            Button("取消", role: .cancel) { }
                            Button("确认退出", role: .destructive) {
                                authManager.signOut()
                            }
                        } message: {
                            Text("是否确定退出当前登录？")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(AppTheme.background)
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
        }
    }
}
