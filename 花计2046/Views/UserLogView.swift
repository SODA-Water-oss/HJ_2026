import SwiftUI

struct UserLogView: View {
    @StateObject private var logManager = UserLogManager.shared
    @EnvironmentObject var supabaseService: SupabaseService
    
    var body: some View {
        NavigationView {
            List {
                ForEach(logManager.logs) { log in
                    LogRowView(log: log)
                }
            }
            .listStyle(.plain)
            .background(AppTheme.background)
            .overlay {
                if logManager.logs.isEmpty && !logManager.isLoading {
                    VStack(spacing: 20) {
                        Spacer(minLength: 140)
                        ZStack {
                            Circle().fill(AppTheme.brandStart.opacity(0.06)).frame(width: 120, height: 120)
                            Circle().fill(AppTheme.brandEnd.opacity(0.04)).frame(width: 90, height: 90)
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 36, weight: .ultraLight))
                                .foregroundColor(Color(hex: "#C0C0C0").opacity(0.5))
                        }
                        Text("暂无操作日志")
                            .font(.appTitle)
                            .foregroundColor(Color(hex: "#C0C0C0"))
                        Text("操作后会自动记录")
                            .font(.appSmall)
                            .foregroundColor(Color(hex: "#C0C0C0").opacity(0.6))
                        Spacer(minLength: 132)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("操作日志")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
        }
        .task {
            await logManager.fetchLogs(supabaseService: supabaseService)
        }
    }
}

// MARK: - 单条日志行
private struct LogRowView: View {
    let log: UserLog
    
    private var displayText: String {
        let a = log.action
        let d = log.detail
        if d.hasPrefix(a) { return d }
        if a == "登录" { return "登录账号" }
        if a == "登出" { return "退出登录" }
        return d.isEmpty ? a : d
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 17))
                .foregroundColor(AppTheme.brandStart)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayText)
                    .font(.appBody)
                    .foregroundColor(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(formatDate(log.createdAt))
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textTertiary)
            }
            
        }
        .padding(.vertical, 10)
        .listRowBackground(Color.white)
        .listRowSeparator(.hidden)
    }
    
    private var iconName: String {
        let a = log.action
        if a.contains("进账") || a.contains("解析") { return "checkmark.circle" }
        if a.contains("编辑") { return "square.and.pencil" }
        if a.contains("删除") || a.contains("批量") { return "trash" }
        if a.contains("导出") { return "square.and.arrow.up" }
        if a.contains("登录") || a.contains("登出") { return "person.circle" }
        return "circle"
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df.string(from: date)
    }
}
