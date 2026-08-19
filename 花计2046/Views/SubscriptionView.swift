import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Color.clear.frame(height: 4)
                    
                    // 标题区
                    VStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.brandStart)
                        
                        Text("关于花计2046")
                            .font(.appLargeTitle)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("v1.0")
                            .font(.appBody)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    
                    // 功能介绍
                    VStack(alignment: .leading, spacing: 16) {
                        Text("功能特点")
                            .font(.appTitle)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        FeatureRow(icon: "mic.fill", text: "语音录入 — 按住说话，自动转文字")
                        FeatureRow(icon: "text.magnifyingglass", text: "AI 解析 — 智能识别消费内容")
                        FeatureRow(icon: "doc.text.magnifyingglass", text: "CSV 导出 — 数据随时备份")
                        FeatureRow(icon: "chart.pie.fill", text: "数据分析 — 可视化消费习惯")
                        
                        Divider()
                        
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(AppTheme.brandStart)
                                .font(.system(size: 16))
                            if AgentConfigManager.cachedHasCustomAgent {
                                Text("已配置自己的智能体，AI 解析不限次数")
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textSecondary)
                            } else {
                                Text("每日免费解析 \(DailyLimitManager.dailyLimit) 次")
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 32)
                }
            }
            .background(AppTheme.background)
            .navigationTitle("帮助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("帮助")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.brandStart)
                .font(.system(size: 16))
                .frame(width: 24)
            Text(text)
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}
