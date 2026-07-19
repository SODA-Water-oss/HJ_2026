import SwiftUI
#if !DEBUG
import StripePaymentSheet
#endif

@main
struct __2046App: App {
    @StateObject var authManager = AuthManager.shared
    @StateObject var supabaseService = SupabaseService.shared
    
	init() {
	#if !DEBUG
       StripeAPI.defaultPublishableKey = AppConfig.stripePublishableKey
       #endif
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.white
        appearance.shadowColor = UIColor(AppTheme.divider)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.textPrimary),
            .font: UIFont.systemFont(ofSize: 34, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.brandStart)
        
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        tabAppearance.backgroundColor = UIColor.white
        tabAppearance.shadowColor = UIColor(AppTheme.divider)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBarItem.appearance().badgeColor = UIColor(AppTheme.brandEnd)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.authState {
                case .checking:
                    // 启动加载画面
                    ZStack {
                        AppTheme.brandGradient.ignoresSafeArea()
                        VStack(spacing: 12) {
                            Text("加载中...")
                                .font(.appBodyMedium)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                case .unauthenticated, .error:
                    AuthView()
                        .environmentObject(authManager)
                        .environmentObject(supabaseService)
                    
                case .authenticated:
                    MainTabView()
                        .environmentObject(authManager)
                        .environmentObject(supabaseService)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        }
    }
}
