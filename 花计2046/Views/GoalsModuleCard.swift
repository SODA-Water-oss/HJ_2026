import SwiftUI

// MARK: - 目标条目数据模型
struct GoalTargetItem: Codable, Identifiable {
    var id = UUID()
    var name: String = ""       // 目标名称（目标设置时输入）
    var category: String        // "收入" / "支出"
    var timeDimension: String   // "每周" / "每月" / "每年" / "日期区间"
    var amount: Double
    var startDate: Date?
    var endDate: Date?
    var createdAt: Date?    // 目标创建时间（判定上一周期是否可算，旧数据为 nil 视为可判定）

    /// 展示用名称（旧数据无名称时回退为「收入目标/支出目标」）
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(category)目标" : trimmed
    }

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

            // 其他维度目标条目（日期区间）展示；每年目标进入下方徽章区
            let otherItems = items.filter { $0.timeDimension == "日期区间" }
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
        // 只展示「上一周期开始时目标已存在」的目标；刚设置的目标不判定，避免误显示未达成
        let badgeItems = items.filter {
            ($0.timeDimension == "每周" || $0.timeDimension == "每月" || $0.timeDimension == "每年") && badgeEligible($0)
        }
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
            if badgeItems.isEmpty {
                if items.isEmpty {
                    Text("设置目标并达成即可获得对应徽章")
                        .font(.appTiny)
                        .foregroundColor(AppTheme.textTertiary)
                } else {
                    Text("目标刚设置，从下一个完整周期起判定达成情况")
                        .font(.appTiny)
                        .foregroundColor(AppTheme.textTertiary)
                }
            } else {
                ForEach(badgeItems) { item in
                    badgeRow(
                        name: item.displayName,
                        title: badgeTitle(for: item),
                        achieved: achievedLastPeriod(for: item),
                        totalCount: achievedCountTotal(for: item),
                        isWeekly: item.timeDimension == "每周"
                    )
                }
            }
        }
    }

    private func badgeTitle(for item: GoalTargetItem) -> String {
        switch item.timeDimension {
        case "每周": return "上周达成"
        case "每月": return "上月达成"
        case "每年": return "上年达成"
        default: return "达成"
        }
    }

    /// 单条目标徽章行：目标名称 + 周/月/年达成 + 上一周期徽章（未达成不显示）+ 历史累计次数文字
    private func badgeRow(name: String, title: String, achieved: Bool, totalCount: Int, isWeekly: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(title)
                    .font(.appTiny)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(width: 88, alignment: .leading)
            Spacer(minLength: 8)
            if achieved {
                if isWeekly { WeeklyBadgeView() } else { MonthlyBadgeView() }
            }
            if totalCount > 0 {
                Text("累计 \(totalCount) 次")
                    .font(.appTiny)
                    .foregroundColor(AppTheme.textTertiary)
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

    /// 某个目标在历史周期中达成的次数（按目标名称一一匹配；周=52 周、月=24 个月、年=5 年、日期区间=1 次）
    /// 上一完整周期范围（周/月/年）
    private func previousPeriodRange(for item: GoalTargetItem) -> (start: Date, end: Date)? {
        let cal = Calendar.current
        let now = Date()
        switch item.timeDimension {
        case "每周":
            let thisWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let start = cal.date(byAdding: .day, value: -7, to: thisWeekStart) ?? thisWeekStart
            return (start, thisWeekStart)
        case "每月":
            let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            let start = cal.date(byAdding: .month, value: -1, to: thisMonthStart) ?? thisMonthStart
            return (start, thisMonthStart)
        case "每年":
            let thisYearStart = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
            let start = cal.date(byAdding: .year, value: -1, to: thisYearStart) ?? thisYearStart
            return (start, thisYearStart)
        default:
            return nil
        }
    }

    /// 目标是否可判定上一周期：目标创建时间不晚于上一周期开始才算（旧数据 createdAt 为 nil 视为可判定）
    private func badgeEligible(_ item: GoalTargetItem) -> Bool {
        guard let createdAt = item.createdAt, let range = previousPeriodRange(for: item) else { return true }
        return createdAt <= range.start
    }

    /// 上一完整周期是否达成（上周/上月/上年），未达成不显示徽章
    private func achievedLastPeriod(for item: GoalTargetItem) -> Bool {
        let records = supabaseService.allRecords
        guard let range = previousPeriodRange(for: item) else { return false }
        return achieved(records: records, start: range.start, end: range.end, item: item)
    }

    /// 历史累计达成次数（周=52、月=24、年=5），以文字保留成绩
    private func achievedCountTotal(for item: GoalTargetItem) -> Int {
        let records = supabaseService.allRecords
        let cal = Calendar.current
        let now = Date()
        var count = 0
        switch item.timeDimension {
        case "每周":
            for i in 0..<52 {
                let end = cal.date(byAdding: .day, value: -7 * i, to: now) ?? now
                let start = cal.date(byAdding: .day, value: -7, to: end) ?? end
                if achieved(records: records, start: start, end: end, item: item) { count += 1 }
            }
        case "每月":
            for i in 0..<24 {
                let end = cal.date(byAdding: .month, value: -i, to: now) ?? now
                let start = cal.date(byAdding: .month, value: -1, to: end) ?? end
                if achieved(records: records, start: start, end: end, item: item) { count += 1 }
            }
        case "每年":
            for i in 0..<5 {
                let end = cal.date(byAdding: .year, value: -i, to: now) ?? now
                let start = cal.date(byAdding: .year, value: -1, to: end) ?? end
                if achieved(records: records, start: start, end: end, item: item) { count += 1 }
            }
        default:
            break
        }
        return count
    }

    private func achieved(records: [Record], start: Date, end: Date, item: GoalTargetItem) -> Bool {
        guard item.amount > 0 else { return false }
        let recs = records.filter { $0.date >= start && $0.date < end }
        let actual: Double
        if item.category == "收入" {
            actual = recs.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        } else {
            actual = recs.filter(\.isExpense).reduce(0) { $0 + $1.amount }
        }
        return actual >= item.amount
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
                Text("\(item.displayName) · \(item.timeDimension)")
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
            if achievedCount > 0 {
                Text("累计达成 \(achievedCount) 次")
                    .font(.appTiny)
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(12)
        .background(AppTheme.background)
        .cornerRadius(12)
    }

    /// 历史累计达成次数（每年=近5年、日期区间=1次），以文字保留成绩
    private var achievedCount: Int {
        let cal = Calendar.current
        let now = Date()
        var count = 0
        switch item.timeDimension {
        case "每年":
            for i in 0..<5 {
                let end = cal.date(byAdding: .year, value: -i, to: now) ?? now
                let start = cal.date(byAdding: .year, value: -1, to: end) ?? end
                if achieved(start: start, end: end) { count += 1 }
            }
        case "日期区间":
            if let s = item.startDate, let e = item.endDate, e >= s, achieved(start: s, end: e) { count = 1 }
        default:
            break
        }
        return count
    }

    private func achieved(start: Date, end: Date) -> Bool {
        guard item.amount > 0 else { return false }
        let recs = records.filter { $0.date >= start && $0.date < end }
        let actual: Double
        if item.category == "收入" {
            actual = recs.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        } else {
            actual = recs.filter(\.isExpense).reduce(0) { $0 + $1.amount }
        }
        return actual >= item.amount
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
                                    Text("\(item.displayName) · \(item.timeDimension)")
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
                    Text("确定删除「\(target.displayName)」吗？删除后不可恢复。")
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
    @State private var name = ""
    @State private var category = "支出"
    @State private var timeDimension = "每月"
    @State private var amount = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("目标名称") {
                    TextField("如：每月存5000", text: $name)
                }
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
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else {
                            validationMessage = "请填写目标名称"
                            showValidationAlert = true
                            return
                        }
                        guard let value = Double(amount), value > 0 else {
                            validationMessage = "请填写有效的目标金额"
                            showValidationAlert = true
                            return
                        }
                        let item = GoalTargetItem(
                            id: UUID(),
                            name: trimmedName,
                            category: category,
                            timeDimension: timeDimension,
                            amount: value,
                            startDate: timeDimension == "日期区间" ? startDate : nil,
                            endDate: timeDimension == "日期区间" ? endDate : nil,
                            createdAt: Date()
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
        .alert("提示", isPresented: $showValidationAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .preferredColorScheme(.light)
    }
}

/// 周达成徽章（华丽，缩小版）：渐变圆底 + 紫色皇冠 + 四角星点缀 + 光晕
struct WeeklyBadgeView: View {
    private var color: Color { AppTheme.brandEnd }

    var body: some View {
        ZStack {
            // 外圈光晕
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 38, height: 38)

            // 渐变圆底
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.38), color.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)

            // 渐变圆环
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white, color, color.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .frame(width: 32, height: 32)

            // 皇冠
            Image(systemName: "crown.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [color, Color(hex: "#A855F7").opacity(0.7)], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: color.opacity(0.6), radius: 2, x: 0, y: 1)

            // 四角星点缀
            sparkle(offset: CGSize(width: -15, height: -15), size: 4)
            sparkle(offset: CGSize(width: 15, height: -13), size: 3)
            sparkle(offset: CGSize(width: -16, height: 13), size: 3)
            sparkle(offset: CGSize(width: 16, height: 15), size: 4)
        }
        .frame(width: 38, height: 38)
    }

    private func sparkle(offset: CGSize, size: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundColor(color.opacity(0.85))
            .offset(offset)
    }
}

/// 月达成徽章（更加华丽）：放射光线 + 双圆环 + 金色皇冠 + 多星点缀
struct MonthlyBadgeView: View {
    private var color: Color { Color(hex: "#EAB308") }

    var body: some View {
        ZStack {
            // 大光晕
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 44, height: 44)

            // 放射光线（8 条）
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.9), color.opacity(0.0)],
                            startPoint: .center,
                            endPoint: .top
                        )
                    )
                    .frame(width: 2.6, height: 17)
                    .offset(y: -17)
                    .rotationEffect(.degrees(Double(i) * 45))
            }

            // 渐变圆底
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.42), Color(hex: "#FDE68A").opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)

            // 双圆环
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white, color, color.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.8
                )
                .frame(width: 36, height: 36)
            Circle()
                .stroke(color.opacity(0.45), lineWidth: 1)
                .frame(width: 28, height: 28)

            // 金色皇冠
            Image(systemName: "crown.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#FBBF24"), Color(hex: "#B45309")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: color.opacity(0.7), radius: 3, x: 0, y: 2)

            // 多点 sparkle 点缀
            sparkle(offset: CGSize(width: -18, height: -18), size: 4)
            sparkle(offset: CGSize(width: 18, height: -16), size: 4)
            sparkle(offset: CGSize(width: -19, height: 16), size: 4)
            sparkle(offset: CGSize(width: 19, height: 18), size: 4)
            sparkle(offset: CGSize(width: 0, height: -22), size: 3)
            sparkle(offset: CGSize(width: 0, height: 22), size: 3)
        }
        .frame(width: 44, height: 44)
    }

    private func sparkle(offset: CGSize, size: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundColor(color.opacity(0.9))
            .offset(offset)
    }
}
