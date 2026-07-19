import SwiftUI

struct ManualEntryRow: Identifiable {
    let id = UUID()
    var type: RecordType = .expense
    var merchant: String = ""
    var category: String = "餐饮"
    var amount: String = ""
    var note: String = ""
}

struct ManualEntryView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    
    @Binding var rows: [ManualEntryRow]
    var onDiscard: (() -> Void)?
    var onSuccess: (() -> Void)?
    @State private var isSaving = false
    @State private var showDeleteAlert = false
    @State private var pendingDeleteId: UUID?
    @State private var showDiscardAlert = false
    @State private var errorMessage = ""
    @State private var hasInitialized = false
    @State private var editingIndex: Int? = nil
    @State private var editType: RecordType = .expense
    @State private var editMerchant: String = ""
    @State private var editAmount: String = ""
    @State private var editCategory: String = ""
    @State private var editNote: String = ""
    @State private var showEditCategoryPicker = false
    @State private var isNewRow = false
    @State private var typeHistory: [UUID: [RecordType: String]] = [:]
    @State private var batchType: RecordType?
    @State private var originalRows: [ManualEntryRow]?
    @State private var editCategoryByType: [RecordType: String] = [:]
    
    private let categories = ["餐饮", "交通", "购物", "娱乐", "住房", "日用", "服饰", "通讯", "医疗", "教育", "其他"]
    private let expenseCategories = ["餐饮","交通","购物","娱乐","住房","日用","服饰","通讯","医疗","教育","其他"]
    private let incomeCategories = ["工资","奖金","兼职","投资收益","理财","礼金","退款","其他"]
    
    private var validCount: Int { rows.filter { !$0.amount.isEmpty }.count }
    private var totalAmount: Double { rows.compactMap { Double($0.amount) }.reduce(0, +) }
    private var incomeTotal: Double { rows.filter { $0.type == .income }.compactMap { Double($0.amount) }.reduce(0, +) }
    private var expenseTotal: Double { rows.filter { $0.type == .expense }.compactMap { Double($0.amount) }.reduce(0, +) }
    private var incomeCount: Int { rows.filter { $0.type == .income && (!$0.merchant.isEmpty || !$0.amount.isEmpty) }.count }
    private var expenseCount: Int { rows.filter { $0.type == .expense && (!$0.merchant.isEmpty || !$0.amount.isEmpty) }.count }
    
    var body: some View {
        ZStack {
            NavigationView {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("记账统计").font(.system(size: 17, weight: .bold)).foregroundColor(AppTheme.textPrimary)
                        if validCount > 0 {
                            HStack(spacing: 12) {
                                if incomeTotal > 0 { Text("收入 ¥\(String(format: "%.2f", incomeTotal))").font(.appBodyMedium).foregroundColor(.green) }
                                if expenseTotal > 0 { Text("支出 ¥\(String(format: "%.2f", expenseTotal))").font(.appBodyMedium).foregroundColor(AppTheme.brandStart) }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(20).background(Color.white)
                
                AppDivider()
                

                
                ScrollView {
                    VStack(spacing: 8) {
                        Color.clear.frame(height: 4)
                        ForEach(rows.indices, id: \.self) { index in
                            rowCardView(at: index)
                        }
                        
                        Button(action: {
                            guard rows.count < 50 else { return }
                            let cat = rows.last?.category ?? "餐饮"
                            let typ = rows.last?.type ?? .expense
                            isNewRow = true
                            editingIndex = rows.count
                            editType = typ; editMerchant = ""; editAmount = ""; editCategory = cat; editNote = ""
                        }) {
                            let atMax = rows.count >= 50
                            HStack {
                                Image(systemName: "plus.circle.fill").font(.system(size: 17))
                                Text("添加一条 (\(rows.count)/50)").font(.system(size: 17))
                            }
                            .foregroundColor(atMax ? AppTheme.textTertiary : AppTheme.brandStart)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .disabled(rows.count >= 50)
                        .padding(.horizontal, 12)
                    }
                    .padding(.bottom, 170)
                }
                .scrollDismissesKeyboard(.immediately)
                
                AppDivider()
                HStack(spacing: 4) {
                    HStack(spacing: 6) {
                        if incomeCount > 0 {
                            Text("收入\(incomeCount)笔")
                                .frame(minWidth: 64, alignment: .leading)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.green)
                        }
                        if expenseCount > 0 {
                            Text("支出\(expenseCount)笔")
                                .frame(minWidth: 64, alignment: .leading)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(AppTheme.brandStart)
                        }
                    }
                    Spacer()
                    if batchType != nil {
                        Button(action: {
                            if let saved = originalRows { rows = saved }
                            originalRows = nil; batchType = nil
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle").font(.system(size: 13, weight: .bold))
                                Text("取消").font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "#C0C0C0"))
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#D0D0D0"), lineWidth: 1))
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Button(action: {
                            if originalRows == nil { originalRows = rows.map { $0 } }
                            for i in rows.indices { var h = typeHistory[rows[i].id, default: [:]]; h[rows[i].type] = rows[i].category; typeHistory[rows[i].id] = h }
                            for i in rows.indices {
                                rows[i].type = .income
                                let incCats = ["工资","奖金","兼职","投资收益","理财","礼金","退款","其他"]
                                let saved = typeHistory[rows[i].id]?[.income]
                                if let s = saved, incCats.contains(s) { rows[i].category = s }
                                else if !incCats.contains(rows[i].category) { rows[i].category = "工资" }
                            }
                            batchType = .income
                        }) {
                            Text("转收入").font(.system(size: 13, weight: .medium))
                                .foregroundColor(batchType == .income ? .white : Color(hex: "#C0C0C0"))
                                .padding(.horizontal, 10).padding(.vertical, 6).frame(minWidth: 52)
                                .background(batchType == .income ? Color.green : Color(hex: "#E8E8E8"))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .disabled(validCount == 0)
                        
                        Button(action: {
                            if originalRows == nil { originalRows = rows.map { $0 } }
                            for i in rows.indices { var h = typeHistory[rows[i].id, default: [:]]; h[rows[i].type] = rows[i].category; typeHistory[rows[i].id] = h }
                            for i in rows.indices {
                                rows[i].type = .expense
                                let expCats = ["餐饮","交通","购物","娱乐","住房","日用","服饰","通讯","医疗","教育","其他"]
                                let saved = typeHistory[rows[i].id]?[.expense]
                                if let s = saved, expCats.contains(s) { rows[i].category = s }
                                else if !expCats.contains(rows[i].category) { rows[i].category = "餐饮" }
                            }
                            batchType = .expense
                        }) {
                            Text("转支出").font(.system(size: 13, weight: .medium))
                                .foregroundColor(batchType == .expense ? .white : Color(hex: "#C0C0C0"))
                                .padding(.horizontal, 10).padding(.vertical, 6).frame(minWidth: 52)
                                .background(batchType == .expense ? AppTheme.brandStart : Color(hex: "#E8E8E8"))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .disabled(validCount == 0)
                    }
                    
                }
                .padding(.horizontal, 20).padding(.vertical, 6)
                .opacity(validCount > 0 || batchType != nil ? 1 : 0)
                .allowsHitTesting(validCount > 0 || batchType != nil)
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(AppTheme.brandEnd)
                        .font(.appSmall)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        let hasContent = rows.contains { !$0.merchant.isEmpty || !$0.amount.isEmpty || !$0.note.isEmpty }
                        if hasContent { showDiscardAlert = true } else { onDiscard?() }
                    }) { Text("放弃").frame(maxWidth: .infinity) }.buttonStyle(AppSecondaryButtonStyle()).disabled(isSaving)
                    Button(action: saveAll) { Text(isSaving ? "保存中..." : "进账").frame(maxWidth: .infinity) }.buttonStyle(AppPrimaryButtonStyle()).disabled(isSaving)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
            .onChange(of: rows.map(\.type)) { newTypes in
                guard let batch = batchType else { return }
                guard let original = originalRows else { return }
                let mismatchIndices = newTypes.indices.filter { newTypes[$0] != batch }
                guard !mismatchIndices.isEmpty else { return }
                batchType = nil
                for i in mismatchIndices {
                    guard i < original.count, i < rows.count else { continue }
                    rows[i].type = original[i].type
                    rows[i].category = original[i].category
                }
            }
            .frame(maxHeight: .infinity)
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil").font(.system(size: 17, weight: .regular)).foregroundColor(AppTheme.brandStart)
                        Text("手动记账").font(.system(size: 17, weight: .bold)).foregroundColor(AppTheme.textPrimary)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { dismissKeyboard() }.foregroundColor(AppTheme.brandStart) }
            }
        }
        .background(AppTheme.background)
        .onAppear { autoOpenEditor() }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { pendingDeleteId = nil }
            Button("确认删除", role: .destructive) {
                if let id = pendingDeleteId { rows.removeAll { $0.id == id }; if rows.isEmpty { rows.append(ManualEntryRow()) } }
                pendingDeleteId = nil
            }
        } message: { Text("是否确认删除该项内容？") }
        .alert("确认放弃", isPresented: $showDiscardAlert) {
            Button("取消", role: .cancel) { }
            Button("确认放弃", role: .destructive) { onDiscard?() }
        } message: { Text("是否确认放弃本次录入内容？") }
            if editingIndex != nil {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { cancelEdit() }
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 0) {
                       // 标题
                       HStack(spacing: 6) {
                           Image(systemName: "square.and.pencil")
                               .font(.system(size: 17))
                               .foregroundColor(AppTheme.textTertiary.opacity(0.5))
                           Text("编辑记录")
                               .font(.system(size: 17, weight: .bold))
                               .foregroundColor(AppTheme.textPrimary)
                       }
                       .frame(maxWidth: .infinity).padding(.top, 16)
                       .padding(.bottom, 12)
                        AppDivider().padding(.horizontal, 16)
                        
                        ScrollView {
                            VStack(spacing: 10) {
                                // 类型切换 - 每个按钮独立背景
                                HStack(spacing: 0) {
                                    Button(action: { withAnimation(.easeInOut(duration: 0.15)) { editCategoryByType[editType] = editCategory; editType = .income; editCategory = editCategoryByType[.income] ?? "工资" } }) {
                                        Text("收入")
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundColor(editType == .income ? .white : .green)
                                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                                            .background(editType == .income ? Color.green : Color.clear)
                                            .cornerRadius(6)
                                    }
                                    Button(action: { withAnimation(.easeInOut(duration: 0.15)) { editCategoryByType[editType] = editCategory; editType = .expense; editCategory = editCategoryByType[.expense] ?? "餐饮" } }) {
                                        Text("支出")
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundColor(editType == .expense ? .white : AppTheme.brandStart)
                                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                                            .background(editType == .expense ? AppTheme.brandStart : Color.clear)
                                            .cornerRadius(6)
                                    }
                                }
                                .background(AppTheme.background)
                                .cornerRadius(7)
                                                                // 类别
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("类别")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)
                                    Button(action: { showEditCategoryPicker = true }) {
                                        HStack {
                                            Text(editCategory)
                                                .font(.system(size: 17))
                                                .foregroundColor(editType == .expense ? AppTheme.brandStart : .green)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(AppTheme.textTertiary)
                                        }
                                        .padding(.horizontal, 12).padding(.vertical, 9)
                                        .background(Color.white)
                                        .cornerRadius(7)
                                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                                    }
                                }
                                
                                // 名称
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("名称")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)
                                    KeyboardDoneTextField(text: $editMerchant, placeholder: "输入名称")
                                       .padding(.horizontal, 12).padding(.vertical, 9)
                                       .background(Color.white)
                                        .cornerRadius(7)
                                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                                        .onChange(of: editMerchant) {
                                            let s = ($0 ?? ""); if s.utf8.count > 50 { editMerchant = String(s.prefix(50)) }
                                        }
                                        .toolbar {
                                            ToolbarItemGroup(placement: .keyboard) {
                                                Spacer()
                                                Button("完成") { dismissKeyboard() }
                                                    .foregroundColor(AppTheme.brandStart)
                                            }
                                        }
                                }
                                
                               // 金额
                               VStack(alignment: .leading, spacing: 4) {
                                   Text("金额")
                                       .font(.system(size: 17, weight: .medium))
                                       .foregroundColor(AppTheme.textSecondary)
                                   HStack(spacing: 6) {
                                       Text("¥").font(.system(size: 17, weight: .medium)).foregroundColor(AppTheme.textTertiary)
                                       AmountTextField(amount: editAmountBinding, font: .systemFont(ofSize: 17), textColor: editType == .income ? UIColor.systemGreen : UIColor(AppTheme.textSecondary))
                                           .frame(maxWidth: .infinity)
                                   }
                                   .padding(.horizontal, 12).padding(.vertical, 9)
                                   .background(Color.white)
                                   .cornerRadius(7)
                                   .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                               }
                               
                               // 备注
                               VStack(alignment: .leading, spacing: 4) {
                                   Text("备注")
                                       .font(.system(size: 17, weight: .medium))
                                       .foregroundColor(AppTheme.textSecondary)
                                 KeyboardDoneTextEditor(text: $editNote)
                                     .frame(minHeight: 72)
                                     .onChange(of: editNote) {
                                          let s = ($0 ?? ""); if s.utf8.count > 200 { editNote = String(s.prefix(200)) }
                                      }
                               }


                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }

                        
                        
                        AppDivider().padding(.horizontal, 16)
                        
                        HStack(spacing: 10) {
                            Button(action: { cancelEdit() }) {
                                Text("取消")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(Color.white)
                                    .cornerRadius(7)
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                            }
                            Button(action: { confirmEdit() }) {
                                Text("保存")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(AppTheme.brandGradient)
                                    .cornerRadius(7)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    .frame(width: UIScreen.main.bounds.width - 56)
                    .frame(maxHeight: 410)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showEditCategoryPicker) {
            if editingIndex != nil {
                CategoryWheelPicker(selection: $editCategory, options: editType == .expense ? expenseCategories : incomeCategories)
                    .presentationDetents([.height(260)])
            }
        }
    }
    
    
    private func cancelEdit() {
        isNewRow = false
        editingIndex = nil
    }

    private func autoOpenEditor() {
        guard !hasInitialized else { return }
        hasInitialized = true
        let hasData = rows.contains { !$0.merchant.isEmpty || !$0.amount.isEmpty }
        if !hasData {
            editingIndex = 0
            editType = rows.first?.type ?? .expense
            editMerchant = rows.first?.merchant ?? ""
            editAmount = rows.first?.amount ?? ""
            editCategory = rows.first?.category ?? "餐饮"
            editNote = rows.first?.note ?? ""
            isNewRow = true
        }
    }
    private func confirmEdit() {
        if isNewRow {
            var r = ManualEntryRow()
            r.type = editType; r.merchant = editMerchant; r.amount = editAmount
            r.category = editCategory; r.note = editNote
            rows.append(r)
        } else if let idx = editingIndex, idx < rows.count {
            let oldType = rows[idx].type
            rows[idx].type = editType; rows[idx].merchant = editMerchant; rows[idx].amount = editAmount
            rows[idx].category = editCategory; rows[idx].note = editNote
            if oldType != editType {
                var h = typeHistory[rows[idx].id, default: [:]]
                h[oldType] = rows[idx].category
                typeHistory[rows[idx].id] = h
            }
        }
        isNewRow = false
        editingIndex = nil
    }
    
    @ViewBuilder
    private func rowCardView(at index: Int) -> some View {
        let row = rows[index]
        let typeColor: Color = row.type == .expense ? AppTheme.brandStart : .green
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 16))
                .foregroundColor(typeColor.opacity(0.5))
            Text(row.type == .expense ? "支" : "收")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(typeColor)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(row.merchant.isEmpty ? "未命名" : row.merchant)
                    .font(.appBodyMedium).foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(row.category)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.categoryColor(row.category))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(AppTheme.categoryColor(row.category).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }
                if !row.note.isEmpty {
                    Text(row.note)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            let amtStr = row.amount.isEmpty ? "0.00" : String(format: "%.2f", Double(row.amount) ?? 0)
            Text("\(row.type == .expense ? "-" : "+")¥\(amtStr)")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(row.type == .expense ? AppTheme.textSecondary : .green)
            Button(action: {
                guard rows.count > 1 else { return }
                if row.merchant.isEmpty && row.amount.isEmpty && row.note.isEmpty {
                    rows.remove(at: index)
                    if rows.isEmpty { rows.append(ManualEntryRow()) }
                } else {
                    pendingDeleteId = row.id; showDeleteAlert = true
                }
            }) {
                Image(systemName: "trash").font(.system(size: 15))
                    .foregroundColor(rows.count <= 1 ? AppTheme.textTertiary : AppTheme.brandEnd)
            }
            .frame(width: 28)
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture {
            editingIndex = index
            editType = row.type
            editMerchant = row.merchant
            editAmount = row.amount
            editCategory = row.category
            editNote = row.note
        }
    }
    
    private var editAmountBinding: Binding<Double> {
        Binding(get: { Double(editAmount) ?? 0 }, set: { let v = min($0, 9_999_999.99); editAmount = v == 0 ? "" : String(format: "%.2f", v) })
    }
    
    private func saveAll() {
        supabaseService.isGloballyProcessing = true
        supabaseService.globalProcessingMessage = "正在保存..."
        dismissKeyboard()
        guard supabaseService.currentUser != nil else {
            errorMessage = "错误：用户未登录"
            return
        }
        isSaving = true
        let validRows = rows.filter { !$0.merchant.isEmpty || !$0.amount.isEmpty }
        let emptyRowCount = rows.count - validRows.count
        let hasEmptyRows = emptyRowCount > 0
        guard !validRows.isEmpty else {
            isSaving = false
            errorMessage = "全部进账失败：未录入有效名称、金额"
            return
        }
        Task {
            var successCount = 0; var failCount = 0
            var successIds = Set<UUID>(); var failedIds = Set<UUID>()
            var failedMsgs: [String] = []
            await withTaskGroup(of: (UUID, Bool, String).self) { group in
                for row in validRows {
                    group.addTask { [row] in
                        let nE = row.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let aB = (Double(row.amount) ?? 0) <= 0
                        if nE && aB { return (row.id, false, "未录入有效名称、金额") }
                        if nE { return (row.id, false, "未录入有效名称") }
                        if aB { return (row.id, false, "未录入有效金额") }
                        let expense = Expense(id: UUID(), userId: supabaseService.currentUser?.id ?? UUID(), type: row.type, amount: abs(Double(row.amount) ?? 0), category: row.category, merchant: row.merchant.isEmpty ? "未命名" : row.merchant, date: Date(), note: row.note.isEmpty ? nil : row.note)
                        do { try await supabaseService.addExpense(expense); return (row.id, true, "") }
                        catch { return (row.id, false, error.localizedDescription) }
                    }
                }
                for await (id, ok, msg) in group {
                    if ok { successCount += 1; successIds.insert(id) }
                    else { failCount += 1; failedIds.insert(id); failedMsgs.append(msg) }
                }
            }
            await MainActor.run {
                isSaving = false
                supabaseService.isGloballyProcessing = false
                if failCount == 0 && !hasEmptyRows {
                    errorMessage = "全部已进账"
                    onSuccess?()
                } else {
                    rows.removeAll { successIds.contains($0.id) }
                    // 如果剩余的行全是空的（含仅空白字符），重置为一条新空行
                    if successCount > 0 {
                        let allEmpty = rows.allSatisfy { $0.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        if allEmpty {
                            rows = [ManualEntryRow(category: rows.last?.category ?? "餐饮")]
                        }
                    }
                    if rows.isEmpty {
                        rows.append(ManualEntryRow(category: "餐饮"))
                    }
                    let totalFail = failCount + emptyRowCount
                    if successCount == 0 {
                        errorMessage = "全部进账失败：\(failedMsgs.joined(separator: "；"))"
                    } else {
                        errorMessage = "\(successCount) 笔已进账，\(totalFail) 笔失败，请修改后重试"
                    }
                }
            }
        }
    }
}
