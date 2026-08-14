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
        VStack(alignment: .leading, spacing: 14) {
            AnalyticsModuleHeader(icon: "target", title: "收支目标") {
                Button(action: { showTargetSetting = true }) {
                    Label("目标设置", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.brandStart)
                }
            }

            // 本周收支（相对周目标）
            periodSummary(
                title: "本周",
                dimension: "每周",
                income: currentPeriodSum(dimension: "每周", category: "收入", records: supabaseService.allRecords),
                expense: currentPeriodSum(dimension: "每周", category: "支出", records: supabaseService.allRecords)
            )

            // 本月收支（相对月目标）
            periodSummary(
                title: "本月",
                dimension: "每月",
                income: currentPeriodSum(dimension: "每月", category: "收入", records: supabaseService.allRecords),
                expense: currentPeriodSum(dimension: "每月", category: "支出", records: supabaseService.allRecords)
            )

            // 其他维度目标条目（每年 / 日期区间）展示
            let otherItems = items.filter { $0.timeDimension != "每周" && $0.timeDimension != "每月" }
            if !otherItems.isEmpty {
                Divider()
                ForEach(otherItems) { item in
                    GoalTargetCard(item: item, records: supabaseService.allRecords)
                }
            }

            // 底部：历史达成徽章（长期显示）
            Divider().padding(.vertical, 2)
            achievementBadges
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .sheet(isPresented: $showTargetSetting) {
            GoalTargetSettingSheet(items: $items)
        }
    }

    // MARK: - 周/月汇总
    private func periodSummary(title: String, dimension: String, income: Double, expense: Double) -> some View {
        let incomeTarget = targetAmount(dimension: dimension, category: "收入")
        let expenseTarget = targetAmount(dimension: dimension, category: "支出")
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            if incomeTarget == 0 && expenseTarget == 0 {
                Text("未设置\(title)目标，点右上角「目标设置」添加")
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textTertiary)
            } else {
                row(label: "收入", current: income, target: incomeTarget, color: .green, currency: CategoryManager.currencySymbol)
                row(label: "支出", current: expense, target: expenseTarget, color: AppTheme.brandEnd, currency: CategoryManager.currencySymbol)
            }
        }
        .padding(12)
        .background(AppTheme.background)
        .cornerRadius(12)
    }

    private func row(label: String, current: Double, target: Double, color: Color, currency: String) -> some View {
        let percent = target > 0 ? current / target * 100 : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.appSmall).foregroundColor(AppTheme.textSecondary)
                Spacer()
                if target > 0 {
                    Text(String(format: "%@%.0f / ¥%.0f（%.0f%%）", currency, current, target, percent))
                        .font(.appSmall)
                        .foregroundColor(percent >= 100 ? Color.green : AppTheme.textPrimary)
                } else {
                    Text(String(format: "%@%.0f", currency, current))
                        .font(.appSmall)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
            if target > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(AppTheme.border)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(percent >= 100 ? Color.green : color)
                            .frame(width: geo.size.width * min(1, percent / 100))
                    }
                }
                .frame(height: 6)
            }
        }
    }

    // MARK: - 历史达成徽章（长期显示）
    private var achievementBadges: some View {
        let weekAchieved = historicalAchievedCount(dimension: "每周")
        let monthAchieved = historicalAchievedCount(dimension: "每月")
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "medal.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.brandGradient)
                Text("目标达成徽章")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            HStack(spacing: 14) {
                badgeGroup(title: "周达成", count: weekAchieved, icon: "crown.fill", color: AppTheme.brandEnd)
                badgeGroup(title: "月达成", count: monthAchieved, icon: "crown.fill", color: Color(hex: "#EAB308"))
            }
            Text("达成 1 个周期目标获得 1 枚徽章")
                .font(.appTiny)
                .foregroundColor(AppTheme.textTertiary)
        }
    }

    private func badgeGroup(title: String, count: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.appSmall).foregroundColor(AppTheme.textSecondary)
            HStack(spacing: 6) {
                ForEach(0..<min(max(count, 0), 10), id: \.self) { _ in
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(color)
                }
                if count > 10 {
                    Text("+\\(count - 10)")
                        .font(.appSmall)
                        .foregroundColor(AppTheme.textSecondary)
                }
                if count == 0 {
                    Text("--")
                        .font(.appSmall)
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
        }
    }

    // MARK: - 计算
    private func targetAmount(dimension: String, category: String) -> Double {
        items.first { $0.timeDimension == dimension && $0.category == category }?.amount ?? 0
    }

    /// 当前周期（本周/本月）某类别的收支合计
    func currentPeriodSum(dimension: String, category: String, records: [Record]) -> Double {
        let now = Date()
        let cal = Calendar.current
        let start: Date
        switch dimension {
        case "每周":
            var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            comps.weekday = 2
            start = cal.date(from: comps) ?? now
        case "每月":
            let comps = cal.dateComponents([.year, .month], from: now)
            start = cal.date(from: comps) ?? now
        default:
            start = now
        }
        let inRange = records.filter { $0.date >= start && $0.date <= now }
        if category == "收入" {
            return inRange.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        }
        return inRange.filter(\.isExpense).reduce(0) { $0 + $1.amount }
    }

    /// 历史达成数量（过去 52 周 / 24 个月，对应目标达标次数）
    func historicalAchievedCount(dimension: String) -> Int {
        let records = supabaseService.allRecords
        let cal = Calendar.current
        let now = Date()
        var count = 0

        if dimension == "每周" {
            let incomeTarget = targetAmount(dimension: "每周", category: "收入")
            let expenseTarget = targetAmount(dimension: "每周", category: "支出")
            guard incomeTarget > 0 || expenseTarget > 0 else { return 0 }
            for i in 0..<52 {
                let end = cal.date(byAdding: .day, value: -7 * i, to: now) ?? now
                let start = cal.date(byAdding: .day, value: -7, to: end) ?? end
                let recs = records.filter { $0.date >= start && $0.date < end }
                let income = recs.filter(\.isIncome).reduce(0) { $0 + $1.amount }
                let expense = recs.filter(\.isExpense).reduce(0) { $0 + $1.amount }
                let incomeOK = incomeTarget == 0 || income >= incomeTarget
                let expenseOK = expenseTarget == 0 || expense <= expenseTarget
                if incomeOK && expenseOK { count += 1 }
            }
        } else if dimension == "每月" {
            let incomeTarget = targetAmount(dimension: "每月", category: "收入")
            let expenseTarget = targetAmount(dimension: "每月", category: "支出")
            guard incomeTarget > 0 || expenseTarget > 0 else { return 0 }
            for i in 0..<24 {
                let end = cal.date(byAdding: .month, value: -i, to: now) ?? now
                let start = cal.date(byAdding: .month, value: -1, to: end) ?? end
                let recs = records.filter { $0.date >= start && $0.date < end }
                let income = recs.filter(\.isIncome).reduce(0) { $0 + $1.amount }
                let expense = recs.filter(\.isExpense).reduce(0) { $0 + $1.amount }
                let incomeOK = incomeTarget == 0 || income >= incomeTarget
                let expenseOK = expenseTarget == 0 || expense <= expenseTarget
                if incomeOK && expenseOK { count += 1 }
            }
        }
        return count
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
    @State private var pendingDelete: GoalTargetItem?

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
                                    pendingDelete = item
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
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
            .background(Color.white)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(AppTheme.brandStart)
                }
            }
            .sheet(isPresented: $showAddForm) {
                GoalTargetAddSheet(items: $items)
            }
            .alert("确认删除", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("取消", role: .cancel) { pendingDelete = nil }
                Button("删除", role: .destructive) {
                    if let target = pendingDelete {
                        items.removeAll { $0.id == target.id }
                        GoalTargetItem.save(items)
                    }
                    pendingDelete = nil
                }
            } message: {
                if let target = pendingDelete {
                    Text("确定删除「\(target.category)目标 · \(target.timeDimension)」吗？删除后不可恢复。")
                } else {
                    Text("确定删除该目标吗？")
                }
            }
        }
        .preferredColorScheme(.light)
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
            .scrollContentBackground(.hidden)
            .navigationTitle("增加目标")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.white)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .cornerRadius(6)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .cornerRadius(6)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}
