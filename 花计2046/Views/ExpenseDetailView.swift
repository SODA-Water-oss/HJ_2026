import SwiftUI

struct ExpenseDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var supabaseService: SupabaseService
    let expense: Expense
    @State private var isDeleting = false
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var currentExpense: Expense
    
    init(expense: Expense) {
        self.expense = expense
        _currentExpense = State(initialValue: expense)
    }
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("记录金额")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.textSecondary)
                    HStack(spacing: 4) {
                        Text(currentExpense.isExpense ? "支" : "收")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(currentExpense.isExpense ? AppTheme.brandStart : .green)
                            .clipShape(Circle())
                        Text(currentExpense.isExpense ? "支出" : "收入")
                            .font(.system(size: 17))
                            .foregroundColor(currentExpense.isExpense ? AppTheme.brandStart : .green)
                    }
                    Text(currentExpense.isIncome ? String(format: "+¥%.2f", currentExpense.amount) : String(format: "-¥%.2f", currentExpense.amount))
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(currentExpense.isIncome ? .green : AppTheme.textSecondary)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 20) {
                    DetailRow(label: "类别", value: currentExpense.category)
                    AppDivider()
                    DetailRow(label: "名称", value: currentExpense.merchant)
                    AppDivider()
                    DetailRow(label: "日期", value: "\(dateFormatted(currentExpense.date)) \(chineseWeekday(currentExpense.date))")
                    AppDivider()
                    DetailRow(label: "时间", value: timeFormatted(currentExpense.date))
                    AppDivider()
                    HStack(alignment: .top) {
                        Text("备注")
                            .font(.system(size: 17))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 60, alignment: .leading)
                        Text(currentExpense.note ?? "-")
                            .font(.system(size: 17))
                            .lineLimit(nil)
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: { showEditSheet = true }) {
                        Text("编辑记录")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    
                   Button(action: { showDeleteAlert = true }) {
                       Text(isDeleting ? "删除中..." : "删除记录")
                           .frame(maxWidth: .infinity)
                   }
                   .buttonStyle(AppSecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("记录详情")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("记录详情")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("确认删除", role: .destructive) { deleteRecord() }
        } message: {
            Text("是否确认删除该项内容？")
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationView {
                EditExpenseView(expense: currentExpense) {
                    // Sync from cache first (optimistic update already ran)
                    if let updated = supabaseService.allRecords.first(where: { $0.id == currentExpense.id }) { currentExpense = updated }
                    // Then refresh from server in background
                    Task { await refreshExpense() }
                }
                .environmentObject(supabaseService)
            }
        }
    }
    
    func dateFormatted(_ d: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; return df.string(from: d)
    }
    func timeFormatted(_ d: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        return df.string(from: d)
    }
    
    func deleteRecord() {
        isDeleting = true
        Task {
            do {
                try await supabaseService.deleteExpense(currentExpense)
                await MainActor.run {
                    NotificationCenter.default.post(name: Notification.Name("ExpensesDidUpdate"), object: nil)
                    dismiss()
                }
            } catch { await MainActor.run { isDeleting = false } }
        }
    }
    
    func refreshExpense() async {
        do {
            let expenses = try await supabaseService.fetchExpenses()
            if let updated = expenses.first(where: { $0.id == currentExpense.id }) {
                await MainActor.run { currentExpense = updated }
            }
        } catch {
            print("Failed to refresh expense: \(error)")
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 17))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 17))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
        }
    }
}
