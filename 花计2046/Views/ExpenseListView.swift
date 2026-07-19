import SwiftUI
import Combine

// MARK: - 账本主视图
struct ExpenseListView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var selectedExpense: Expense?
    @State private var editingExpense: Expense?
    @State private var showDetail = false
    @State private var showEdit = false
    @State private var showDeleteAlert = false
    @State private var pendingDeleteExpense: Expense?
    @State private var showCategoryPicker = false
    @State private var showYearPicker = false
    @State private var showMonthPicker = false
   @State private var showSearch = false
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var listHeight: CGFloat = 600
   @State private var lastScrollTime: Date = .distantPast
   @State private var fingerY: CGFloat = 0
   @State private var sweepToggled: Set<UUID> = []
   @State private var selectedExpenseIds: Set<UUID> = []
   @State private var sweepModeActive = false
   @State private var sweepDriver = SweepScrollDriver()
   @State private var sweepDirectionDown = true
   @State private var showBatchNoteSheet = false
    @State private var batchNoteText = ""
    @State private var batchNoteMode: NoteMode = .replace
    
    var categories: [String] {
        switch supabaseService.sharedSearchType {
        case "支出": return ["全部", "餐饮", "交通", "购物", "娱乐", "住房", "日用", "服饰", "通讯", "医疗", "教育", "其他"]
        case "收入": return ["全部", "工资", "奖金", "兼职", "投资收益", "理财", "礼金", "退款", "其他"]
        default: return ["全部", "餐饮", "交通", "购物", "娱乐", "住房", "日用", "服饰", "通讯", "医疗", "教育", "其他支出", "工资", "奖金", "兼职", "投资收益", "理财", "礼金", "退款", "其他收入"]
        }
    }
    var monthOptions: [String] { ["全部"] + (1...12).map { String(format: "%02d月", $0) } }
    
  var yearOptions: [String] {
        let years = Set(supabaseService.expenses.map { String($0.month.prefix(4)) + "年" }).sorted(by: >)
        return ["全部"] + years
   }

   var allFilteredIds: Set<UUID> { Set(searchGrouped.flatMap { $0.expenses.map { $0.id } }) }
   var isAllSelected: Bool { !allFilteredIds.isEmpty && selectedExpenseIds.isSuperset(of: allFilteredIds) }
   var allSelected: [Expense] {
        let ids = selectedExpenseIds
        return searchGrouped.flatMap { $0.expenses }.filter { ids.contains($0.id) }
   }
   
   var hasActiveFilters: Bool {
        !supabaseService.sharedSearchText.isEmpty || !supabaseService.sharedSearchNote.isEmpty || !supabaseService.sharedSearchCategory.isEmpty || !supabaseService.sharedSearchYear.isEmpty || !supabaseService.sharedSearchMonth.isEmpty || supabaseService.sharedSearchType != "全部"
   }
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
    
    var searchGrouped: [MonthExpenseGroup] {
        let typeFiltered: [Expense]
        switch supabaseService.sharedSearchType {
        case "支出": typeFiltered = supabaseService.allRecords.filter { $0.isExpense }
        case "收入": typeFiltered = supabaseService.allRecords.filter { $0.isIncome }
        default: typeFiltered = supabaseService.allRecords
        }
        if supabaseService.sharedSearchText.isEmpty && supabaseService.sharedSearchCategory.isEmpty && supabaseService.sharedSearchYear.isEmpty && supabaseService.sharedSearchMonth.isEmpty && supabaseService.sharedSearchNote.isEmpty {
            let grouped = Dictionary(grouping: typeFiltered) { $0.month }
            return grouped.map { key, value in
                MonthExpenseGroup(month: key, monthDisplay: value.first?.monthDisplay ?? key, expenses: value.sorted { $0.date > $1.date })
            }.sorted { $0.month > $1.month }
        }
        let filtered = typeFiltered.filter { e in
            let matchMerchant = supabaseService.sharedSearchText.isEmpty || e.merchant.localizedCaseInsensitiveContains(supabaseService.sharedSearchText)
            let matchNote = supabaseService.sharedSearchNote.isEmpty || (e.note?.localizedCaseInsensitiveContains(supabaseService.sharedSearchNote) ?? false)
            let matchCategory: Bool
            if supabaseService.sharedSearchCategory.isEmpty { matchCategory = true }
            else if supabaseService.sharedSearchCategory == "其他支出" { matchCategory = e.category == "其他" && e.isExpense }
            else if supabaseService.sharedSearchCategory == "其他收入" { matchCategory = e.category == "其他" && e.isIncome }
            else { matchCategory = e.category == supabaseService.sharedSearchCategory }
            let matchYear = supabaseService.sharedSearchYear.isEmpty || e.month.hasPrefix(supabaseService.sharedSearchYear.replacingOccurrences(of: "年", with: ""))
            let matchMonth = supabaseService.sharedSearchMonth.isEmpty || e.month.hasSuffix(supabaseService.sharedSearchMonth.replacingOccurrences(of: "月", with: ""))
            return matchMerchant && matchNote && matchCategory && matchYear && matchMonth
        }
        let grouped = Dictionary(grouping: filtered) { $0.month }
        return grouped.map { key, value in
            MonthExpenseGroup(month: key, monthDisplay: value.first?.monthDisplay ?? key, expenses: value.sorted { $0.date > $1.date })
        }.sorted { $0.month > $1.month }
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 12)
                    if showSearch {
                        searchPanel
                    }
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
                        .padding(.top, showSearch ? 6 : 3)
                        .animation(.easeOut(duration: 0.2), value: showSearch)
                        .padding(.bottom, showSearch ? 4 : 12)
                    }
                    if showSearch { Color.clear.frame(height: 8) }
                    if supabaseService.allRecords.isEmpty && supabaseService.isRecordsLoading {
                        Spacer()
                        PawPrintLoading()
                        Spacer()
                    } else if supabaseService.allRecords.isEmpty {
                        ScrollView { emptyState }.scrollDismissesKeyboard(.immediately)
                    } else {
                        expenseList
                    }
                }
                .background(AppTheme.background)
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
            }
            .background(GeometryReader { geo in Color.clear.onAppear { listHeight = geo.size.height - 120 } })
            .ignoresSafeArea(.keyboard)
            .navigationTitle("账本")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.clipboard.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(AppTheme.brandGradient)
                        Text("账本").font(.system(size: 17, weight: .semibold)).foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(NavigationLink(destination: Group { if let e = selectedExpense { ExpenseDetailView(expense: e) } }, isActive: $showDetail) { EmptyView() })
            .background(NavigationLink(destination: Group { if let e = editingExpense { EditExpenseView(expense: e) { }.environmentObject(supabaseService) } }, isActive: $showEdit) { EmptyView() })
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { pendingDeleteExpense = nil }
                Button("确认删除", role: .destructive) {
                    if let expense = pendingDeleteExpense {
                        Task { try? await supabaseService.deleteExpense(expense) }
                    }
                    pendingDeleteExpense = nil
                }
            } message: { Text("是否确定删除该笔账单？") }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showYearPicker) { YearWheelPicker(selection: $supabaseService.sharedSearchYear, options: yearOptions).presentationDetents([.height(230)]) }
        .sheet(isPresented: $showMonthPicker) { MonthWheelPicker(selection: $supabaseService.sharedSearchMonth, options: monthOptions).presentationDetents([.height(270)]) }
        .sheet(isPresented: $showCategoryPicker) { CategoryWheelPicker(selection: $supabaseService.sharedSearchCategory, options: categories).presentationDetents([.height(230)]) }
        .sheet(isPresented: $showBatchNoteSheet) { BatchOperationSheet(selectedCount: allSelected.count, batchNoteText: $batchNoteText, batchNoteMode: $batchNoteMode, onNoteConfirm: { Task { try? await supabaseService.batchUpdateNote(expenses: allSelected, note: batchNoteText, mode: batchNoteMode); selectedExpenseIds = [] } }, onDeleteConfirm: { Task { try? await supabaseService.batchDeleteExpenses(ids: Array(selectedExpenseIds)); selectedExpenseIds = [] } }, onDateConfirm: { date in Task { try? await supabaseService.batchUpdateTime(expenses: allSelected, date: date); selectedExpenseIds = [] } }, onCategoryConfirm: { cat in Task { try? await supabaseService.batchUpdateCategory(expenses: allSelected, category: cat); selectedExpenseIds = [] } }, onCancel: { showBatchNoteSheet = false }) }
        .onAppear {
            SupabaseService.shared.unreadExpenseCount = 0
        }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSearch)
        .overlay(alignment: .bottomTrailing) { if !showDetail && !showEdit { floatingSearchButton } }
    }
    
    @ViewBuilder private var floatingSearchButton: some View {
        Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showSearch.toggle(); if !showSearch { selectedExpenseIds = [] } } }) {
            ZStack {
                Circle().fill(AppTheme.brandGradient).frame(width: 56, height: 56).shadow(color: AppTheme.brandShadow, radius: 10, x: 0, y: 4)
                Image(systemName: showSearch ? "xmark" : "magnifyingglass").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
            }
            .opacity(showSearch ? 0.7 : 0.3)
        }
        .padding(.trailing, 20).padding(.bottom, 40)
        .overlay(alignment: .topTrailing) {
            if hasActiveFilters && !showSearch {
                Circle().fill(AppTheme.brandEnd).frame(width: 12, height: 12).offset(x: -14, y: 14)
            }
        }
    }
    
    @ViewBuilder private var searchPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Button(action: { supabaseService.sharedSearchType = "全部" }) {
                    Text("全部").font(.system(size: 17, weight: .medium))
                        .foregroundStyle(supabaseService.sharedSearchType == "全部" ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#A855F7"), Color(hex: "#C084FC")], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color(hex: "#B0B0B0")))
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(supabaseService.sharedSearchType == "全部" ? AppTheme.brandStart.opacity(0.15) : Color.white)
                        .cornerRadius(6)
                }
                Button(action: { supabaseService.sharedSearchType = "收入" }) {
                    Text("收入").font(.system(size: 17, weight: .medium))
                        .foregroundStyle(supabaseService.sharedSearchType == "收入" ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#A855F7"), Color(hex: "#C084FC")], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color(hex: "#B0B0B0")))
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(supabaseService.sharedSearchType == "收入" ? Color(hex: "#A855F7").opacity(0.15) : Color.white)
                        .cornerRadius(6)
                }
                Button(action: { supabaseService.sharedSearchType = "支出" }) {
                    Text("支出").font(.system(size: 17, weight: .medium))
                        .foregroundStyle(supabaseService.sharedSearchType == "支出" ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#A855F7"), Color(hex: "#C084FC")], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color(hex: "#B0B0B0")))
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(supabaseService.sharedSearchType == "支出" ? Color(hex: "#A855F7").opacity(0.15) : Color.white)
                        .cornerRadius(6)
                }
            }
            .background(AppTheme.background)
            .cornerRadius(7)
            HStack(spacing: 8) {
                SearchNameField(text: $supabaseService.sharedSearchText, placeholder: "名称搜索")
                    .byteLimited($supabaseService.sharedSearchText, max: 50)
                SearchNameField(text: $supabaseService.sharedSearchNote, placeholder: "备注搜索...")
                    .byteLimited($supabaseService.sharedSearchNote, max: 200)
            }
            HStack(spacing: 8) {
                FilterChip(label: supabaseService.sharedSearchYear.isEmpty ? "全部年份" : supabaseService.sharedSearchYear, isActive: !supabaseService.sharedSearchYear.isEmpty) { showYearPicker = true }
                FilterChip(label: supabaseService.sharedSearchMonth.isEmpty ? "全部月份" : supabaseService.sharedSearchMonth, isActive: !supabaseService.sharedSearchMonth.isEmpty) { showMonthPicker = true }
                FilterChip(label: supabaseService.sharedSearchCategory.isEmpty ? "全部类别" : supabaseService.sharedSearchCategory, isActive: !supabaseService.sharedSearchCategory.isEmpty) { showCategoryPicker = true }
            }
            if hasActiveFilters {
                Button(action: clearFilters) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 15))
                        Text("清除筛选").font(.system(size: 15))
                    }.foregroundColor(.white.opacity(0.85))
                }.padding(.top, 2)
            }
            // ── 勾选操作栏 ──
            HStack(spacing: 12) {
                    Text("已选 \(selectedExpenseIds.count) 条")
                        .font(.system(size: 15)).foregroundColor(.white.opacity(0.85))
                Spacer()
                Button(action: {
                    if isAllSelected { selectedExpenseIds = [] }
                    else { selectedExpenseIds = allFilteredIds }
                }) {
                    Text(isAllSelected ? "取消全选" : "全选")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.white.opacity(0.2)).cornerRadius(6)
                }
            }
            Button(action: {
                guard !selectedExpenseIds.isEmpty else { return }
                batchNoteText = ""; showBatchNoteSheet = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.and.list.clipboard").font(.system(size: 15))
                    Text("批量操作（已选 \(selectedExpenseIds.count) 条）").font(.system(size: 15))
                }.foregroundColor(.white.opacity(selectedExpenseIds.isEmpty ? 0.35 : 0.9))
            }.padding(.top, 4)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.brandGradient).shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4))
        .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 0)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { dismissKeyboard() }
                    .foregroundStyle(AppTheme.brandGradient)
            }
        }
    }
    
    private func clearFilters() {
        withAnimation { supabaseService.sharedSearchText = ""; supabaseService.sharedSearchNote = ""; supabaseService.sharedSearchCategory = ""; supabaseService.sharedSearchYear = ""; supabaseService.sharedSearchMonth = ""; supabaseService.sharedSearchType = "全部"; selectedExpenseIds = [] }
    }

    private func toggleExpense(_ id: UUID) {
        if selectedExpenseIds.contains(id) { selectedExpenseIds.remove(id) }
        else { selectedExpenseIds.insert(id) }
    }
    
    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 132)
            ZStack {
                Circle().fill(AppTheme.brandStart.opacity(0.06)).frame(width: 160, height: 160)
                Circle().fill(AppTheme.brandEnd.opacity(0.04)).frame(width: 120, height: 120)
                Image(systemName: "tray.full.fill").font(.system(size: 44, weight: .light)).foregroundColor(Color(hex: "#C0C0C0").opacity(0.5))
            }
            VStack(spacing: 6) {
                Text("暂无记录").font(.system(size: 19, weight: .medium)).foregroundColor(Color(hex: "#C0C0C0"))
                if hasActiveFilters {
                    Text("试试调整搜索条件").font(.system(size: 17)).foregroundColor(Color(hex: "#C0C0C0"))
                } else {
                    Text("点击底部「录入」开始记账").font(.system(size: 17)).foregroundColor(Color(hex: "#C0C0C0"))
                }
            }
            Spacer(minLength: 132)
        }.frame(maxWidth: .infinity)
    }
    
    @ViewBuilder private var expenseList: some View {
        ScrollViewReader { proxy in
            ScrollView {
            VStack(spacing: 12) {
                Color.clear.frame(height: 0)
                    .background(ScrollViewAccessor { sweepDriver.attach(to: $0) })
                ForEach(searchGrouped) { group in
                    MonthSectionCard(group: group)
                    VStack(spacing: 8) {
                        ForEach(group.expenses) { expense in
                            ExpenseRowView(expense: expense, isSelectionMode: showSearch, isSelected: selectedExpenseIds.contains(expense.id), onToggle: { toggleExpense(expense.id) }, onLongPress: {
                                if !showSearch { showSearch = true }
                                if let frame = rowFrames[expense.id] { fingerY = frame.midY }
                                sweepToggled = []
                                toggleExpense(expense.id)
                                sweepToggled.insert(expense.id)
                                sweepModeActive = true
                                let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred()
                            }, onLongPressStateChanged: { isPressing in
                                if !isPressing && sweepModeActive { sweepDriver.stop(); sweepModeActive = false; sweepToggled = [] }
                            })
                                .onTapGesture {
                                    if showSearch { toggleExpense(expense.id) }
                                    else { selectedExpense = expense; showDetail = true }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { pendingDeleteExpense = expense; showDeleteAlert = true } label: { Label("删除", systemImage: "trash") }
                                    Button { editingExpense = expense; showEdit = true } label: { Label("编辑", systemImage: "pencil") }.tint(AppTheme.brandStart)
                                    Button { selectedExpense = expense; showDetail = true } label: { Label("详情", systemImage: "info.circle") }.tint(.orange)
                                }
                        }
                    }.padding(.horizontal, 16)
                }
            }.padding(.top, 0).padding(.bottom, 12)
            }.scrollDismissesKeyboard(.immediately)
            .coordinateSpace(name: "expenseList")
            .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .named("expenseList"))
                    .onChanged { value in
                        guard showSearch else { return }
                        if sweepModeActive {
                            let dy = value.translation.height
                            if dy < -15, sweepDirectionDown {
                                sweepDirectionDown = false
                                sweepDriver.isActive = false
                                sweepDriver.scrollView?.isScrollEnabled = true
                            } else if dy > 10, !sweepDirectionDown {
                                sweepDirectionDown = true
                                sweepDriver.scrollView?.isScrollEnabled = false
                                sweepDriver.isActive = true
                            }
                            return
                        }
                        let now = Date()
                        if now.timeIntervalSince(lastScrollTime) > 0.2 {
                            if value.location.y > 500, let bottom = rowFrames.max(by: { $0.value.maxY < $1.value.maxY }) {
                                proxy.scrollTo(bottom.key, anchor: .bottom)
                                lastScrollTime = now
                            }
                        }
                    }
            )
            .onChange(of: sweepModeActive) { active in
                if active {
                    sweepDirectionDown = true
                    sweepDriver.start {
                        var batch: Set<UUID> = []
                        for (id, frame) in rowFrames {
                            let top = frame.minY - frame.height * 0.25
                            let bottom = frame.maxY + frame.height * 0.25
                            if fingerY >= top && fingerY <= bottom, !sweepToggled.contains(id) {
                                sweepToggled.insert(id)
                                batch.insert(id)
                            }
                        }
                        if !batch.isEmpty {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            for id in batch { toggleExpense(id) }
                        }
                    }
                } else {
                    sweepDriver.stop()
                    sweepToggled = []
                    sweepDirectionDown = true
                }
            }
            }
    }
    
}

// MARK: - 加载等待动画（波浪爪印）
struct RowFrameKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct PawPrintLoading: View {
    @State private var wave: Int = 0
    private let pawCount = 9
    private let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    private func pawColor(at index: Int) -> Color {
        let fraction = CGFloat(index) / CGFloat(max(pawCount - 1, 1))
        let r = 0.357 + (0.659 - 0.357) * fraction
        let g = 0.431 + (0.333 - 0.431) * fraction
        let b = 0.941 + (0.969 - 0.941) * fraction
        return Color(red: Double(r), green: Double(g), blue: Double(b))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(0..<pawCount, id: \.self) { i in
                    let dist = (wave - i + pawCount * 2) % (pawCount * 2)
                    let lit = dist < pawCount
                    PawIcon(filled: lit, active: lit && dist == pawCount - 1, gradientColor: pawColor(at: i))
                }
            }
            .onReceive(timer) { _ in
                wave = (wave + 1) % (pawCount * 2)
            }
            Text("正在加载...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.brandGradient)
        }
    }
}

// MARK: - 月份汇总卡片
struct MonthSectionCard: View {
    let group: MonthExpenseGroup
    var body: some View {
        HStack {
            Image(systemName: "calendar").font(.system(size: 14)).foregroundStyle(AppTheme.brandGradient)
            Text(group.monthDisplay).font(.system(size: 17, weight: .medium)).foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text(group.totalAmount > 0 ? "小计: +¥\(String(format: "%.2f", group.totalAmount))" : group.totalAmount < 0 ? "小计: -¥\(String(format: "%.2f", -group.totalAmount))" : "小计: ¥0.00").font(.system(size: 17, weight: .medium)).foregroundStyle(AppTheme.brandGradient)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(AppTheme.brandStart.opacity(0.06))
        .overlay(Rectangle().fill(AppTheme.brandStart.opacity(0.3)).frame(height: 1), alignment: .bottom)
    }
}

// MARK: - 名称搜索框
struct SearchNameField: View {
    @Binding var text: String
    var placeholder: String = "名称搜索..."
    @FocusState private var isFocused: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundColor(AppTheme.textTertiary.opacity(0.6))
            ZStack(alignment: .leading) {
                if text.isEmpty && !isFocused { Text(placeholder).font(.system(size: 17)).foregroundColor(Color(hex: "#B0B0B0")) }
                TextField("", text: $text).font(.system(size: 17)).foregroundColor(AppTheme.brandStart).autocorrectionDisabled().focused($isFocused).onSubmit { dismissKeyboard() }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10).background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
    }
}

// MARK: - 筛选标签
struct FilterChip: View {
    let label: String; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label).font(.system(size: 17)).foregroundStyle(isActive ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(hex: "#B0B0B0"))).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(isActive ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(hex: "#C0C0C0")))
            }
            .padding(.horizontal, 10).padding(.vertical, 8).frame(maxWidth: .infinity).background(Color.white).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isActive ? AppTheme.brandStart.opacity(0.4) : AppTheme.border, lineWidth: isActive ? 1.5 : 1))
        }
    }
}

// MARK: - 支出行视图
struct ExpenseRowView: View {
    let expense: Expense
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggle: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil
    var onLongPressStateChanged: ((Bool) -> Void)? = nil
    @State private var checkBounce: CGFloat = 1.0
    @State private var rowBounce: CGFloat = 1.0
    var categoryColor: Color { AppTheme.categoryColor(expense.category) }
    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Button(action: { onToggle?() }) {
                    ZStack {
                        Circle().stroke(isSelected ? AppTheme.brandStart : Color(hex: "#D0D0D0"), lineWidth: 2).frame(width: 22, height: 22)
                        if isSelected {
                            Circle().fill(AppTheme.brandStart).frame(width: 14, height: 14)
                                .scaleEffect(checkBounce)
                            Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            Circle().fill((expense.isExpense ? AppTheme.brandStart : Color.green).opacity(0.15)).frame(width: 44, height: 44).overlay(Text(expense.isExpense ? "支" : "收").font(.system(size: 21, weight: .semibold)).foregroundColor(expense.isExpense ? AppTheme.brandStart : .green))
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.merchant.count > 6 ? String(expense.merchant.prefix(6)) + "..." : expense.merchant).font(.appBodyMedium).foregroundColor(AppTheme.textPrimary).lineLimit(1)
                Text(expense.category).font(.system(size: 13)).foregroundColor(categoryColor).padding(.horizontal, 6).padding(.vertical, 2).background(categoryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                Text("\(dateRowFormatted(expense.date)) \(chineseWeekday(expense.date))").font(.appSmall).foregroundColor(AppTheme.textTertiary)
                if let note = expense.note, !note.isEmpty { Text(note).font(.appSmall).foregroundColor(AppTheme.textSecondary) }
            }
            Spacer()
            Text(expense.isExpense ? String(format: "-¥%.2f", expense.amount) : String(format: "+¥%.2f", expense.amount)).font(.appBodyMedium).foregroundColor(expense.isExpense ? AppTheme.textSecondary : .green)
            if !isSelectionMode {
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(AppTheme.textTertiary.opacity(0.5)).padding(.leading, 4)
            }
        }
        .padding(16).background(ZStack { Color.white; RecordWatermark(expense: expense) }).overlay(HStack(spacing: 0) { Rectangle().fill(expense.isExpense ? AppTheme.brandStart : .green).frame(width: 3); Spacer(minLength: 0) }.allowsHitTesting(false)).cornerRadius(12).shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .scaleEffect(rowBounce)
        .background(GeometryReader { geo in
            Color.clear.preference(key: RowFrameKey.self, value: [expense.id: geo.frame(in: .named("expenseList"))])
        })
        .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 50, perform: { onLongPress?() }, onPressingChanged: { isPressing in
            onLongPressStateChanged?(isPressing)
        })
        .onChange(of: isSelected) { newValue in
            checkBounce = 1.4
            rowBounce = 1.03
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 12)) {
                checkBounce = 1.0
            }
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 15)) {
                rowBounce = 1.0
            }
        }
    }
}

func dateRowFormatted(_ d: Date) -> String { let df = DateFormatter(); df.dateFormat = "MM-dd"; return df.string(from: d) }

func chineseWeekday(_ d: Date) -> String {
    let df = DateFormatter(); df.locale = Locale(identifier: "zh_CN"); df.dateFormat = "EEE"
    return df.string(from: d)
}

// MARK: - 年份滚轮选择器
struct YearWheelPicker: View {
    @Binding var selection: String; let options: [String]; @State private var tempSelection: String = ""; @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { dismiss() }.foregroundColor(AppTheme.textSecondary); Spacer()
                Text("选择年份").font(.appBody.weight(.semibold)).foregroundColor(AppTheme.textPrimary); Spacer()
                Button("确定") { selection = (tempSelection == "全部") ? "" : tempSelection; dismiss() }.foregroundStyle(AppTheme.brandGradient).fontWeight(.semibold)
            }.padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            Picker("年份", selection: $tempSelection) {
                ForEach(options, id: \.self) { yr in Text(yr == "全部" ? "全部年份" : yr).font(.system(size: 21, weight: .medium)).tag(yr) }
            }.pickerStyle(.wheel)
        }.background(.ultraThinMaterial).onAppear { tempSelection = selection.isEmpty ? (options.first ?? "") : selection }
    }
}

// MARK: - 月份滚轮选择器
struct MonthWheelPicker: View {
    @Binding var selection: String; let options: [String]; @State private var tempSelection: String = ""; @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { dismiss() }.foregroundColor(AppTheme.textSecondary); Spacer()
                Text("选择月份").font(.appBody.weight(.semibold)).foregroundColor(AppTheme.textPrimary); Spacer()
                Button("确定") { selection = (tempSelection == "全部") ? "" : tempSelection; dismiss() }.foregroundStyle(AppTheme.brandGradient).fontWeight(.semibold)
            }.padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            Picker("月份", selection: $tempSelection) {
                ForEach(options, id: \.self) { m in Text(m == "全部" ? "全部月份" : m).font(.system(size: 21, weight: .medium)).tag(m) }
            }.pickerStyle(.wheel)
        }.background(.ultraThinMaterial).onAppear { tempSelection = selection.isEmpty ? (options.first ?? "") : selection }
    }
}

// MARK: - 分类滚轮选择器
struct CategoryWheelPicker: View {
    @Binding var selection: String; let options: [String]; @State private var tempSelection: String = ""; @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { dismiss() }.foregroundColor(AppTheme.textSecondary); Spacer()
                Text("选择类型").font(.appBody.weight(.semibold)).foregroundColor(AppTheme.textPrimary); Spacer()
                Button("确定") { selection = (tempSelection == "全部") ? "" : tempSelection; dismiss() }.foregroundStyle(AppTheme.brandGradient).fontWeight(.semibold)
            }.padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            Picker("分类", selection: $tempSelection) {
                ForEach(options, id: \.self) { cat in Text(cat == "全部" ? "全部类别" : cat).font(.system(size: 21, weight: .medium)).tag(cat) }
            }.pickerStyle(.wheel)
        }.background(.ultraThinMaterial).onAppear { tempSelection = selection.isEmpty ? (options.first ?? "") : selection }
    }
}

struct BatchOperationSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    let selectedCount: Int
    @Binding var batchNoteText: String
    @Binding var batchNoteMode: NoteMode
    var onNoteConfirm: () -> Void
    var onDeleteConfirm: () -> Void
    var onDateConfirm: (Date) -> Void
    var onCategoryConfirm: (String) -> Void
    var onCancel: () -> Void
    var batchCategories: [String] = ["餐饮", "交通", "购物", "娱乐", "住房", "日用", "服饰", "通讯", "医疗", "教育", "其他"]

    @State private var showNoteSheet = false
    @State private var showDeleteAlert = false
    @State private var didProcess = false
    @State private var showDateSheet = false
    @State private var showCategorySheet = false
    private var isProcessing: Bool { supabaseService.batchProgress != nil }

    var body: some View {
        VStack(spacing: 20) {
            Text("批量操作").font(.title2.weight(.semibold)).foregroundColor(.white).padding(.top, 32)

            Text("已选 \(selectedCount) 条记录")
                .font(.subheadline).foregroundStyle(AppTheme.brandGradient)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(AppTheme.brandStart.opacity(0.08))
                .cornerRadius(8)

            // ── 操作列表 ──
            VStack(spacing: 10) {
                BatchOperationRow(icon: "pencil.and.list.clipboard", title: "修改备注") { if !isProcessing { showNoteSheet = true } }
                BatchOperationRow(icon: "calendar", title: "修改时间") { if !isProcessing { showDateSheet = true } }
                BatchOperationRow(icon: "tag", title: "修改类别") { if !isProcessing { showCategorySheet = true } }
                BatchOperationRow(icon: "trash", title: "批量删除", tint: .red) { if !isProcessing { showDeleteAlert = true } }
            }.padding(.horizontal)
            .opacity(isProcessing ? 0.5 : 1.0)
            .disabled(isProcessing)

            Spacer()

            if let bp = supabaseService.batchProgress, bp.1 > 0 {
                PawPrintProgress(current: bp.0, total: bp.1)
                    .padding(.horizontal)
            }

            Button(action: { if !isProcessing { onCancel() } }) {
                Text("关闭操作")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isProcessing ? AnyShapeStyle(Color.gray.opacity(0.5)) : AnyShapeStyle(AppTheme.brandGradient))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color.clear)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isProcessing ? Color.gray.opacity(0.3) : AppTheme.brandStart.opacity(0.5), lineWidth: 1.5))
            }
            .disabled(isProcessing)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial)
        
        .sheet(isPresented: $showNoteSheet) {
            BatchNoteSheet(selectedCount: selectedCount, batchNoteText: $batchNoteText, batchNoteMode: $batchNoteMode, onConfirm: onNoteConfirm, onCancel: { showNoteSheet = false })
        }
        .sheet(isPresented: $showCategorySheet) {
            BatchCategorySheet(selectedCount: selectedCount, categories: batchCategories, onConfirm: { cat in onCategoryConfirm(cat) }, onCancel: { showCategorySheet = false })
        }
        .sheet(isPresented: $showDateSheet) {
            BatchDatePickerSheet(selectedCount: selectedCount, onConfirm: { date in onDateConfirm(date) }, onCancel: { showDateSheet = false })
        }
        .alert("批量删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) { didProcess = true; onDeleteConfirm() }
        } message: {
            Text("是否确定删除已选的 \(selectedCount) 条记录？")
        }
        .onChange(of: isProcessing) { processing in if processing { didProcess = true } else if didProcess { onCancel(); didProcess = false } }
        .onChange(of: showNoteSheet) { showing in if !showing && didProcess { onCancel(); didProcess = false } }
        .onChange(of: showDateSheet) { showing in if !showing && didProcess { onCancel(); didProcess = false } }
        .onChange(of: showCategorySheet) { showing in if !showing && didProcess { onCancel(); didProcess = false } }
    }
}

// MARK: - 批量操作菜单行
struct BatchOperationRow: View {
    let icon: String
    let title: String
    var tint: Color = AppTheme.brandStart
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).font(.system(size: 17)).foregroundColor(.white).frame(width: 24)
                Text(title).font(.system(size: 17, weight: .medium)).foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 17, weight: .semibold)).foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 14).padding(.horizontal, 16)
            .background(AppTheme.brandGradient).cornerRadius(12)
            .shadow(color: AppTheme.brandShadow, radius: 6, x: 0, y: 3)
        }
    }
}

// MARK: - 批量修改备注子 Sheet
struct BatchNoteSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    @State private var isProcessing = false
    let selectedCount: Int
    @Binding var batchNoteText: String
    @Binding var batchNoteMode: NoteMode
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    Text("修改备注").font(.title2.weight(.semibold)).padding(.top, 32)
                    Text("已选 \(selectedCount) 条记录")
                        .font(.subheadline).foregroundStyle(AppTheme.brandGradient)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(AppTheme.brandStart.opacity(0.08))
                        .cornerRadius(8)

                    TextEditor(text: $batchNoteText)
                        .byteLimited($batchNoteText, max: 200)
                        .font(.system(size: 18))
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#666666"), lineWidth: 1))
                        .padding(.horizontal)

                    HStack {
                        if batchNoteText.utf8.count > 200 {
                            Text("您的输入已超上限!")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.brandGradient)
                        }
                        Spacer()
                        Text("\(batchNoteText.utf8.count)/200")
                            .font(.system(size: 12))
                            .foregroundStyle(batchNoteText.utf8.count > 200 ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(hex: "#888888")))
                    }
                    .padding(.horizontal)

                    Picker("模式", selection: $batchNoteMode) {
                        Text("替换").tag(NoteMode.replace)
                        Text("追加").tag(NoteMode.append)
                    }.pickerStyle(.segmented).padding(.horizontal)

                    HStack(spacing: 16) {
                        Button(action: { if !isProcessing { onCancel() } }) {
                            Text("取消修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(isProcessing ? AppTheme.textTertiary : AppTheme.brandStart)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.clear).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isProcessing ? AppTheme.textTertiary.opacity(0.3) : AppTheme.brandStart.opacity(0.5), lineWidth: 1.5))
                        }
                        .disabled(isProcessing)
                        Button(action: { isProcessing = true; onConfirm() }) {
                            Text(isProcessing ? "处理中..." : "确认修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(AppTheme.brandGradient).cornerRadius(8)
                                .shadow(color: AppTheme.brandShadow, radius: 6, x: 0, y: 3)
                        }
                        .disabled(batchNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                    }.padding(.horizontal)
                    .task(id: supabaseService.batchProgress?.0) {
                        if supabaseService.batchProgress == nil && isProcessing { dismiss() }
                    }

                    Spacer()
                }
                .opacity(isProcessing ? 0.4 : 1.0)
                .disabled(isProcessing)

                if isProcessing {
                    VStack(spacing: 12) {
                        if let bp = supabaseService.batchProgress, bp.1 > 0 {
                            PawPrintProgress(current: bp.0, total: bp.1)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
            .navigationBarHidden(true)
            
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { dismissKeyboard() }
                        .foregroundStyle(AppTheme.brandGradient)
                }
            }
        }
    }
}

// MARK: - 批量修改月份 Sheet
// MARK: - 批量修改时间 Sheet
struct BatchDatePickerSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    @State private var isProcessing = false
    let selectedCount: Int
    var onConfirm: (Date) -> Void
    var onCancel: () -> Void

    @State private var selectedDate = Date()

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    Text("修改时间").font(.title2.weight(.semibold)).padding(.top, 32)
                    Text("已选 \(selectedCount) 条记录")
                        .font(.subheadline).foregroundStyle(AppTheme.brandGradient)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(AppTheme.brandStart.opacity(0.08))
                        .cornerRadius(8)
                    Spacer()

                    Text(selectedDate, format: .dateTime.weekday(.abbreviated))
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 4) {
                        HStack {
                            Text("日期").font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.textSecondary).frame(width: 36, alignment: .leading)
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "zh_CN"))
                                .disabled(isProcessing)
                        }
                        HStack {
                            Text("时间").font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.textSecondary).frame(width: 36, alignment: .leading)
                            DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "zh_CN"))
                                .disabled(isProcessing)
                        }
                    }
                    .padding(.horizontal, 8)

                    Spacer()

                    HStack(spacing: 16) {
                        Button(action: { if !isProcessing { onCancel() } }) {
                            Text("取消修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(isProcessing ? AppTheme.textTertiary : AppTheme.brandStart)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.clear).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isProcessing ? AppTheme.textTertiary.opacity(0.3) : AppTheme.brandStart.opacity(0.5), lineWidth: 1.5))
                        }
                        .disabled(isProcessing)
                        Button(action: { isProcessing = true; onConfirm(selectedDate) }) {
                            Text(isProcessing ? "修改中..." : "确认修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(AppTheme.brandGradient).cornerRadius(8)
                                .shadow(color: AppTheme.brandShadow, radius: 6, x: 0, y: 3)
                        }
                        .disabled(isProcessing)
                    }.padding(.horizontal, 20)
                }
                .opacity(isProcessing ? 0.4 : 1.0)
                .disabled(isProcessing)
                if isProcessing {
                    VStack(spacing: 12) {
                        if let bp = supabaseService.batchProgress, bp.1 > 0 {
                            PawPrintProgress(current: bp.0, total: bp.1)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
            .navigationBarHidden(true)
            .presentationDetents([.height(520)])
            .task(id: supabaseService.batchProgress?.0) {
                if supabaseService.batchProgress == nil && isProcessing { dismiss() }
            }
        }
    }
}

struct BatchMonthSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    @State private var isProcessing = false
    let selectedCount: Int
    var onConfirm: (String) -> Void
    var onCancel: () -> Void

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())

    private let years: [Int] = Array(2024...Calendar.current.component(.year, from: Date()))
    private let months: [Int] = Array(1...12)

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    Text("修改月份").font(.title2.weight(.semibold)).padding(.top, 32)
                    Text("已选 \(selectedCount) 条记录")
                        .font(.subheadline).foregroundStyle(AppTheme.brandGradient)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(AppTheme.brandStart.opacity(0.08))
                        .cornerRadius(8)

                    HStack(spacing: 0) {
                        Picker("年", selection: $selectedYear) {
                            ForEach(years, id: \.self) { y in
                                Text("\(String(y))年").font(.system(size: 21, weight: .medium)).tag(y)
                            }
                        }.pickerStyle(.wheel).frame(width: 120)
                        Picker("月", selection: $selectedMonth) {
                            ForEach(months, id: \.self) { m in
                                Text(String(format: "%02d月", m)).font(.system(size: 21, weight: .medium)).tag(m)
                            }
                        }.pickerStyle(.wheel).frame(width: 120)
                    }

                    Spacer()

                    HStack(spacing: 16) {
                        Button(action: { if !isProcessing { onCancel() } }) {
                            Text("取消修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(isProcessing ? AppTheme.textTertiary : AppTheme.brandStart)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.clear).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isProcessing ? AppTheme.textTertiary.opacity(0.3) : AppTheme.brandStart.opacity(0.5), lineWidth: 1.5))
                        }
                        .disabled(isProcessing)
                        Button(action: { isProcessing = true
                            let monthStr = "\(String(selectedYear))年\(String(format: "%02d月", selectedMonth))"
                            onConfirm(monthStr)
                        }) {
                            Text(isProcessing ? "处理中..." : "确认修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(AppTheme.brandGradient).cornerRadius(8)
                                .shadow(color: AppTheme.brandShadow, radius: 6, x: 0, y: 3)
                        }
                        .disabled(isProcessing)
                    }.padding(.horizontal)
                    .task(id: supabaseService.batchProgress?.0) {
                        if supabaseService.batchProgress == nil && isProcessing { dismiss() }
                    }
                }
                .frame(maxHeight: .infinity)
                .opacity(isProcessing ? 0.4 : 1.0)
                .disabled(isProcessing)

                if isProcessing {
                    VStack(spacing: 12) {
                        if let bp = supabaseService.batchProgress, bp.1 > 0 {
                            PawPrintProgress(current: bp.0, total: bp.1)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
            .navigationBarHidden(true)
            .presentationDetents([.height(620)])
        }
    }
}


// MARK: - 批量修改类别 Sheet
struct BatchCategorySheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    @State private var isProcessing = false
    let selectedCount: Int
    let categories: [String]
    var onConfirm: (String) -> Void
    var onCancel: () -> Void

    @State private var selectedCategory: String = "餐饮"

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    Text("修改类别").font(.title2.weight(.semibold)).padding(.top, 32)
                    Text("已选 \(selectedCount) 条记录")
                        .font(.subheadline).foregroundColor(AppTheme.brandStart)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(AppTheme.brandStart.opacity(0.08))
                        .cornerRadius(8)
                    Spacer()
                    Picker("类别", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).font(.system(size: 21, weight: .medium)).tag(cat)
                        }
                    }.pickerStyle(.wheel).frame(height: 520)
                    Spacer()
                    HStack(spacing: 16) {
                        Button(action: { if !isProcessing { onCancel() } }) {
                            Text("取消修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(isProcessing ? AppTheme.textTertiary : AppTheme.brandStart)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.clear).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isProcessing ? AppTheme.textTertiary.opacity(0.3) : AppTheme.brandStart.opacity(0.5), lineWidth: 1.5))
                        }.disabled(isProcessing)
                        Button(action: { isProcessing = true; onConfirm(selectedCategory) }) {
                            Text(isProcessing ? "处理中..." : "确认修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(AppTheme.brandGradient).cornerRadius(8)
                                .shadow(color: AppTheme.brandShadow, radius: 6, x: 0, y: 3)
                        }.disabled(isProcessing)
                    }.padding(.horizontal)
                     .task(id: supabaseService.batchProgress?.0) {
                         if supabaseService.batchProgress == nil && isProcessing { dismiss() }
                     }
                }
                .opacity(isProcessing ? 0.4 : 1.0)
                .disabled(isProcessing)
                if isProcessing {
                    VStack(spacing: 12) {
                        if let bp = supabaseService.batchProgress, bp.1 > 0 {
                            PawPrintProgress(current: bp.0, total: bp.1)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct PawPrintProgress: View {
    let current: Int
    let total: Int
    private let pawCount = 9

    private func pawColor(at index: Int) -> Color {
        let fraction = CGFloat(index) / CGFloat(max(pawCount - 1, 1))
        let startColor = UIColor(red: 0.357, green: 0.431, blue: 0.941, alpha: 1.0)
        let endColor = UIColor(red: 0.659, green: 0.333, blue: 0.969, alpha: 1.0)
        var sH: CGFloat = 0, sS: CGFloat = 0, sB: CGFloat = 0, sA: CGFloat = 0
        var eH: CGFloat = 0, eS: CGFloat = 0, eB: CGFloat = 0, eA: CGFloat = 0
        startColor.getHue(&sH, saturation: &sS, brightness: &sB, alpha: &sA)
        endColor.getHue(&eH, saturation: &eS, brightness: &eB, alpha: &eA)
        let h = sH + (eH - sH) * fraction
        let s = sS + (eS - sS) * fraction
        let b = sB + (eB - sB) * fraction
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(b))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<pawCount, id: \.self) { i in
                    let threshold = (i + 1) * total / pawCount
                    PawIcon(
                        filled: current >= threshold,
                        active: current > i * total / pawCount && current < threshold,
                        gradientColor: pawColor(at: i)
                    )
                }
            }
            Text("正在处理 \(current)/\(total) 条记录...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.brandGradient)
        }
    }
}

struct PawIcon: View {
    let filled: Bool
    let active: Bool
    let gradientColor: Color
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            Ellipse().frame(width: 9, height: 6.5).offset(y: 3.5)
            Circle().frame(width: 4.5, height: 4.5).offset(x: -4.5, y: -1.5)
            Circle().frame(width: 4.5, height: 4.5).offset(y: -3.2)
            Circle().frame(width: 4.5, height: 4.5).offset(x: 4.5, y: -1.5)
        }
        .foregroundColor(filled ? gradientColor : gradientColor.opacity(0.15))
        .shadow(color: filled ? gradientColor.opacity(0.35) : .clear, radius: 3, x: 0, y: 1.5)
        .scaleEffect(active ? pulse : 1.0)
        .rotationEffect(.degrees(90))
        .offset(y: active ? -3 : 0)
        .onAppear { if active { withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { pulse = 1.35 } } }
    }
}

// MARK: - 连续滚动驱动器（CADisplayLink）
final class SweepScrollDriver: NSObject {
    weak var scrollView: UIScrollView?
    var onTick: (() -> Void)?
    var speed: CGFloat = 185
    private var displayLink: CADisplayLink?
    private var wasScrollEnabled = true

    func attach(to scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    func start(onTick: @escaping () -> Void) {
        self.onTick = onTick
        wasScrollEnabled = scrollView?.isScrollEnabled ?? true
        scrollView?.isScrollEnabled = false
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    var isActive = true

    @objc private func tick() {
        guard isActive, let sv = scrollView else { return }
        sv.contentOffset.y += speed / 60.0
        onTick?()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        scrollView?.isScrollEnabled = wasScrollEnabled
        isActive = true
        onTick = nil
    }
}

// MARK: - 捕获 ScrollView 的底层 UIScrollView
struct ScrollViewAccessor: UIViewRepresentable {
    let onScrollView: (UIScrollView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            var current: UIView? = view
            while current != nil {
                if let sv = current as? UIScrollView {
                    onScrollView(sv)
                    break
                }
                current = current?.superview
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var current: UIView? = uiView
            while current != nil {
                if let sv = current as? UIScrollView {
                    onScrollView(sv)
                    break
                }
                current = current?.superview
            }
        }
    }
}
