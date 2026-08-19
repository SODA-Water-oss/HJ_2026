import SwiftUI

struct UserLogView: View {
    @StateObject private var logManager = UserLogManager.shared
    @EnvironmentObject var supabaseService: SupabaseService
    
    var body: some View {

            List {
                ForEach(logManager.logs) { log in
                    LogRowView(log: log)
                }
            }
            .listStyle(.plain)
            .background(AppTheme.background)
            .overlay {
                if logManager.isLoading && logManager.logs.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if logManager.logs.isEmpty {
                    VStack(spacing: 20) {
                        Spacer(minLength: 140)
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#E5E7EB"))
                                .frame(width: 100, height: 100)
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "#9CA3AF"))
                        }
                        Text("暂无记录")
                            .font(.appTitle)
                            .foregroundColor(Color(hex: "#9CA3AF"))
                        Text("操作后会自动记录")
                            .font(.appSmall)
                            .foregroundColor(Color(hex: "#9CA3AF").opacity(0.6))
                        Spacer(minLength: 132)
                    }
                } else if logManager.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding(.top, 20)
                        Spacer()
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
                        Text("操作记录")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
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
    
    private var countText: String? {
        guard let open = log.detail.lastIndex(of: "("),
              let close = log.detail.lastIndex(of: ")"),
              close > open else { return nil }
        let candidate = log.detail[log.detail.index(after: open)..<close]
        guard !candidate.isEmpty, candidate.allSatisfy(\.isNumber) else { return nil }
        return String(candidate)
    }

    private var strippedText: String {
        guard let open = log.detail.lastIndex(of: "("),
              let close = log.detail.lastIndex(of: ")"),
              close > open else { return log.detail }
        let candidate = log.detail[log.detail.index(after: open)..<close]
        guard !candidate.isEmpty, candidate.allSatisfy(\.isNumber) else { return log.detail }
        return String(log.detail[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayText: String {
        let a = log.action
        let d = strippedText
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
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayText)
                    .font(.appBody)
                    .foregroundColor(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(formatDate(log.createdAt))
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textTertiary)
            }
            Spacer()
            if let countText {
                Text(countText)
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.white)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
