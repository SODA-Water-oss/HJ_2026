import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var showYearPicker = false
    @State private var showMonthPicker = false
    @State private var showCategoryPicker = false
    @State private var showSearch = false

    var categories: [String] {
        switch supabaseService.sharedSearchType {
        case "支出": return ["全部", "餐饮", "交通", "购物", "娱乐", "住房", "日用", "服饰", "通讯", "医疗", "教育", "其他"]
        case "收入": return ["全部", "工资", "奖金", "兼职", "投资收益", "理财", "礼金", "退款", "其他"]
        default: return ["全部", "餐饮", "交通", "购物", "娱乐", "住房", "日用", "服饰", "通讯", "医疗", "教育", "其他支出", "工资", "奖金", "兼职", "投资收益", "理财", "礼金", "退款", "其他收入"]
        }
    }
    var monthOptions: [String] { ["全部"] + (1...12).map { String(format: "%02d月", $0) } }
    var yearOptions: [String] { let years = Set(supabaseService.expenses.map { String($0.month.prefix(4)) + "年" }).sorted(by: >); return ["全部"] + years }
    var hasActiveFilters: Bool { !supabaseService.sharedSearchText.isEmpty || !supabaseService.sharedSearchNote.isEmpty || !supabaseService.sharedSearchCategory.isEmpty || !supabaseService.sharedSearchYear.isEmpty || !supabaseService.sharedSearchMonth.isEmpty || supabaseService.sharedSearchType != "全部" }
    var filterSummaryText: String {
        var parts: [String] = []
        if supabaseService.sharedSearchType != "全部" { parts.append(supabaseService.sharedSearchType) }
        if !supabaseService.sharedSearchYear.isEmpty { parts.append(supabaseService.sharedSearchYear) }
        if !supabaseService.sharedSearchMonth.isEmpty { parts.append(supabaseService.sharedSearchMonth) }
        if !supabaseService.sharedSearchCategory.isEmpty { parts.append(supabaseService.sharedSearchCategory) }
        if !supabaseService.sharedSearchText.isEmpty { parts.append("名称:\(supabaseService.sharedSearchText)") }
        if !supabaseService.sharedSearchNote.isEmpty { parts.append("备注:\(supabaseService.sharedSearchNote)") }
        return parts.joined(separator: " · ")
    }
    
    var filteredRecords: [Record] {
        let typeFiltered: [Record]
        switch supabaseService.sharedSearchType {
        case "支出": typeFiltered = supabaseService.allRecords.filter { $0.isExpense }
        case "收入": typeFiltered = supabaseService.allRecords.filter { $0.isIncome }
        default: typeFiltered = supabaseService.allRecords
        }
        if supabaseService.sharedSearchText.isEmpty && supabaseService.sharedSearchCategory.isEmpty && supabaseService.sharedSearchYear.isEmpty && supabaseService.sharedSearchMonth.isEmpty && supabaseService.sharedSearchNote.isEmpty { return typeFiltered }
        return typeFiltered.filter { e in
                let matchNote = supabaseService.sharedSearchNote.isEmpty || (e.note?.localizedCaseInsensitiveContains(supabaseService.sharedSearchNote) ?? false)
            let matchMerchant = supabaseService.sharedSearchText.isEmpty || e.merchant.localizedCaseInsensitiveContains(supabaseService.sharedSearchText)
            let matchCategory: Bool
            if supabaseService.sharedSearchCategory.isEmpty { matchCategory = true }
            else if supabaseService.sharedSearchCategory == "其他支出" { matchCategory = e.category == "其他" && e.isExpense }
            else if supabaseService.sharedSearchCategory == "其他收入" { matchCategory = e.category == "其他" && e.isIncome }
            else { matchCategory = e.category == supabaseService.sharedSearchCategory }
            let matchYear = supabaseService.sharedSearchYear.isEmpty || e.month.hasPrefix(supabaseService.sharedSearchYear.replacingOccurrences(of: "年", with: ""))
            let matchMonth = supabaseService.sharedSearchMonth.isEmpty || e.month.hasSuffix(supabaseService.sharedSearchMonth.replacingOccurrences(of: "月", with: ""))
            return matchMerchant && matchCategory && matchYear && matchMonth && matchNote
       }
   }
    
    struct CategoryAnalytics: Identifiable {
        let category: String
        let amount: Double
        let count: Int
        let ratio: Double
        var id: String { category }
    }
    
   var categoryAnalytics: [CategoryAnalytics] {
        let data = filteredRecords
        let grouped = Dictionary(grouping: data, by: { $0.category })
        let total = data.reduce(0) { $0 + $1.amount }
       return grouped.map { cat, items in
            let sum = items.reduce(0) { $0 + $1.amount }
            return CategoryAnalytics(
                category: cat,
                amount: sum,
                count: items.count,
                ratio: total > 0 ? sum / total : 0
            )
        }
       .sorted { $0.amount > $1.amount }
    }
    
    var expenseAnalytics: [CategoryAnalytics] {
        let data = filteredRecords.filter(\.isExpense)
        let grouped = Dictionary(grouping: data, by: { $0.category })
        let total = data.reduce(0) { $0 + $1.amount }
        return grouped.map { cat, items in
            let sum = items.reduce(0) { $0 + $1.amount }
            return CategoryAnalytics(category: cat, amount: sum, count: items.count, ratio: total > 0 ? sum / total : 0)
        }
        .sorted { $0.amount > $1.amount }
    }
    
    var incomeAnalytics: [CategoryAnalytics] {
        let data = filteredRecords.filter(\.isIncome)
        let grouped = Dictionary(grouping: data, by: { $0.category })
        let total = data.reduce(0) { $0 + $1.amount }
        return grouped.map { cat, items in
            let sum = items.reduce(0) { $0 + $1.amount }
            return CategoryAnalytics(category: cat, amount: sum, count: items.count, ratio: total > 0 ? sum / total : 0)
        }
        .sorted { $0.amount > $1.amount }
    }
    
    var expenseTotal: Double { filteredRecords.filter(\.isExpense).reduce(0) { $0 + $1.amount } }
    var incomeTotal: Double { filteredRecords.filter(\.isIncome).reduce(0) { $0 + $1.amount } }
    var netTotal: Double { incomeTotal - expenseTotal }
    
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
               } else {
               ScrollView {
               VStack(spacing: 16) {
               totalCard
                
                if supabaseService.sharedSearchType == "全部" || supabaseService.sharedSearchType == "收入" {
                    if !incomeAnalytics.isEmpty {
                        pieCard(data: incomeAnalytics, title: "收入占比")
                        categoryCard(data: incomeAnalytics, title: "收入类别")
                    }
                }
                if supabaseService.sharedSearchType == "全部" || supabaseService.sharedSearchType == "支出" {
                    if !expenseAnalytics.isEmpty {
                        pieCard(data: expenseAnalytics, title: "支出占比")
                        categoryCard(data: expenseAnalytics, title: "支出类别")
                    }
                }
                
                if !monthlyTrend.isEmpty {
                    trendCard
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
        .sheet(isPresented: $showYearPicker) { YearWheelPicker(selection: $supabaseService.sharedSearchYear, options: yearOptions).presentationDetents([.height(230)]) }
        .sheet(isPresented: $showMonthPicker) { MonthWheelPicker(selection: $supabaseService.sharedSearchMonth, options: monthOptions).presentationDetents([.height(270)]) }
        .sheet(isPresented: $showCategoryPicker) { CategoryWheelPicker(selection: $supabaseService.sharedSearchCategory, options: categories).presentationDetents([.height(230)]) }
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
                SearchNameField(text: $supabaseService.sharedSearchText, placeholder: "名称搜索")
                    .byteLimited($supabaseService.sharedSearchText, max: 50)
                SearchNameField(text: $supabaseService.sharedSearchNote, placeholder: "备注搜索")
                    .byteLimited($supabaseService.sharedSearchNote, max: 200)
            }
            HStack(spacing: 8) {
                FilterChip(label: supabaseService.sharedSearchYear.isEmpty ? "全部年份" : supabaseService.sharedSearchYear, isActive: !supabaseService.sharedSearchYear.isEmpty) { showYearPicker = true }
                FilterChip(label: supabaseService.sharedSearchMonth.isEmpty ? "全部月份" : supabaseService.sharedSearchMonth, isActive: !supabaseService.sharedSearchMonth.isEmpty) { showMonthPicker = true }
                FilterChip(label: supabaseService.sharedSearchCategory.isEmpty ? "全部类别" : supabaseService.sharedSearchCategory, isActive: !supabaseService.sharedSearchCategory.isEmpty) { showCategoryPicker = true }
            }
            if hasActiveFilters {
                Button(action: { withAnimation { supabaseService.sharedSearchText = ""; supabaseService.sharedSearchNote = ""; supabaseService.sharedSearchCategory = ""; supabaseService.sharedSearchYear = ""; supabaseService.sharedSearchMonth = ""; supabaseService.sharedSearchType = "全部" } }) {
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
    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.brandStart)
                Text("收支概况")
                    .font(.appTitle)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            VStack(spacing: 8) {
                HStack {
                    Text("收入").font(.appBody).foregroundColor(.green)
                    Spacer()
                    Text(String(format: "+¥%.2f", incomeTotal))
                        .font(.appBodyMedium).foregroundColor(.green)
                }
                HStack {
                    Text("支出").font(.appBody).foregroundColor(AppTheme.brandStart)
                    Spacer()
                    Text(String(format: "-¥%.2f", expenseTotal))
                        .font(.appBodyMedium).foregroundColor(AppTheme.textSecondary)
                }
                AppDivider()
                HStack {
                    Text("净收入").font(.appBodyMedium).foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text(String(format: "%@¥%.2f", netTotal >= 0 ? "+" : "", netTotal))
                        .font(.appBodyMedium).foregroundColor(netTotal >= 0 ? .green : AppTheme.brandStart)
                }
            }
            HStack {
                Text("\(filteredRecords.count)笔记录")
                    .font(.appSmall).foregroundColor(AppTheme.textTertiary)
                Spacer()
            }
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
    }
    
    private func pieCard(data: [CategoryAnalytics], title: String) -> some View {
        let count = data.count
        let isMany = count > 6
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.brandStart)
                Text(title)
                    .font(.appTitle)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
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
        .cardStyle()
        .frame(maxWidth: .infinity)
    }
    
    // 图例分组（仅从 categoryAnalytics 取对应步长的项）
    private func legendGroup(data: [CategoryAnalytics], start: Int, stride: Int) -> some View {
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
                    Text(item.category)
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
   

   
   // 图例列
   private func legendColumn(data: [CategoryAnalytics], start: Int, stride: Int) -> some View {
       VStack(alignment: .leading, spacing: 10) {
           ForEach(Array(data.enumerated()), id: \.offset) { idx, item in
               if (idx - start) % stride == 0 {
                   HStack(spacing: 6) {
                       Circle()
                           .fill(catColor(item.category))
                           .frame(width: 9, height: 9)
                   Text(item.category)
                       .font(.appSmall)
                       .lineLimit(1).minimumScaleFactor(0.75)
                       .foregroundColor(AppTheme.textPrimary)

                   Text(String(format: "%.1f%%", item.ratio * 100))
                        .font(.system(size: 11))
                       .lineLimit(1)
                       .frame(minWidth: 52, alignment: .trailing)
                       .foregroundColor(AppTheme.textSecondary)
                   }
               }
           }
           Spacer()
       }
   }
    
    private func categoryCard(data: [CategoryAnalytics], title: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.brandStart)
                Text(title)
                    .font(.appTitle)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            if data.isEmpty {
                Text("暂无数据")
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                ForEach(data) { item in
                    CategoryDetailView(analytics: item)
                }
            }
        }
       .cardStyle()
       .frame(maxWidth: .infinity)
   }
    
    // MARK: - 月度趋势
    struct MonthlyTrend: Identifiable {
        let month: String
        let monthDisplay: String
        let expense: Double
        let income: Double
        var id: String { month }
    }
    
    var monthlyTrend: [MonthlyTrend] {
        let grouped = Dictionary(grouping: filteredRecords, by: { $0.month })
        return grouped.map { month, records in
            let exp = records.filter(\.isExpense).reduce(0) { $0 + $1.amount }
            let inc = records.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM"
            guard let d = df.date(from: month) else {
                return MonthlyTrend(month: month, monthDisplay: month, expense: exp, income: inc)
            }
            df.dateFormat = "MM月"
            return MonthlyTrend(month: month, monthDisplay: df.string(from: d), expense: exp, income: inc)
        }
        .sorted { $0.month < $1.month }
    }
    
    @ViewBuilder
    private var trendCard: some View {
        let allVals = monthlyTrend.flatMap { [$0.expense, $0.income] }
        let maxVal = max(allVals.max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.brandStart)
                Text("月度趋势")
                    .font(.appTitle)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            VStack(spacing: 12) {
                ForEach(monthlyTrend) { trend in
                    VStack(spacing: 4) {
                        HStack {
                            Text(trend.monthDisplay)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                                .frame(width: 40, alignment: .leading)
                            Spacer()
                        }
                        if trend.expense > 0 || trend.income > 0 {
                            HStack(spacing: 0) {
                                if trend.income > 0 {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.green)
                                        .frame(width: max(6, CGFloat(trend.income / maxVal) * 100), height: 10)
                                }
                                Spacer().frame(width: 4)
                                if trend.expense > 0 {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppTheme.brandStart)
                                        .frame(width: max(6, CGFloat(trend.expense / maxVal) * 100), height: 10)
                                }
                                Spacer()
                                Text("+\(String(format: "¥%.0f", trend.income))  \(String(format: "¥%.0f", trend.expense))")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }
                    }
                }
            }
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
    }
    private func analyticsTypeButton(_ label: String) -> some View {
        Button(action: { supabaseService.sharedSearchType = label }) {
            Text(label).font(.system(size: 17, weight: .medium))
                .foregroundStyle(supabaseService.sharedSearchType == label ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#A855F7"), Color(hex: "#C084FC")], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color(hex: "#B0B0B0")))
                .frame(maxWidth: .infinity).padding(.vertical, 7)
                .background(supabaseService.sharedSearchType == label ? (label == "全部" ? AppTheme.brandStart.opacity(0.15) : Color(hex: "#A855F7").opacity(0.15)) : Color.white)
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
    "投资收益": Color(hex: "#22C55E").opacity(0.88),
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
                Text(String(format: "¥%.2f", analytics.amount))
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
    
