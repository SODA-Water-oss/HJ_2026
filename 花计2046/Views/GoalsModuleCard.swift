import SwiftUI

// MARK: - 目标条目数据模型
struct GoalTargetItem: Codable, Identifiable {
    var id = UUID()
    var name: String = ""       // 目标名称（目标设置时输入）
    var category: String        // "收入" / "支出"
    var timeDimension: String   // "每周" / "每月" / "每年" / "日期区间"
    var amount: Double
    var comparison: String?     // "大于" / "小于" / "等于"，旧数据兼容映射
    var startDate: Date?
    var endDate: Date?
    var createdAt: Date?    // 目标创建时间（判定上一周期是否可算，旧数据为 nil 视为可判定）

    /// 展示用名称（旧数据无名称时回退为「收入目标/支出目标」）
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(category)目标" : trimmed
    }

    static let timeDimensions = ["每周", "每月", "每年", "日期区间"]
    static let comparisons = ["大于", "小于", "等于"]

    var comparisonDisplay: String {
        switch comparison {
        case "大于等于": return "大于"
        case "小于等于": return "小于"
        case "等于": return "等于"
        default: return comparison ?? "大于"
        }
    }

    func isAchieved(actual: Double) -> Bool {
        switch comparisonDisplay {
        case "小于":
            return actual < amount
        case "等于":
            return abs(actual - amount) < 0.01
        default:
            return actual > amount
        }
    }

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
    @State private var items: [GoalTargetItem] = GoalTargetItem.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnalyticsModuleHeader(icon: "target", title: "收支目标") {
                NavigationLink {
                    GoalTargetSettingPage(items: $items)
                        .environmentObject(supabaseService)
                } label: {
                    Label("目标设置", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.brandStart)
                }
                .buttonStyle(.plain)
            }

            if items.isEmpty {
                Text("暂未设置收支目标")
                    .font(.appBody)
                    .foregroundColor(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(items) { item in
                    GoalTargetCard(item: item, records: supabaseService.allRecords)
                }
            }

            // 底部：历史达成徽章（长期显示）
            Divider().padding(.vertical, 2)
            achievementBadges
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .task { await syncGoalTargets() }
    }

    /// 云端同步：先显示本地缓存，再拉取云端（换设备可恢复）；首次升级时把本地旧目标上传云端
    private func syncGoalTargets() async {
        if items.isEmpty { items = GoalTargetItem.load() }
        guard let userId = supabaseService.currentUser?.id else { return }
        guard let loaded = try? await supabaseService.fetchGoalTargets() else { return }
        let cloudItems = loaded.map { GoalTargetItem(from: $0) }
        if cloudItems.isEmpty && !items.isEmpty {
            for item in items {
                try? await supabaseService.addGoalTarget(item.toCodable(userId: userId))
            }
        } else if !cloudItems.isEmpty {
            items = cloudItems
            GoalTargetItem.save(cloudItems)
        }
    }

    // MARK: - 历史达成徽章（长期显示）
    private var achievementBadges: some View {
        // 只展示「上一周期结束前目标已存在」且真实达成的目标；刚设置的目标不判定
        let badgeItems = items.filter {
            ($0.timeDimension == "每周" || $0.timeDimension == "每月" || $0.timeDimension == "每年" || $0.timeDimension == "日期区间")
                && badgeEligible($0)
                && (achievedLastPeriod(for: $0) || achievedCountTotal(for: $0) > 0)
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "medal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.brandGradient)
                    .frame(width: 24)
                Text("目标达成徽章")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            if badgeItems.isEmpty {
                Text("目标设置后，每个统计周期结束显示徽章颁发结果。")
                    .font(.appTiny)
                    .foregroundColor(AppTheme.textTertiary)
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
        case "日期区间": return "上阶段达成"
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

    /// 目标是否可判定上一周期：必须有创建时间，且不晚于上一周期结束
    private func badgeEligible(_ item: GoalTargetItem) -> Bool {
        if item.timeDimension == "日期区间" {
            // 固定起止日期的目标：区间已结束才判定达成
            guard let end = item.endDate else { return false }
            guard end <= Date() else { return false }
            guard let createdAt = item.createdAt else { return false }
            return createdAt <= end
        }
        guard let createdAt = item.createdAt else { return false }
        guard let range = previousPeriodRange(for: item) else { return false }
        return createdAt <= range.end
    }

    /// 上一完整周期是否达成（上周/上月/上年），未达成不显示徽章
    private func achievedLastPeriod(for item: GoalTargetItem) -> Bool {
        let records = supabaseService.allRecords
        if item.timeDimension == "日期区间" {
            guard let s = item.startDate, let e = item.endDate, e >= s else { return false }
            return achieved(records: records, start: s, end: e, item: item)
        }
        guard let range = previousPeriodRange(for: item) else { return false }
        return achieved(records: records, start: range.start, end: range.end, item: item)
    }

    /// 历史累计达成次数（周=52、月=24、年=5），以文字保留成绩
    private func achievedCountTotal(for item: GoalTargetItem) -> Int {
        let records = supabaseService.allRecords
        let cal = Calendar.current
        let now = Date()
        var count = 0
        let thisWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let thisYearStart = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
        switch item.timeDimension {
        case "每周":
            for i in 1..<53 {
                let end = cal.date(byAdding: .weekOfYear, value: -(i - 1), to: thisWeekStart) ?? thisWeekStart
                let start = cal.date(byAdding: .weekOfYear, value: -1, to: end) ?? end
                if achieved(records: records, start: start, end: end, item: item) { count += 1 }
            }
        case "每月":
            for i in 1..<25 {
                let end = cal.date(byAdding: .month, value: -(i - 1), to: thisMonthStart) ?? thisMonthStart
                let start = cal.date(byAdding: .month, value: -1, to: end) ?? end
                if achieved(records: records, start: start, end: end, item: item) { count += 1 }
            }
        case "每年":
            for i in 1..<6 {
                let end = cal.date(byAdding: .year, value: -(i - 1), to: thisYearStart) ?? thisYearStart
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
        if let createdAt = item.createdAt, createdAt > end { return false }
        let recs = records.filter { $0.date >= start && $0.date < end }
        let actual: Double
        if item.category == "收入" {
            actual = recs.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        } else {
            actual = recs.filter(\.isExpense).reduce(0) { $0 + $1.amount }
        }
        return item.isAchieved(actual: actual)
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
                Image(systemName: goalComparisonIcon(comparison: item.comparisonDisplay, filled: false))
                    .font(.system(size: 15))
                    .foregroundColor(item.category == "收入" ? .green : AppTheme.textSecondary)
                Text("\(item.displayName) · \(item.timeDimension)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(item.comparisonDisplay) ¥\(Int(item.amount))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            progressBar
            Text(progressText)
                .font(.appTiny)
                .foregroundColor(progressTextColor)
            if achievedCount > 0 {
                Text("累计达成 \(achievedCount) 次")
                    .font(.appTiny)
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(12)
        .background(item.category == "收入" ? Color.green.opacity(0.08) : AppTheme.textSecondary.opacity(0.08))
        .cornerRadius(12)
    }

    /// 历史累计达成次数（每年=近5年、日期区间=1次），以文字保留成绩
    private var achievedCount: Int {
        let cal = Calendar.current
        let now = Date()
        var count = 0
        let thisYearStart = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
        switch item.timeDimension {
        case "每年":
            for i in 1..<6 {
                let end = cal.date(byAdding: .year, value: -(i - 1), to: thisYearStart) ?? thisYearStart
                let start = cal.date(byAdding: .year, value: -1, to: end) ?? end
                if achieved(start: start, end: end) { count += 1 }
            }
        case "日期区间":
            if let s = item.startDate, let e = item.endDate, e >= s, e <= now, achieved(start: s, end: e) { count = 1 }
        default:
            break
        }
        return count
    }

    private func achieved(start: Date, end: Date) -> Bool {
        guard item.amount > 0 else { return false }
        if let createdAt = item.createdAt, createdAt > end { return false }
        let recs = records.filter { $0.date >= start && $0.date < end }
        let actual: Double
        if item.category == "收入" {
            actual = recs.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        } else {
            actual = recs.filter(\.isExpense).reduce(0) { $0 + $1.amount }
        }
        return item.isAchieved(actual: actual)
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
        case "每周":
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            range = (weekStart, now)
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
        let achieved = item.isAchieved(actual: actual)
        let label = item.category == "收入" ? "收入" : "支出"
        let comparison = item.comparisonDisplay
        if actual > item.amount {
            let excess = (actual - item.amount) / item.amount * 100
            if comparison == "大于" {
                return "🎉 \(periodLabel)\(label) ¥\(Int(actual))，超额 \(Int(excess))%"
            } else if comparison == "小于" {
                return "\(periodLabel)\(label) ¥\(Int(actual))，超额 \(Int(excess))%"
            }
        }
        if achieved {
            return "🎉 \(periodLabel)\(label) ¥\(Int(actual))，已完成"
        } else if actual > 0 {
            return "\(periodLabel)\(label) ¥\(Int(actual))，完成 \(Int(percent))%"
        } else {
            return "\(periodLabel)暂无\(label)记录，完成 0%"
        }
    }

    private var periodLabel: String {
        switch item.timeDimension {
        case "每周": return "本周"
        case "每月": return "本月"
        case "每年": return "本年度"
        case "日期区间": return "本时段"
        default: return "本周期"
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(AppTheme.border)
                RoundedRectangle(cornerRadius: 4)
                    .fill(item.category == "收入" ? Color.green : AppTheme.textSecondary)
                    .frame(width: geo.size.width * min(1, percent / 100))
            }
        }
        .frame(height: 8)
    }

    private var progressTextColor: Color {
        let comparison = item.comparisonDisplay
        if comparison == "小于", actual > item.amount {
            return AppTheme.brandEnd
        }
        return AppTheme.textTertiary
    }
}

// MARK: - 目标设置（整页，参考账单提醒排版）
struct GoalTargetSettingPage: View {
    @Binding var items: [GoalTargetItem]
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var showAddForm = false
    @State private var pendingDelete: GoalTargetItem?
    @State private var editingItem: GoalTargetItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Color.clear.frame(height: 4)

                if items.isEmpty {
                    emptyState
                }

                ForEach(items) { item in
                    goalCard(item)
                }

                addGoalButton

                Spacer(minLength: 24)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.brandStart)
                    Text("目标设置")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .sheet(isPresented: $showAddForm) {
            GoalTargetAddSheet(items: $items)
        }
        .sheet(item: $editingItem) { item in
            GoalTargetAddSheet(items: $items, editingItem: item)
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
                    Task { try? await supabaseService.deleteGoalTarget(id: target.id) }
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
        .preferredColorScheme(.light)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.textTertiary)
            Text("暂无目标")
                .font(.appTitle)
                .foregroundColor(AppTheme.textPrimary)
            Text("点击下方新建目标开始")
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    private var addGoalButton: some View {
        Button(action: { showAddForm = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("新建目标")
                    .font(.appBodyMedium)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .padding(.horizontal, 20)
    }

    private func goalCard(_ item: GoalTargetItem) -> some View {
        let categoryColor: Color = item.category == "收入" ? .green : AppTheme.textSecondary
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: goalComparisonIcon(comparison: item.comparisonDisplay, filled: true))
                        .font(.system(size: 16))
                        .foregroundColor(categoryColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.appBodyMedium)
                        .foregroundColor(AppTheme.textPrimary)
                    HStack(spacing: 6) {
                        Text(item.category)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(categoryColor)
                        Text(item.timeDimension)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Text("\(item.comparisonDisplay) ¥\(Int(item.amount))")
                        .font(.appSmall)
                        .foregroundColor(categoryColor)
                    if item.timeDimension == "日期区间", let s = item.startDate, let e = item.endDate {
                        Text("\(goalChineseDate(s)) ~ \(goalChineseDate(e))")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }

                Spacer()

                Button {
                    pendingDelete = item
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(AppTheme.brandEnd)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                editingItem = item
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
}

// MARK: - 新增目标表单
struct GoalTargetAddSheet: View {
    @Binding var items: [GoalTargetItem]
    var editingItem: GoalTargetItem? = nil
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "支出"
    @State private var timeDimension = "每月"
    @State private var comparison = "大于"
    @State private var amount = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var initialized = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 4)

                    VStack(alignment: .leading, spacing: 16) {
                        // 目标名称
                        VStack(alignment: .leading, spacing: 6) {
                            Text("目标名称")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textSecondary)
                            TextField("如：每月存5000", text: $name)
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textPrimary)
                                .tint(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                                .onChange(of: name) { _, newValue in
                                    if newValue.count > 20 { name = String(newValue.prefix(20)) }
                                }
                        }

                        // 目标类型
                        VStack(alignment: .leading, spacing: 6) {
                            Text("目标类型")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textSecondary)
                            HStack(spacing: 12) {
                                typeOptionButton(
                                    title: "收入目标",
                                    icon: "arrow.up.circle",
                                    color: .green,
                                    value: "收入"
                                )
                                typeOptionButton(
                                    title: "支出目标",
                                    icon: "arrow.down.circle",
                                    color: AppTheme.textSecondary,
                                    value: "支出"
                                )
                            }
                        }

                        // 时间维度
                        VStack(alignment: .leading, spacing: 6) {
                            Text("时间维度")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textSecondary)
                            HStack(spacing: 0) {
                                ForEach(GoalTargetItem.timeDimensions, id: \.self) { dim in
                                    Button(action: { timeDimension = dim }) {
                                        Text(dim)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(timeDimension == dim ? AnyShapeStyle(Color.white) : AnyShapeStyle(AppTheme.brandGradient))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Group { if timeDimension == dim { AppTheme.brandGradient } else { AppTheme.background } })
                                            .cornerRadius(7)
                                    }
                                }
                            }
                            .background(AppTheme.background)
                            .cornerRadius(8)
                            if timeDimension == "日期区间" {
                                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                                    .environment(\.locale, Locale(identifier: "zh_CN"))
                                DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                                    .environment(\.locale, Locale(identifier: "zh_CN"))
                            }
                        }

                        // 达成条件
                        VStack(alignment: .leading, spacing: 6) {
                            Text("达成条件")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textSecondary)
                            HStack(spacing: 0) {
                                ForEach(GoalTargetItem.comparisons, id: \.self) { option in
                                    Button(action: { comparison = option }) {
                                        Text(option)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(comparison == option ? AnyShapeStyle(Color.white) : AnyShapeStyle(AppTheme.brandGradient))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Group { if comparison == option { AppTheme.brandGradient } else { AppTheme.background } })
                                            .cornerRadius(7)
                                    }
                                }
                            }
                            .background(AppTheme.background)
                            .cornerRadius(8)
                        }

                        // 目标金额
                        VStack(alignment: .leading, spacing: 6) {
                            Text("目标金额")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textSecondary)
                            TextField("金额（元）", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textPrimary)
                                .tint(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                        }
                    }
                    .whiteCardContainer()

                    VStack(spacing: 12) {
                        Button(action: saveTarget) {
                            Text("保存")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppPrimaryButtonStyle())

                        Button(action: { dismiss() }) {
                            Text("取消")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 16)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(editingItem == nil ? "新建目标" : "编辑目标")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .onAppear {
            guard let editingItem, !initialized else { return }
            name = editingItem.name
            category = editingItem.category
            timeDimension = editingItem.timeDimension
            comparison = editingItem.comparisonDisplay
            amount = String(format: "%.2f", editingItem.amount)
            startDate = editingItem.startDate ?? Date()
            endDate = editingItem.endDate ?? Date().addingTimeInterval(30 * 24 * 60 * 60)
            initialized = true
        }
        .alert("提示", isPresented: $showValidationAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .preferredColorScheme(.light)
    }

    private func saveTarget() {
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
        if let editingItem, let index = items.firstIndex(where: { $0.id == editingItem.id }) {
            var updated = items[index]
            updated.name = trimmedName
            updated.category = category
            updated.timeDimension = timeDimension
            updated.amount = value
            updated.comparison = comparison
            updated.startDate = timeDimension == "日期区间" ? startDate : nil
            updated.endDate = timeDimension == "日期区间" ? endDate : nil
            items[index] = updated
            if let userId = supabaseService.currentUser?.id {
                Task { try? await supabaseService.updateGoalTarget(updated.toCodable(userId: userId)) }
            }
        } else {
            let item = GoalTargetItem(
                id: UUID(),
                name: trimmedName,
                category: category,
                timeDimension: timeDimension,
                amount: value,
                comparison: comparison,
                startDate: timeDimension == "日期区间" ? startDate : nil,
                endDate: timeDimension == "日期区间" ? endDate : nil,
                createdAt: Date()
            )
            items.append(item)
            if let userId = supabaseService.currentUser?.id {
                Task { try? await supabaseService.addGoalTarget(item.toCodable(userId: userId)) }
            }
        }
        GoalTargetItem.save(items)
        dismiss()
    }

    private func typeOptionButton(title: String, icon: String, color: Color, value: String) -> some View {
        let isSelected = category == value
        return Button {
            category = value
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? color.opacity(0.12) : AppTheme.background)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(0.5) : AppTheme.border, lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

private func goalChineseDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy年M月d日"
    return formatter.string(from: date)
}

private func goalComparisonIcon(comparison: String, filled: Bool) -> String {
    switch comparison {
    case "小于":
        return filled ? "arrow.down.circle.fill" : "arrow.down.circle"
    case "等于":
        return filled ? "equal.circle.fill" : "equal.circle"
    default:
        return filled ? "arrow.up.circle.fill" : "arrow.up.circle"
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
