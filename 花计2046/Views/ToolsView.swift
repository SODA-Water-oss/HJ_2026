import SwiftUI

struct ToolsView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 4)
                    
                    // MARK: - 待开发工具列表
                    toolCard(
                        icon: "dollarsign.circle",
                        title: "利息计算器",
                        desc: "计算贷款利息、存款利息、年化收益率",
                        status: "即将上线"
                    )
                    
                    toolCard(
                        icon: "arrow.left.arrow.right",
                        title: "汇率换算",
                        desc: "多币种实时汇率换算，出差旅行好帮手",
                        status: "即将上线"
                    )
                    
                    toolCard(
                        icon: "person.2",
                        title: "AA分账",
                        desc: "聚餐、旅行多人均摊，自动算出每人应付",
                        status: "即将上线"
                    )
                    
                    toolCard(
                        icon: "chart.pie",
                        title: "支出占比分析",
                        desc: "按类别查看各月支出分布与趋势",
                        status: "即将上线"
                    )
                    
                    toolCard(
                        icon: "percent",
                        title: "折扣计算器",
                        desc: "输入原价和折扣，自动算出折后价和节省金额",
                        status: "即将上线"
                    )
                    
                    toolCard(
                        icon: "calendar.badge.clock",
                        title: "定期账单提醒",
                        desc: "房租、会员费、月供到期提醒，不再忘缴",
                        status: "即将上线"
                    )
                    
                    Spacer(minLength: 32)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("工具")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
        }
    }
    
    private func toolCard(icon: String, title: String, desc: String, status: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppTheme.brandStart)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Text(desc)
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(status)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.background)
                .cornerRadius(6)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
}
