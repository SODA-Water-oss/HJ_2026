import SwiftUI

// MARK: - 目标条目数据模型
struct GoalTargetItem: Codable, Identifiable {
    var id = UUID()
    var category: String        // "收入" / "支出"
    var timeDimension: String   // "每周" / "每月" / "每年" / "日期区间"
    var amount: Double
    var startDate: Date?
    var endDate: Date?

    static let timeDimensions = ["每周", "每月", "每年", "日期区间"]

    static func load() -> [GoalTargetItem] {
        guard let data = UserDefaults.standard.data(forKey: "goal_target_items"),
              let value = try? JSONDecoder().decode([GoalTargetItem].self, from: data) else {
            return []
        }
        return value
    }

    static func save(_ items: [GoalTargetItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "goal_target_items")
        }
    }
}

// MARK: - 收支目标整体模块
struct GoalsModuleCard: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var showTargetSetting = false
    @State private var items: [GoalTargetItem] = GoalTargetItem.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.brandGradient)
                Text("收支目标")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button(action: { showTargetSetting = true }) {
                    Label("目标设置", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.brandStart)
                }
            }

            if items.isEmpty {
                Text("暂无目标，点击右上角「目标设置」添加收支目标")
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(items) { item in
                    GoalTargetCard(item: item, records: supabaseService.allRecords)
                }
            }

            // 徽章：按目标达标数量展示
            let achieved = items.filter { achievementPercent($0, records: supabaseService.allRecords) >= 100 }.count
            if achieved > 0 {
                Divider().padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 8) {
                    Text("目标达成徽章")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                    HStack(spacing: 10) {
                        ForEach(0..<min(achieved, 12), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(AppTheme.brandGradient)
                        }
                    }
                    Text("已达成 \(achieved) 个目标")
                        .font(.appTiny)
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .sheet(isPresented: $showTargetSetting) {
            GoalTargetSettingSheet(items: $items)
        }
    }

    /// 目标达成度（0-100+）
    func achievementPercent(_ item: GoalTargetItem, records: [Record]) -> Double {
        guard item.amount > 0 else { return 0 }
        let actual = actualAmount(item, records: records)
        return actual / item.amount * 100
    }

    /// 目标对应时间范围内、对应类别的实际金额
    func actualAmount(_ item: GoalTargetItem, records: [Record]) -> Double {
        guard let range = recordsRange(for: item) else { return 0 }
        let inRange = records.filter { $0.date >= range.start && $0.date <= range.end }
        if item.category == "收入" {
            return inRange.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        } else {
            return inRange.filter(\.isExpense).reduce(0) { $0 + $1.amount }
        }
    }

    func recordsRange(for item: GoalTargetItem) -> (start: Date, end: Date)? {
        let now = Date()
        let cal = Calendar.current
        switch item.timeDimension {
        case "每周":
            return (cal.date(byAdding: .day, value: -7, to: now) ?? now, now)
        case "每月":
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, now)
        case "每年":
            let comps = cal.dateComponents([.year], from: now)
            let start = cal.date(from: comps) ?? now
            return (start, now)
        case "日期区间":
            guard let s = item.startDate, let e = item.endDate, e >= s else { return nil }
            return (s, e)
        default:
            return nil
        }
    }
}

// MARK: - 单条目标达成卡片
struct GoalTargetCard: View {
    let item: GoalTargetItem
    let records: [Record]
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.category == "收入" ? "arrow.up.circle" : "arrow.down.circle")
                    .font(.system(size: 15))
                    .foregroundColor(item.category == "收入" ? .green : AppTheme.textSecondary)
                Text("\(item.category)目标 · \(item.timeDimension)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(String(format: "¥%.0f", item.amount))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            progressBar
            Text(progressText)
                .font(.appTiny)
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(12)
        .background(AppTheme.background)
        .cornerRadius(12)
    }

    private var percent: Double {
        guard item.amount > 0 else { return 0 }
        let actual = actual
        return actual / item.amount * 100
    }

    private var actual: Double {
        // 复用 GoalsModuleCard 的计算逻辑
        let now = Date()
        let cal = Calendar.current
        let range: (start: Date, end: Date)?
        switch item.timeDimension {
        case "每周": range = (cal.date(byAdding: .day, value: -7, to: now) ?? now, now)
        case "每月":
            let comps = cal.dateComponents([.year, .month], from: now)
            range = (cal.date(from: comps) ?? now, now)
        case "每年":
            let comps = cal.dateComponents([.year], from: now)
            range = (cal.date(from: comps) ?? now, now)
        case "日期区间":
            if let s = item.startDate, let e = item.endDate, e >= s { range = (s, e) } else { range = nil }
        default: range = nil
        }
        guard let r = range else { return 0 }
        let inRange = records.filter { $0.date >= r.start && $0.date <= r.end }
        if item.category == "收入" {
            return inRange.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        } else {
            return inRange.filter(\.isExpense).reduce(0) { $0 + $1.amount }
        }
    }

    private var progressText: String {
        let achieved = percent >= 100
        let label = item.category == "收入" ? "收入" : "支出"
        if achieved {
            return "🎉 已完成：\(label) ¥\(Int(actual))，超出目标 \(Int(percent - 100))%"
        } else if actual > 0 {
            return "当前\(label) ¥\(Int(actual))，完成 \(Int(percent))%"
        } else {
            return "本周期暂无\(label)记录，完成 0%"
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(AppTheme.border)
                RoundedRectangle(cornerRadius: 4)
                    .fill(percent >= 100 ? Color.green : AppTheme.brandStart)
                    .frame(width: geo.size.width * min(1, percent / 100))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - 目标设置（空页面 + 增加条目；只可删除不可修改）
struct GoalTargetSettingSheet: View {
    @Binding var items: [GoalTargetItem]
    @Environment(\.dismiss) private var dismiss
    @State private var showAddForm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "target")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.textTertiary)
                        Text("暂无目标")
                            .font(.appBody)
                            .foregroundColor(AppTheme.textSecondary)
                        Text("点击下方「增加目标」添加收支目标")
                            .font(.appSmall)
                            .foregroundColor(AppTheme.textTertiary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(item.category)目标 · \(item.timeDimension)")
                                        .font(.appBody)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text(String(format: "¥%.0f", item.amount))
                                        .font(.appSmall)
                                        .foregroundColor(AppTheme.textSecondary)
                                    if item.timeDimension == "日期区间", let s = item.startDate, let e = item.endDate {
                                        Text("\(s.formatted(date: .abbreviated, time: .omitted)) ~ \(e.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.appTiny)
                                            .foregroundColor(AppTheme.textTertiary)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    items.removeAll { $0.id == item.id }
                                    GoalTargetItem.save(items)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                Text("目标设定后不可修改，只能删除后重新添加")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)

                Button(action: { showAddForm = true }) {
                    Label("增加目标", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .navigationTitle("目标设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(AppTheme.brandStart)
                }
            }
            .sheet(isPresented: $showAddForm) {
                GoalTargetAddSheet(items: $items)
            }
        }
    }
}

// MARK: - 新增目标表单
struct GoalTargetAddSheet: View {
    @Binding var items: [GoalTargetItem]
    @Environment(\.dismiss) private var dismiss
    @State private var category = "支出"
    @State private var timeDimension = "每月"
    @State private var amount = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 24 * 60 * 60)

    var body: some View {
        NavigationStack {
            Form {
                Section("目标类型") {
                    Picker("类型", selection: $category) {
                        Text("支出目标").tag("支出")
                        Text("收入目标").tag("收入")
                    }
                }
                Section("时间维度") {
                    Picker("时间", selection: $timeDimension) {
                        ForEach(GoalTargetItem.timeDimensions, id: \.self) { Text($0).tag($0) }
                    }
                    if timeDimension == "日期区间" {
                        DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                    }
                }
                Section("目标金额") {
                    TextField("金额（元）", text: $amount)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("增加目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let value = Double(amount), value > 0 else { return }
                        let item = GoalTargetItem(
                            id: UUID(),
                            category: category,
                            timeDimension: timeDimension,
                            amount: value,
                            startDate: timeDimension == "日期区间" ? startDate : nil,
                            endDate: timeDimension == "日期区间" ? endDate : nil
                        )
                        items.append(item)
                        GoalTargetItem.save(items)
                        dismiss()
                    }
                    .foregroundColor(AppTheme.brandStart)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }
}
