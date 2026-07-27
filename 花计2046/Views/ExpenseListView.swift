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
    
    @State private var showShareSheet = false
    @State private var isExporting = false
    @State private var exportURL: URL?
    
    var categories: [String] {
        // 从数据库中提取有数据的类别，支出在上、收入在下
        let allExpenseCats = Set(supabaseService.allRecords.filter(\.isExpense).map(\.category))
        let allIncomeCats = Set(supabaseService.allRecords.filter(\.isIncome).map(\.category))
        let matchedExpense = CategoryManager.expenseCats.filter { allExpenseCats.contains($0) }
        let matchedIncome = CategoryManager.incomeCats.filter { allIncomeCats.contains($0) }
        let hasData = !allExpenseCats.isEmpty || !allIncomeCats.isEmpty
        
        switch supabaseService.sharedSearchType {
        case "支出":
            if hasData { return ["全部"] + matchedExpense }
            return ["全部"] + CategoryManager.expenseCats
        case "收入":
            if hasData { return ["全部"] + matchedIncome }
            return ["全部"] + CategoryManager.incomeCats
        default:
            if hasData { return ["全部"] + matchedExpense + matchedIncome }
            return ["全部"] + CategoryManager.expenseCats + CategoryManager.incomeCats
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
            e.matchesSearch(
                searchText: supabaseService.sharedSearchText,
                searchNote: supabaseService.sharedSearchNote,
                searchCategory: supabaseService.sharedSearchCategory,
                searchYear: supabaseService.sharedSearchYear,
                searchMonth: supabaseService.sharedSearchMonth
            )
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                   Button(action: {
                       let exportCount = searchGrouped.flatMap(\.expenses).count
                       Task.detached {
                           let url = CSVExporter.exportCSV(records: searchGrouped.flatMap(\.expenses))
                           await MainActor.run {
                               exportURL = url
                               showShareSheet = true
                               isExporting = false
                           }
                       }
                       Task { await UserLogManager.log(action: "导出", detail: "导出(\(exportCount))", supabaseService: supabaseService) }
                       isExporting = true
                    }) {
                        Label(isExporting ? "生成中..." : "导出当前账本", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isExporting)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.textSecondary)
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
                        Task {
                            try? await supabaseService.deleteExpense(expense)
                            await UserLogManager.log(action: "删除", detail: "删除(1)", supabaseService: supabaseService)
                        }
                    }
                    pendingDeleteExpense = nil
                }
            } message: { Text("是否确定删除该笔账单？") }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showYearPicker) { YearWheelPicker(selection: $supabaseService.sharedSearchYear, options: yearOptions).presentationDetents([.height(230)]) }
        .sheet(isPresented: $showMonthPicker) { MonthWheelPicker(selection: $supabaseService.sharedSearchMonth, options: monthOptions).presentationDetents([.height(270)]) }
        .sheet(isPresented: $showCategoryPicker) { CategoryWheelPicker(selection: $supabaseService.sharedSearchCategory, options: categories).presentationDetents([.height(230)]) }
   .sheet(isPresented: $showBatchNoteSheet) { BatchOperationSheet(selectedCount: allSelected.count, batchNoteText: $batchNoteText, batchNoteMode: $batchNoteMode, onNoteConfirm: { let count = allSelected.count; Task { try? await supabaseService.batchUpdateNote(expenses: allSelected, note: batchNoteText, mode: batchNoteMode); await UserLogManager.log(action: "批量修改", detail: "批量修改备注(\(count))", supabaseService: supabaseService); selectedExpenseIds = [] } }, onDeleteConfirm: { let count = selectedExpenseIds.count; Task { try? await supabaseService.batchDeleteExpenses(ids: Array(selectedExpenseIds)); await UserLogManager.log(action: "批量删除", detail: "批量删除(\(count))", supabaseService: supabaseService); selectedExpenseIds = [] } }, onDateConfirm: { date in let count = allSelected.count; Task { try? await supabaseService.batchUpdateTime(expenses: allSelected, date: date); await UserLogManager.log(action: "批量修改", detail: "批量修改时间(\(count))", supabaseService: supabaseService); selectedExpenseIds = [] } }, onCurrencyConfirm: { sym in let count = allSelected.count; Task { try? await supabaseService.batchUpdateCurrency(expenses: allSelected, currencySymbol: sym); await UserLogManager.log(action: "批量修改", detail: "批量修改货币(\(count))", supabaseService: supabaseService); selectedExpenseIds = [] } }, onCategoryConfirm: { cat in let count = allSelected.count; Task { try? await supabaseService.batchUpdateCategory(expenses: allSelected, category: cat); await UserLogManager.log(action: "批量修改", detail: "批量修改类别(\(count))", supabaseService: supabaseService); selectedExpenseIds = [] } }, onCancel: { showBatchNoteSheet = false }) }
    .sheet(isPresented: $showShareSheet) {
        if let url = exportURL {
            ShareSheet(items: [url])
        }
    }
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
                SearchNameField(text: $supabaseService.sharedSearchText, placeholder: "搜索名称...")
                    .byteLimited($supabaseService.sharedSearchText, max: 50)
                SearchNameField(text: $supabaseService.sharedSearchNote, placeholder: "搜索备注...")
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
