import SwiftUI

/// 月度收支目标数据（本地存储）
struct GoalTargets: Codable {
    var monthlyIncomeTarget: Double = 0
    var monthlyExpenseTarget: Double = 0

    static func load() -> GoalTargets {
        guard let data = UserDefaults.standard.data(forKey: "goal_targets"),
              let value = try? JSONDecoder().decode(GoalTargets.self, from: data) else {
            return GoalTargets()
        }
        return value
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "goal_targets")
        }
    }
}

/// 目标整体模块：收入目标 + 支出目标 + 冲刺目标（储蓄）
struct GoalsModuleCard: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @ObservedObject var manager: AchievementManager
    @State private var showTargetSetting = false
    @State private var showGoalManagement = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.brandGradient)
                Text("目标")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button(action: { showTargetSetting = true }) {
                    Label("目标设置", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.brandStart)
                }
            }

            let targets = GoalTargets.load()

            // 收入目标
            targetRow(
                title: "收入目标",
                current: currentMonthIncome,
                target: targets.monthlyIncomeTarget,
                color: .green,
                emptyHint: "设置本月收入目标"
            )

            // 支出目标
            targetRow(
                title: "支出目标",
                current: currentMonthExpense,
                target: targets.monthlyExpenseTarget,
                color: AppTheme.brandStart,
                emptyHint: "设置本月支出目标",
                isExpense: true
            )

            // 冲刺目标（储蓄）
            Divider().padding(.vertical, 2)
            HStack {
                Text("冲刺目标").font(.system(size: 13)).foregroundColor(AppTheme.textSecondary)
                Spacer()
                Button("管理") { showGoalManagement = true }
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.brandStart)
            }
            if let progress = manager.snapshot?.currentGoalProgress {
                VStack(alignment: .leading, spacing: 6) {
                    Text(progress.goal.name)
                        .font(.appBody)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(AppTheme.border)
                            RoundedRectangle(cornerRadius: 4).fill(Color.green).frame(width: geo.size.width * min(1, progress.percent / 100))
                        }
                    }
                    .frame(height: 8)
                    Text(String(format: "%.0f%% 已存 ¥%.0f", progress.percent, progress.savedAmount))
                        .font(.appTiny)
                        .foregroundColor(AppTheme.textSecondary)
                }
            } else {
                Text("设第一个目标")
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .sheet(isPresented: $showTargetSetting) {
            GoalTargetSheet()
        }
        .sheet(isPresented: $showGoalManagement) {
            GoalManagementSheet(manager: manager)
        }
    }

    private var currentMonthIncome: Double {
        let month = currentMonthKey
        return supabaseService.allRecords
            .filter { $0.isIncome && $0.month == month }
            .reduce(0) { $0 + $1.amount }
    }

    private var currentMonthExpense: Double {
        let month = currentMonthKey
        return supabaseService.allRecords
            .filter { $0.isExpense && $0.month == month }
            .reduce(0) { $0 + $1.amount }
    }

    private var currentMonthKey: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df.string(from: Date())
    }

    private func targetRow(
        title: String,
        current: Double,
        target: Double,
        color: Color,
        emptyHint: String,
        isExpense: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 13)).foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text(display(current, target: target, isExpense: isExpense))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(overTarget(current, target: target, isExpense: isExpense) ? Color(hex: "#EF4444") : AppTheme.textPrimary)
            }
            if target > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(AppTheme.border)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(overTarget(current, target: target, isExpense: isExpense) ? Color(hex: "#EF4444") : color)
                            .frame(width: geo.size.width * min(1, ratio(current, target: target)))
                    }
                }
                .frame(height: 6)
            } else {
                Button(action: { showTargetSetting = true }) {
                    Text(emptyHint)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
        }
    }

    private func ratio(_ current: Double, target: Double) -> Double {
        target > 0 ? current / target : 0
    }

    private func overTarget(_ current: Double, target: Double, isExpense: Bool) -> Bool {
        // 支出超目标变红；收入低于目标也提示（但不红，用正常色）
        isExpense ? (target > 0 && current > target) : false
    }

    private func display(_ current: Double, target: Double, isExpense: Bool) -> String {
        if target > 0 {
            return String(format: "¥%.0f / ¥%.0f", current, target)
        }
        return String(format: "本月 ¥%.0f", current)
    }
}

/// 目标设置：录入收入目标、支出目标
struct GoalTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var incomeTarget = ""
    @State private var expenseTarget = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("每月收入目标（元）", text: $incomeTarget)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("收入目标")
                } footer: {
                    Text("当月收入达到该金额即视为达标")
                }

                Section {
                    TextField("每月支出目标（元）", text: $expenseTarget)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("支出目标")
                } footer: {
                    Text("当月支出超出该金额会红色提醒")
                }
            }
            .navigationTitle("目标设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(AppTheme.brandStart)
                }
            }
            .onAppear {
                let targets = GoalTargets.load()
                if targets.monthlyIncomeTarget > 0 { incomeTarget = String(format: "%.0f", targets.monthlyIncomeTarget) }
                if targets.monthlyExpenseTarget > 0 { expenseTarget = String(format: "%.0f", targets.monthlyExpenseTarget) }
            }
        }
    }

    private func save() {
        var targets = GoalTargets.load()
        targets.monthlyIncomeTarget = Double(incomeTarget) ?? 0
        targets.monthlyExpenseTarget = Double(expenseTarget) ?? 0
        targets.save()
    }
}
