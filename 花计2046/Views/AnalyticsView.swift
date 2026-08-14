import SwiftUI
import Combine

struct AnalyticsView: View {
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    @EnvironmentObject var supabaseService: SupabaseService
    @ObservedObject private var searchState = SearchState.shared
    @State private var showYearPicker = false
    @State private var showMonthPicker = false
    @State private var showCategoryPicker = false
    @State private var showSearch = false
    @State private var analyticsCurrency = ""
    @State private var analyticsSnapshot: AnalyticsSnapshot?
    @State private var analyticsReady = false
    @State private var activeRebuildID = UUID()
    @State private var categoriesCache: [String] = []
    @State private var yearOptionsCache: [String] = []

    var categories: [String] { categoriesCache }
    var monthOptions: [String] { ["全部"] + (1...12).map { String(format: "%02d月", $0) } }
    var yearOptions: [String] { yearOptionsCache }

    /// 重建类别/年份选项（仅在数据或筛选变化时执行，避免每次渲染全量遍历）
    private func rebuildFilterOptions() {
        let allExpenseCats = Set(supabaseService.allRecords.filter(\.isExpense).map(\.category))
        let allIncomeCats = Set(supabaseService.allRecords.filter(\.isIncome).map(\.category))
        let matchedExpense = CategoryManager.expenseCats.filter { allExpenseCats.contains($0) }
        let matchedIncome = CategoryManager.incomeCats.filter { allIncomeCats.contains($0) }
        let hasData = !allExpenseCats.isEmpty || !allIncomeCats.isEmpty

        switch searchState.type {
        case "支出":
            categoriesCache = hasData ? ["全部"] + matchedExpense : ["全部"] + CategoryManager.expenseCats
        case "收入":
            categoriesCache = hasData ? ["全部"] + matchedIncome : ["全部"] + CategoryManager.incomeCats
        default:
            categoriesCache = hasData ? ["全部"] + matchedExpense + matchedIncome : ["全部"] + CategoryManager.expenseCats + CategoryManager.incomeCats
        }

        yearOptionsCache = ["全部"] + Set(supabaseService.expenses.map { String($0.month.prefix(4)) + "年" }).sorted(by: >)
    }
    var hasActiveFilters: Bool { !searchState.text.isEmpty || !searchState.note.isEmpty || !searchState.category.isEmpty || !searchState.year.isEmpty || !searchState.month.isEmpty || searchState.type != "全部" }
    var filterSummaryText: String {
        var parts: [String] = []
        if searchState.type != "全部" { parts.append(searchState.type) }
        if !searchState.year.isEmpty { parts.append(searchState.year) }
        if !searchState.month.isEmpty { parts.append(searchState.month) }
        if !searchState.category.isEmpty { parts.append(searchState.category) }
        if !searchState.text.isEmpty { parts.append("名称:\(searchState.text)") }
        if !searchState.note.isEmpty { parts.append("备注:\(searchState.note)") }
        return parts.joined(separator: " · ")
    }
    
    private var snapshotKey: String {
        [
            searchState.type,
            searchState.text,
            searchState.note,
            searchState.category,
            searchState.year,
            searchState.month,
            currencySymbol,
            analyticsCurrency
        ].joined(separator: "\u{1F}")
    }

    var filteredRecords: [Record] {
        analyticsSnapshot?.filteredRecords ?? []
    }
    
    struct CategoryAnalytics: Identifiable {
        let category: String
        let currency: String
        let amount: Double
        let count: Int
        let ratio: Double
        var id: String { category + currency }
    }
    
    private struct AnalyticsGroupKey: Hashable {
        let category: String
        let currency: String
    }
    
   var categoryAnalytics: [CategoryAnalytics] {
        analyticsSnapshot?.categoryAnalytics ?? []
    }
    
    var expenseAnalytics: [CategoryAnalytics] {
        analyticsSnapshot?.expenseAnalytics ?? []
    }
    
    var incomeAnalytics: [CategoryAnalytics] {
        analyticsSnapshot?.incomeAnalytics ?? []
    }

    private static func categoryAnalytics(for data: [Record]) -> [CategoryAnalytics] {
        let grouped = Dictionary(grouping: data, by: { AnalyticsGroupKey(category: $0.category, currency: $0.displayCurrency) })
        let totalByCurrency = Dictionary(grouping: data, by: { $0.displayCurrency })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        return grouped.map { key, items in
            let sum = items.reduce(0) { $0 + $1.amount }
            let total = totalByCurrency[key.currency] ?? 0
            return CategoryAnalytics(
                category: key.category,
                currency: key.currency,
                amount: sum,
                count: items.count,
                ratio: total > 0 ? sum / total : 0
            )
        }
        .sorted { $0.amount > $1.amount }
    }
    
    private var availableCurrencies: [String] {
        analyticsSnapshot?.availableCurrencies ?? []
    }

    private var effectiveAnalyticsCurrency: String {
        analyticsSnapshot?.effectiveCurrency ?? currencySymbol
    }

    private var analyticsRecords: [Record] {
        analyticsSnapshot?.analyticsRecords ?? []
    }

    private var monthlyBarPoints: [AnalyticsBarPoint] {
        analyticsSnapshot?.monthlyBarPoints ?? []
    }

    private var monthlyLinePoints: [AnalyticsLinePoint] {
        analyticsSnapshot?.monthlyLinePoints ?? []
    }

    private var dailyScatterPoints: [AnalyticsDotPoint] {
        analyticsSnapshot?.dailyScatterPoints ?? []
    }

    private static func shortMonth(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]), let year = Int(parts[0]) else { return key }
        return String(format: "%02d/%02d", year % 100, month)
    }
    
    // MARK: - 月度对比 / 健康指标
    private var currentMonthRecords: [Record] {
        analyticsSnapshot?.currentMonthRecords ?? []
    }
    
    private var previousMonthRecords: [Record] {
        analyticsSnapshot?.previousMonthRecords ?? []
    }
    
    private var monthExpenseChange: Double? {
        analyticsSnapshot?.health.monthExpenseChange
    }
    
    private var monthExpenseChangeText: String {
        guard let change = monthExpenseChange else { return "上月无支出" }
        return String(format: "%@%.1f%%", change >= 0 ? "+" : "", change)
    }
    
    private var monthExpenseChangeColor: Color {
        guard let change = monthExpenseChange else { return AppTheme.textSecondary }
        return change > 0 ? AppTheme.brandStart : .green
    }
    
    private var dailyAverageExpenseText: String {
        guard let value = dailyAverageExpense else { return "--" }
        return String(format: "%@%.2f", effectiveAnalyticsCurrency, value)
    }
    
    private var dailyAverageExpense: Double? {
        analyticsSnapshot?.health.dailyAverageExpense
    }

  var body: some View {
       NavigationView {
            ZStack(alignment: .bottomTrailing) {
           VStack(spacing: 0) {
               Color.clear.frame(height: showSearch ? 9 : 4)
                if showSearch { searchPanel.transition(.move(edge: .top).combined(with: .opacity)) }
                if hasActiveFilters {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease").font(.system(size: 15))
                        Text(filterSummaryText).font(.system(size: 17, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.brandGradient)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(AppTheme.brandStart.opacity(0.08))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.top, showSearch ? 6 : 10)
                    .padding(.bottom, showSearch ? 4 : 6)
                }
                if supabaseService.allRecords.isEmpty && supabaseService.isRecordsLoading {
                    Spacer()
                    PawPrintLoading().offset(y: 5)
                    Spacer()
                } else if supabaseService.allRecords.isEmpty {
                   ScrollView { emptyState }
               } else if !analyticsReady {
                   ProgressView()
                       .frame(maxWidth: .infinity, maxHeight: .infinity)
               } else {
               ScrollView {
               VStack(spacing: 16) {
                    // 1. 月小结（当月/搜索月份）
                    monthSummaryCard

                    // 2. 趣味点评（30天记录点评）
                    AIReviewCard()
                        .environmentObject(supabaseService)

                    // 3. 收支目标（整体模块）
                    GoalsModuleCard()
                        .environmentObject(supabaseService)

                    // 4. 资金总览：12个月收支双折线（标题在卡片内）
                    totalCard
                    if !monthlyTrendPoints.isEmpty {
                        trend12Card
                    }
                    
                    // 收入（标题在卡片内，位于支出前）
                    if searchState.type == "全部" || searchState.type == "收入" {
                        if !incomeAnalytics.isEmpty {
                            categorySection(icon: "arrow.up.circle", title: "收入", data: incomeAnalytics)
                        }
                    }
                    
                    // 支出（标题在卡片内，位于收入后）
                    if searchState.type == "全部" || searchState.type == "支出" {
                        if !expenseAnalytics.isEmpty {
                            categorySection(icon: "arrow.down.circle", title: "支出", data: expenseAnalytics)
                        }
                    }
                }
            }
            .padding(.top, 8).padding(.horizontal, 16).padding(.bottom, 16)
            }
        } // VStack
            .background(AppTheme.background)
            .navigationTitle("分析")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("分析")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            }
            .ignoresSafeArea(.keyboard)
        }
        .ignoresSafeArea(.keyboard)
        .overlay(alignment: .bottomTrailing) { floatingSearchButton }
        .sheet(isPresented: $showYearPicker) { YearWheelPicker(selection: $searchState.year, options: yearOptions).presentationDetents([.height(230)]) }
        .sheet(isPresented: $showMonthPicker) { MonthWheelPicker(selection: $searchState.month, options: monthOptions).presentationDetents([.height(270)]) }
        .sheet(isPresented: $showCategoryPicker) { CategoryWheelPicker(selection: $searchState.category, options: categories).presentationDetents([.height(230)]) }
        .onAppear { rebuildSnapshot() }
        .onChange(of: snapshotKey) { _ in rebuildSnapshot() }
        .onReceive(supabaseService.$allRecords) { _ in rebuildSnapshot() }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSearch)
   }
    
    
    @ViewBuilder private var floatingSearchButton: some View {
        Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showSearch.toggle() } }) {
            ZStack {
                Circle().fill(AppTheme.brandGradient).frame(width: 56, height: 56).shadow(color: AppTheme.brandShadow, radius: 10, x: 0, y: 4)
                Image(systemName: showSearch ? "xmark" : "magnifyingglass").font(.system(size: 21, weight: .semibold)).foregroundColor(.white)
            }
            .opacity(showSearch ? 0.7 : 0.3)
        }
        .padding(.trailing, 20).padding(.bottom, 40)
        .overlay(alignment: .topTrailing) {
            if hasActiveFilters && !showSearch {
                Circle().fill(AppTheme.brandGradient).frame(width: 12, height: 12).offset(x: -14, y: 14)
            }
        }
    }
    
    @ViewBuilder private var searchPanel: some View {
        VStack(spacing: 8) {
                HStack(spacing: 0) {
                    analyticsTypeButton("全部")
                    analyticsTypeButton("收入")
                    analyticsTypeButton("支出")
                }
                .background(AppTheme.background)
                .cornerRadius(7)
            HStack(spacing: 8) {
                SearchNameField(text: $searchState.text, placeholder: "搜索名称...")
                    .byteLimited($searchState.text, max: 50)
                SearchNameField(text: $searchState.note, placeholder: "搜索备注...")
                    .byteLimited($searchState.note, max: 200)
            }
            HStack(spacing: 8) {
                FilterChip(label: searchState.year.isEmpty ? "全部年份" : searchState.year, isActive: !searchState.year.isEmpty) { showYearPicker = true }
                FilterChip(label: searchState.month.isEmpty ? "全部月份" : searchState.month, isActive: !searchState.month.isEmpty) { showMonthPicker = true }
                FilterChip(label: searchState.category.isEmpty ? "全部类别" : searchState.category, isActive: !searchState.category.isEmpty) { showCategoryPicker = true }
            }
            if hasActiveFilters {
                Button(action: { withAnimation { searchState.text = ""; searchState.note = ""; searchState.category = ""; searchState.year = ""; searchState.month = ""; searchState.type = "全部" } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 15))
                        Text("清除筛选").font(.system(size: 15))
                    }.foregroundColor(.white.opacity(0.85))
                }.padding(.top, 2)
            }
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.brandGradient).shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4))
        .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 0)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { dismissKeyboard() }
                    .foregroundColor(AppTheme.brandStart)
            }
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 140)
            ZStack {
                Circle().fill(AppTheme.brandStart.opacity(0.06)).frame(width: 160, height: 160)
                Circle().fill(AppTheme.brandGradient.opacity(0.04)).frame(width: 120, height: 120)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(Color(hex: "#C0C0C0").opacity(0.5))
            }
            VStack(spacing: 6) {
                Text("暂无记录")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(Color(hex: "#C0C0C0"))
                Text("点击底部「录入」开始记账")
                    .font(.system(size: 17))
                    .foregroundColor(Color(hex: "#C0C0C0"))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

extension AnalyticsView {
    private struct HealthMetrics {
        let monthExpenseChange: Double?
        let savingsRate: Double?
        let dailyAverageExpense: Double?
        let largestExpenseRatio: Double?
    }

    private struct AnalyticsSnapshot {
        let filteredRecords: [Record]
        let categoryAnalytics: [CategoryAnalytics]
        let expenseAnalytics: [CategoryAnalytics]
        let incomeAnalytics: [CategoryAnalytics]
        let availableCurrencies: [String]
        let effectiveCurrency: String
        let analyticsRecords: [Record]
        let monthlyBarPoints: [AnalyticsBarPoint]
        let monthlyLinePoints: [AnalyticsLinePoint]
        let monthlyTrendPoints: [MonthlyTrendPoint]
        let dailyScatterPoints: [AnalyticsDotPoint]
        let currentMonthRecords: [Record]
        let previousMonthRecords: [Record]
        let hasCurrentMonthRecords: Bool
        let health: HealthMetrics

        static func make(
            records: [Record],
            searchType: String,
            searchText: String,
            searchNote: String,
            searchCategory: String,
            searchYear: String,
            searchMonth: String,
            currencySymbol: String,
            analyticsCurrency: String,
            now: Date
        ) -> AnalyticsSnapshot {
            let typeFiltered: [Record]
            switch searchType {
            case "支出": typeFiltered = records.filter { $0.isExpense }
            case "收入": typeFiltered = records.filter { $0.isIncome }
            default: typeFiltered = records
            }

            let filtered: [Record]
            if searchText.isEmpty && searchCategory.isEmpty && searchYear.isEmpty && searchMonth.isEmpty && searchNote.isEmpty {
                filtered = typeFiltered
            } else {
                filtered = typeFiltered.filter { record in
                    record.matchesSearch(
                        searchText: searchText,
                        searchNote: searchNote,
                        searchCategory: searchCategory,
                        searchYear: searchYear,
                        searchMonth: searchMonth
                    )
                }
            }

            let categoryAnalytics = AnalyticsView.categoryAnalytics(for: filtered)
            let expenseAnalytics = AnalyticsView.categoryAnalytics(for: filtered.filter(\.isExpense))
            let incomeAnalytics = AnalyticsView.categoryAnalytics(for: filtered.filter(\.isIncome))
            let availableCurrencies = Array(Set(filtered.map { $0.displayCurrency })).sorted()

            let effectiveCurrency: String
            if availableCurrencies.contains(analyticsCurrency) {
                effectiveCurrency = analyticsCurrency
            } else if availableCurrencies.contains(currencySymbol) {
                effectiveCurrency = currencySymbol
            } else {
                effectiveCurrency = availableCurrencies.first ?? currencySymbol
            }

            let currencyRecords = filtered.filter { $0.displayCurrency == effectiveCurrency }
            let barGrouped = Dictionary(grouping: currencyRecords, by: { $0.month })
            let monthlyBarPoints = barGrouped.keys.sorted().flatMap { month in
                let monthRecords = barGrouped[month] ?? []
                let income = monthRecords.filter(\.isIncome).reduce(0) { $0 + $1.amount }
                let expense = monthRecords.filter(\.isExpense).reduce(0) { $0 + $1.amount }
                return [
                    AnalyticsBarPoint(month: shortMonth(month), type: "收入", amount: income),
                    AnalyticsBarPoint(month: shortMonth(month), type: "支出", amount: expense)
                ]
            }

            let lineGrouped = Dictionary(grouping: currencyRecords, by: { $0.month })
            let monthlyLinePoints = lineGrouped.keys.sorted().compactMap { month in
                let monthRecords = lineGrouped[month] ?? []
                let net = monthRecords.reduce(0) { $0 + $1.signedAmount }
                return AnalyticsLinePoint(month: month, monthDisplay: shortMonth(month), net: net)
            }

            let currentKey = currentMonthKey(searchYear: searchYear, searchMonth: searchMonth, now: now)
            let previousKey = previousMonthKey(for: currentKey, now: now)
            let currentMonthRecords = records.filter { $0.displayCurrency == effectiveCurrency && $0.month == currentKey }
            let previousMonthRecords = records.filter { $0.displayCurrency == effectiveCurrency && $0.month == previousKey }

            let cal = Calendar.current
            let dailyGrouped = Dictionary(grouping: currencyRecords.filter { $0.month == currentKey }, by: { cal.component(.day, from: $0.date) })
            let dailyScatterPoints = dailyGrouped.keys.sorted().flatMap { day in
                let dayRecords = dailyGrouped[day] ?? []
                let income = dayRecords.filter(\.isIncome).reduce(0) { $0 + $1.amount }
                let expense = dayRecords.filter(\.isExpense).reduce(0) { $0 + $1.amount }
                return [
                    AnalyticsDotPoint(day: day, type: "收入", amount: income),
                    AnalyticsDotPoint(day: day, type: "支出", amount: expense)
                ]
            }
            .filter { $0.amount > 0 }

            // 近 12 个月收支趋势（双折线）
            let trendGrouped = Dictionary(grouping: currencyRecords, by: { $0.month })
            let recentMonths = Array(trendGrouped.keys.sorted().suffix(12))
            let monthlyTrendPoints = recentMonths.compactMap { month -> MonthlyTrendPoint? in
                let recs = trendGrouped[month] ?? []
                let income = recs.filter(\.isIncome).reduce(0) { $0 + $1.amount }
                let expense = recs.filter(\.isExpense).reduce(0) { $0 + $1.amount }
                return MonthlyTrendPoint(month: month, monthDisplay: shortMonth(month), income: income, expense: expense)
            }

            let currentExpense = currentMonthRecords.filter(\.isExpense).reduce(0) { $0 + $1.amount }
            let previousExpense = previousMonthRecords.filter(\.isExpense).reduce(0) { $0 + $1.amount }
            let currentIncome = currentMonthRecords.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let dayCount = daysElapsed(for: currentKey, now: now)
            let largestExpense = currentMonthRecords.filter(\.isExpense).map(\.amount).max() ?? 0

            let health = HealthMetrics(
                monthExpenseChange: previousExpense > 0 ? (currentExpense - previousExpense) / previousExpense * 100 : nil,
                savingsRate: currentIncome > 0 ? (currentIncome - currentExpense) / currentIncome * 100 : nil,
                dailyAverageExpense: dayCount > 0 ? currentExpense / Double(dayCount) : nil,
                largestExpenseRatio: currentExpense > 0 ? largestExpense / currentExpense * 100 : nil
            )

            return AnalyticsSnapshot(
                filteredRecords: filtered,
                categoryAnalytics: categoryAnalytics,
                expenseAnalytics: expenseAnalytics,
                incomeAnalytics: incomeAnalytics,
                availableCurrencies: availableCurrencies,
                effectiveCurrency: effectiveCurrency,
                analyticsRecords: currencyRecords,
                monthlyBarPoints: monthlyBarPoints,
                monthlyLinePoints: monthlyLinePoints,
                monthlyTrendPoints: monthlyTrendPoints,
                dailyScatterPoints: dailyScatterPoints,
                currentMonthRecords: currentMonthRecords,
                previousMonthRecords: previousMonthRecords,
                hasCurrentMonthRecords: !currentMonthRecords.isEmpty,
                health: health
            )
        }

        private static func currentMonthKey(searchYear: String, searchMonth: String, now: Date) -> String {
            let cal = Calendar.current
            if !searchYear.isEmpty || !searchMonth.isEmpty {
                let year = searchYear.isEmpty ? String(cal.component(.year, from: now)) : searchYear.replacingOccurrences(of: "年", with: "")
                let month = searchMonth.isEmpty ? String(cal.component(.month, from: now)) : searchMonth.replacingOccurrences(of: "月", with: "")
                return String(format: "%04d-%02d", Int(year) ?? cal.component(.year, from: now), Int(month) ?? cal.component(.month, from: now))
            }
            return String(format: "%04d-%02d", cal.component(.year, from: now), cal.component(.month, from: now))
        }

        private static func previousMonthKey(for monthKey: String, now: Date) -> String {
            let parts = monthKey.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2 else { return monthKey }
            let cal = Calendar.current
            guard let thisMonth = cal.date(from: DateComponents(year: parts[0], month: parts[1])),
                  let last = cal.date(byAdding: .month, value: -1, to: thisMonth) else { return monthKey }
            return String(format: "%04d-%02d", cal.component(.year, from: last), cal.component(.month, from: last))
        }

        private static func daysElapsed(for monthKey: String, now: Date) -> Int {
            let cal = Calendar.current
            let parts = monthKey.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2,
                  let monthDate = cal.date(from: DateComponents(year: parts[0], month: parts[1])) else { return 0 }
            if parts[0] == cal.component(.year, from: now) && parts[1] == cal.component(.month, from: now) {
                return max(1, cal.component(.day, from: now))
            }
            return cal.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        }
    }

    private func rebuildSnapshot() {
        rebuildFilterOptions()
        let requestID = UUID()
        activeRebuildID = requestID

        let records = supabaseService.allRecords
        let searchType = searchState.type
        let searchText = searchState.text
        let searchNote = searchState.note
        let searchCategory = searchState.category
        let searchYear = searchState.year
        let searchMonth = searchState.month
        let symbol = currencySymbol
        let currency = analyticsCurrency
        let now = Date()

        Task.detached {
            let snapshot = AnalyticsSnapshot.make(
                records: records,
                searchType: searchType,
                searchText: searchText,
                searchNote: searchNote,
                searchCategory: searchCategory,
                searchYear: searchYear,
                searchMonth: searchMonth,
                currencySymbol: symbol,
                analyticsCurrency: currency,
                now: now
            )
            await MainActor.run {
                guard self.activeRebuildID == requestID else { return }
                self.analyticsSnapshot = snapshot
                self.analyticsReady = true
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        AnalyticsModuleHeader(icon: icon, title: title)
            .padding(.top, 4)
    }

    private func sectionHeader(_ title: String, icon: String, @ViewBuilder trailing: @escaping () -> some View) -> some View {
        AnalyticsModuleHeader(icon: icon, title: title) {
            trailing()
        }
        .padding(.top, 4)
    }

    private var monthlyTrendPoints: [MonthlyTrendPoint] {
        analyticsSnapshot?.monthlyTrendPoints ?? []
    }

    private var currentMonthTitle: String {
        currentMonthRecords.first?.monthDisplay ?? "本月"
    }

    /// 当月收支柱状图数据（收入/支出两个柱子）
    private var currentMonthBarPoints: [AnalyticsBarPoint] {
        let income = currentMonthRecords.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let expense = currentMonthRecords.filter(\.isExpense).reduce(0) { $0 + $1.amount }
        let label = currentMonthTitle
        return [
            AnalyticsBarPoint(month: label, type: "收入", amount: income),
            AnalyticsBarPoint(month: label, type: "支出", amount: expense)
        ]
    }

    // MARK: - 月小结卡片（当月/搜索月份）
    private var monthSummaryCard: some View {
        let income = currentMonthRecords.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let expense = currentMonthRecords.filter(\.isExpense).reduce(0) { $0 + $1.amount }
        let net = income - expense
        return VStack(alignment: .leading, spacing: 14) {
            AnalyticsModuleHeader(icon: "calendar", title: "\(currentMonthTitle) 小结")
            if currentMonthRecords.isEmpty {
                Text("该月暂无记录")
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                HStack(spacing: 10) {
                    summaryValue(title: "月收入", amount: income, prefix: "+", color: .green, currency: effectiveAnalyticsCurrency)
                    summaryValue(title: "月支出", amount: expense, prefix: "-", color: AppTheme.textSecondary, currency: effectiveAnalyticsCurrency)
                }
                AppDivider()
                HStack {
                    Text("月结余")
                        .font(.appBody)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%@%@%.2f", net >= 0 ? "+" : "", effectiveAnalyticsCurrency, net))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(AppTheme.brandEnd)
                }
                HStack {
                    Text("日均支出")
                        .font(.appSmall)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text(dailyAverageExpenseText)
                        .font(.appSmall)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("支出环比")
                        .font(.appSmall)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text(monthExpenseChangeText)
                        .font(.appSmall)
                        .foregroundColor(monthExpenseChangeColor)
                }
                if income > 0 || expense > 0 {
                    MonthlyBarChartView(points: currentMonthBarPoints)
                        .frame(height: 160)
                }
            }
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
    }

    private func summaryValue(title: String, amount: Double, prefix: String, color: Color, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appSmall)
                .foregroundColor(AppTheme.textSecondary)
            Text(String(format: "%@%@%.2f", prefix, currency, amount))
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 12个月收支双折线卡片
    private var trend12Card: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnalyticsSubHeader(icon: "chart.line.uptrend.xyaxis", title: "月度收支趋势")
            MonthlyDualLineChartView(points: monthlyTrendPoints)
                .frame(height: 220)
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
    }

    private var totalCard: some View {
        let income = analyticsRecords.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let expense = analyticsRecords.filter(\.isExpense).reduce(0) { $0 + $1.amount }
        let net = income - expense
        return VStack(alignment: .leading, spacing: 16) {
            AnalyticsModuleHeader(icon: "chart.bar.xaxis", title: "资金总览") {
                if availableCurrencies.count > 1 {
                    AnalyticsCurrencyPicker(
                        currencies: availableCurrencies,
                        selection: Binding(
                            get: { effectiveAnalyticsCurrency },
                            set: { analyticsCurrency = $0 }
                        )
                    )
                }
            }
            if analyticsRecords.isEmpty {
                Text("该币种暂无记录")
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
            } else {
                HStack(spacing: 10) {
                    overviewValue(title: "收入", amount: income, prefix: "+", color: .green, currency: effectiveAnalyticsCurrency)
                    overviewValue(title: "支出", amount: expense, prefix: "-", color: AppTheme.textSecondary, currency: effectiveAnalyticsCurrency)
                }
                AppDivider()
                HStack(alignment: .firstTextBaseline) {
                    Text("净结余")
                        .font(.appBody)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%@%@%.2f", net >= 0 ? "+" : "", effectiveAnalyticsCurrency, net))
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(net >= 0 ? .green : AppTheme.brandStart)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                HStack {
                    Text("\(analyticsRecords.count)笔记录")
                        .font(.appSmall)
                        .foregroundColor(AppTheme.textTertiary)
                    Spacer()
                }
            }
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
    }

    private func overviewValue(title: String, amount: Double, prefix: String, color: Color, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appSmall)
                .foregroundColor(AppTheme.textSecondary)
            Text(String(format: "%@%@%.2f", prefix, currency, amount))
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendGroup(data: [CategoryAnalytics], start: Int, stride: Int) -> some View {
        let showCurrency = Set(data.map { $0.currency }).count > 1
        var entries: [(offset: Int, element: CategoryAnalytics)] = []
        for (i, item) in data.enumerated() {
            if (i - start) % stride == 0 {
                entries.append((i, item))
            }
        }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(entries, id: \.offset) { idx, item in
                HStack(spacing: 5) {
                    Circle()
                        .fill(catColor(item.category))
                        .frame(width: 8, height: 8)
                    Text(showCurrency ? "\(item.category) \(item.currency)" : item.category)
                        .font(.appSmall).lineLimit(1).minimumScaleFactor(0.75)
                        .foregroundColor(AppTheme.textPrimary)
                   Text(String(format: "%.1f%%", item.ratio * 100))
                        .font(.system(size: 11))
                       .lineLimit(1)
                       .frame(minWidth: 48, alignment: .trailing)
                       .foregroundColor(AppTheme.textSecondary)
               }
           }
           Spacer()
       }
   }
   

    private func categorySection(icon: String, title: String, data: [CategoryAnalytics]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AnalyticsModuleHeader(icon: icon, title: title)

            pieContent(data: data, title: "\(title)占比")

            AppDivider()

            categoryContent(data: data, title: "\(title)类别")
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
    }

    private func pieContent(data: [CategoryAnalytics], title: String) -> some View {
        let count = data.count
        let isMany = count > 6
        return VStack(alignment: .leading, spacing: 12) {
            AnalyticsSubHeader(icon: "chart.pie.fill", title: title)

            HStack(alignment: .top, spacing: isMany ? 12 : 24) {
                PieChartView(data: data)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: data.map { $0.id })
                    .frame(width: isMany ? 100 : 140, height: isMany ? 100 : 140)

                HStack(alignment: .top, spacing: isMany ? 8 : 0) {
                    if isMany {
                        legendGroup(data: data, start: 0, stride: 2)
                        legendGroup(data: data, start: 1, stride: 2)
                    } else {
                        legendGroup(data: data, start: 0, stride: 1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func categoryContent(data: [CategoryAnalytics], title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            AnalyticsSubHeader(icon: "chart.bar.fill", title: title)

            if data.isEmpty {
                Text("暂无数据")
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(data) { item in
                    CategoryDetailView(analytics: item)
                }
            }
        }
    }

    private func analyticsTypeButton(_ label: String) -> some View {
        Button(action: { searchState.type = label }) {
            Text(label).font(.system(size: 17, weight: .medium))
                .foregroundStyle(searchState.type == label ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#A855F7"), Color(hex: "#C084FC")], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color(hex: "#B0B0B0")))
                .frame(maxWidth: .infinity).padding(.vertical, 7)
                .background(searchState.type == label ? (label == "全部" ? AppTheme.brandStart.opacity(0.15) : Color(hex: "#A855F7").opacity(0.15)) : Color.white)
                .cornerRadius(6)
        }
    }
}

struct PieChartView: View {
    let data: [AnalyticsView.CategoryAnalytics]
    

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                    // 彩色玻璃层
                    PieSlice(startAngle: slice.start, endAngle: slice.end)
                        .fill(catColor(data[index].category))
                    
                    // 玻璃高光层 — 从中心白到边缘透明，模拟玻璃光泽
                    PieSlice(startAngle: slice.start, endAngle: slice.end)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.05)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: size * 0.5
                            )
                        )
                    
                    // 边界分割线
                    PieSlice(startAngle: slice.start, endAngle: slice.end)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                }
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: size / 2)
        }
    }
    
    private var slices: [(start: Angle, end: Angle)] {
        var current: Double = -90
        return data.map { item in
            let start = Angle(degrees: current)
            let sweep = item.ratio * 360
            current += sweep
            let end = Angle(degrees: current)
            return (start, end)
        }
    }
}

// 品牌色衍生色系 — 从品牌紫蓝渐变色环延伸，保持 APP UI 整体感
// 色系: 蓝紫 → 紫 → 玫红 → 粉 → 青 → 蓝 → 紫灰 → 靛蓝
let categoryColorDict: [String: Color] = [
    // 支出——品牌紫蓝衍色
    "餐饮": Color(hex: "#5B6EF0").opacity(0.88),
    "交通": Color(hex: "#A855F7").opacity(0.88),
    "购物": Color(hex: "#D486B8").opacity(0.88),
    "娱乐": Color(hex: "#F0A0C0").opacity(0.88),
    "住房": Color(hex: "#60B8D0").opacity(0.88),
    "日用": Color(hex: "#6B8FE8").opacity(0.88),
    "服饰": Color(hex: "#9A8BC8").opacity(0.88),
    "通讯": Color(hex: "#4F7CD0").opacity(0.88),
    "医疗": Color(hex: "#E06070").opacity(0.88),
    "教育": Color(hex: "#50B8A0").opacity(0.88),
    // 收入——绿色系
    "工资": Color(hex: "#34D399").opacity(0.88),
    "奖金": Color(hex: "#10B981").opacity(0.88),
    "兼职": Color(hex: "#6EE7B7").opacity(0.88),
    "投资": Color(hex: "#22C55E").opacity(0.88),
    "理财": Color(hex: "#86EFAC").opacity(0.88),
    "礼金": Color(hex: "#A7F3D0").opacity(0.88),
    "退款": Color(hex: "#4ADE80").opacity(0.88),
    "其他": Color(hex: "#A09080").opacity(0.88),
]

func catColor(_ name: String) -> Color {
    categoryColorDict[name] ?? Color(hex: "#6B7280").opacity(0.88)
}

let pieChartColors: [Color] = [
    Color(hex: "#5B6EF0").opacity(0.88),   // 餐饮
    Color(hex: "#A855F7").opacity(0.88),   // 交通
    Color(hex: "#D486B8").opacity(0.88),   // 购物
    Color(hex: "#F0A0C0").opacity(0.88),   // 娱乐
    Color(hex: "#60B8D0").opacity(0.88),   // 住房
    Color(hex: "#6B8FE8").opacity(0.88),   // 日用
    Color(hex: "#9A8BC8").opacity(0.88),   // 服饰
    Color(hex: "#4F7CD0").opacity(0.88),   // 通讯
    Color(hex: "#E06070").opacity(0.88),   // 医疗
    Color(hex: "#50B8A0").opacity(0.88),   // 教育
    Color(hex: "#A09080").opacity(0.88),   // 其他
]

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start = CGPoint(
            x: center.x + radius * cos(CGFloat(startAngle.radians)),
            y: center.y + radius * sin(CGFloat(startAngle.radians))
        )
        var path = Path()
        path.move(to: center)
        path.addLine(to: start)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct CategoryDetailView: View {
    let analytics: AnalyticsView.CategoryAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(catColor(analytics.category))
                    .frame(width: 9, height: 9)
                Text(analytics.category)
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(String(format: analytics.currency + "%.2f", analytics.amount))
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Text("\(analytics.count)笔")
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 44, alignment: .trailing)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.border)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [catColor(analytics.category), catColor(analytics.category).opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * analytics.ratio, height: 8).animation(.spring(response: 0.4, dampingFraction: 0.7), value: analytics.ratio)
                }
            }
            .frame(height: 8)
        }
    }
}
    
