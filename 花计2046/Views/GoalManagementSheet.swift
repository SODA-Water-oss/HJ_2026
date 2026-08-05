import SwiftUI

struct GoalManagementSheet: View {
    @ObservedObject var manager: AchievementManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var target = ""
    @State private var starting = ""
    @State private var deadline = Date().addingTimeInterval(60 * 60 * 24 * 365)

    var body: some View {
        NavigationStack {
            Form {
                Section("当前目标") {
                    ForEach(manager.snapshot?.goals ?? []) { goal in
                        HStack {
                            Image(systemName: goal.isActive ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(goal.isActive ? AppTheme.brandStart : AppTheme.textTertiary)
                            VStack(alignment: .leading) {
                                Text(goal.name).font(.appBody).foregroundColor(AppTheme.textPrimary)
                                Text(String(format: "¥%.0f / ¥%.0f", goal.startingAmount, goal.targetAmount))
                                    .font(.appTiny).foregroundColor(AppTheme.textSecondary)
                            }
                            Spacer()
                            Button("冲刺") { manager.setActiveGoal(id: goal.id) }
                                .font(.appSmall)
                                .disabled(goal.isActive)
                            Button(role: .destructive) { manager.deleteGoal(id: goal.id) } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
                Section("新增目标") {
                    TextField("名称", text: $name)
                    TextField("目标金额", text: $target).keyboardType(.decimalPad)
                    TextField("已有积蓄", text: $starting).keyboardType(.decimalPad)
                    DatePicker("截止日期", selection: $deadline, displayedComponents: .date)
                    Button("添加") {
                        let targetValue = Double(target) ?? 0
                        guard !name.isEmpty, targetValue > 0 else { return }
                        manager.addGoal(name: name, targetAmount: targetValue, startingAmount: Double(starting) ?? 0, deadline: deadline)
                        name = ""
                        target = ""
                        starting = ""
                    }
                }
                Section("月度预算") {
                    TextField(
                        "预算金额（留空自动参考近 90 天均值）",
                        value: Binding(
                            get: { manager.snapshot?.budget.monthlyBudget ?? 0 },
                            set: { manager.setMonthlyBudget($0 > 0 ? $0 : nil) }
                        ),
                        format: .number
                    )
                    .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("财务目标")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
