import SwiftUI

struct AIConfirmView: View {
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var supabaseService: SupabaseService

    @Binding var parsedItems: [GeminiService.ParsedExpense]
    var onDiscard: (() -> Void)?
    var onSuccess: (() -> Void)?
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var deletedIndices: Set<Int> = []
    @State private var showDeleteAlert = false
    @State private var pendingDeleteIndex: Int?
    @State private var showDiscardAlert = false
   @State private var batchType: RecordType?
    @State private var originalParsedItems: [GeminiService.ParsedExpense]?
    @State private var typeHistory: [UUID: [RecordType: String]] = [:]
    @State private var editingIndex: Int? = nil
    @State private var editCategoryByType: [RecordType: String] = [:]
    @State private var editFields = EditRowOverlay.EditableFields(
        type: .expense, merchant: "", amount: "", category: "餐饮", note: ""
    )
   var totalExpenseAmount: Double {
        parsedItems.enumerated().reduce(0) { $0 + (deletedIndices.contains($1.offset) ? 0 : ($1.element.type == .expense ? $1.element.amount : 0)) }
    }
    var totalIncomeAmount: Double {
        parsedItems.enumerated().reduce(0) { $0 + (deletedIndices.contains($1.offset) ? 0 : ($1.element.type == .income ? $1.element.amount : 0)) }
    }
    
    private var expenseCount: Int {
        parsedItems.enumerated().filter { !deletedIndices.contains($0.offset) && $0.element.type == .expense }.count
    }
    private var incomeCount: Int {
        parsedItems.enumerated().filter { !deletedIndices.contains($0.offset) && $0.element.type == .income }.count
    }

    var body: some View {
        ZStack {
            NavigationView {
            VStack(spacing: 0) {
                Color.clear.frame(width: 0, height: 0)
                    .onTapGesture { dismissKeyboard() }
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("解析统计")
                            .font(.appTitle)
                            .foregroundColor(AppTheme.textPrimary)
                        HStack(spacing: 12) {
                            if totalIncomeAmount > 0 {
                                Text("收入 \(currencySymbol)\(String(format: "%.2f", totalIncomeAmount))")
                                .font(.appBodyMedium)
                                   .foregroundColor(.green)
                            }
                            if totalExpenseAmount > 0 {
                                Text("支出 \(currencySymbol)\(String(format: "%.2f", totalExpenseAmount))")
                    .font(.appBodyMedium)
                                   .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(20)
                .background(Color.white)

                AppDivider()

                // Expense rows
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(parsedItems.indices, id: \.self) { index in
                            if !deletedIndices.contains(index) {
                                ExpenseEditRow(item: parsedItems[index], onTap: { let item = parsedItems[index]; editFields = EditRowOverlay.EditableFields(type: item.type, merchant: item.merchant, amount: String(format: "%.2f", item.amount), category: item.category, note: item.note ?? ""); editCategoryByType[item.type] = item.category; editingIndex = index }, onDelete: { pendingDeleteIndex = index; showDeleteAlert = true })
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .padding(.bottom, 170)
               }

              AppDivider()
                HStack(spacing: 4) {
                    HStack(spacing: 6) {
                        if incomeCount > 0 {
                            Text("收入\(incomeCount)笔")
                                .frame(minWidth: 64, alignment: .leading)
                                .font(.system(size: 17, weight: .regular))
                                .font(.appBodyMedium)
                                .foregroundColor(.green)
                        }
                        if expenseCount > 0 {
                            Text("支出\(expenseCount)笔")
                                .frame(minWidth: 64, alignment: .leading)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    if batchType != nil {
                        Button(action: {
                            if let saved = originalParsedItems { parsedItems = saved }
                            originalParsedItems = nil; batchType = nil
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 13, weight: .bold))
                                Text("取消")
                                    .font(.system(size: 13, weight: .medium))
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
                            if originalParsedItems == nil { originalParsedItems = parsedItems.map { $0 } }
                            for i in parsedItems.indices where !deletedIndices.contains(i) {
                                let item = parsedItems[i]; var h = typeHistory[item.id, default: [:]]
                                h[item.type] = item.category; typeHistory[item.id] = h
                            }
                            for i in parsedItems.indices where !deletedIndices.contains(i) {
                                parsedItems[i].type = .income
                                let incCats = CategoryManager.incomeCats
                                let saved = typeHistory[parsedItems[i].id]?[.income]
                                if let s = saved, incCats.contains(s) { parsedItems[i].category = s }
                                else if !incCats.contains(parsedItems[i].category) { parsedItems[i].category = "工资" }
                            }
                            batchType = .income
                        }) {
                            Text("转收入")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(batchType == .income ? .white : Color(hex: "#C0C0C0"))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .frame(minWidth: 84)
                                .background(batchType == .income ? Color.green : Color(hex: "#E8E8E8"))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Button(action: {
                            if originalParsedItems == nil { originalParsedItems = parsedItems.map { $0 } }
                            for i in parsedItems.indices where !deletedIndices.contains(i) {
                                let item = parsedItems[i]; var h = typeHistory[item.id, default: [:]]
                                h[item.type] = item.category; typeHistory[item.id] = h
                            }
                            for i in parsedItems.indices where !deletedIndices.contains(i) {
                                parsedItems[i].type = .expense
                                let expCats = CategoryManager.expenseCats
                                let saved = typeHistory[parsedItems[i].id]?[.expense]
                                if let s = saved, expCats.contains(s) { parsedItems[i].category = s }
                                else if !expCats.contains(parsedItems[i].category) { parsedItems[i].category = "餐饮" }
                            }
                            batchType = .expense
                        }) {
                            Text("转支出")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .frame(minWidth: 84)
                                .background(batchType == .expense ? AppTheme.textSecondary.opacity(0.22) : Color(hex: "#E8E8E8"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(batchType == .expense ? AppTheme.textSecondary.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 8)

                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(AppTheme.brandEnd)
                        .font(.appSmall)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                // Bottom buttons
                HStack(spacing: 4) {
                    Button(action: { showDiscardAlert = true }) {
                        Text("放弃")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSecondaryButtonStyle())

                    Button(action: saveAll) {
                        Text(isSaving ? "保存中..." : "进账")
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(isSaving)
                }
                .padding(20)
            }
            .onChange(of: parsedItems.map(\.type)) { newTypes in
                guard let batch = batchType else { return }
                guard let original = originalParsedItems else { return }
                let mismatchIndices = newTypes.indices.filter { newTypes[$0] != batch }
                guard !mismatchIndices.isEmpty else { return }
                batchType = nil
                for i in mismatchIndices {
                    guard i < original.count, i < parsedItems.count else { continue }
                    parsedItems[i].type = original[i].type
                    parsedItems[i].category = original[i].category
                }
            }
            .frame(maxHeight: .infinity)
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .principal) { HStack(spacing: 4) { Image(systemName: "checkmark.circle.badge.questionmark").font(.system(size: 17, weight: .semibold)).foregroundColor(AppTheme.brandStart); Text("解析内容").font(.appTitle).foregroundColor(AppTheme.textPrimary) } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { dismissKeyboard() }
                        .foregroundColor(AppTheme.brandStart)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {
                    pendingDeleteIndex = nil
                }
                Button("确认删除", role: .destructive) {
                    if let idx = pendingDeleteIndex {
                        deletedIndices.insert(idx)
                        pendingDeleteIndex = nil
                        if deletedIndices.count == parsedItems.count {
                            onDiscard?()
                        }
                    }
                }
            } message: {
                Text("是否确认删除该项内容？")
            }
        .alert("确认放弃", isPresented: $showDiscardAlert) {
            Button("取消", role: .cancel) { }
            Button("确认放弃", role: .destructive) {
                onDiscard?()
            }
            } message: {
                Text("是否确认放弃本次解析结果？")
            }
        }
        
        if editingIndex != nil {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { editingIndex = nil }

           EditRowOverlay(
               fields: $editFields,
               categoryByType: $editCategoryByType,
               onSave: {
                   guard let idx = editingIndex, idx < parsedItems.count else { return }
                   parsedItems[idx].type = editFields.type
                   parsedItems[idx].merchant = editFields.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
                   parsedItems[idx].amount = Double(editFields.amount) ?? 0
                   parsedItems[idx].category = editFields.category
                   parsedItems[idx].note = editFields.note.isEmpty ? nil : editFields.note
                   editingIndex = nil
               },
               onCancel: { editingIndex = nil }
           )
           .onAppear {
                if let idx = editingIndex, idx < parsedItems.count {
                    let item = parsedItems[idx]
                    editFields = EditRowOverlay.EditableFields(
                        type: item.type,
                        merchant: item.merchant,
                        amount: String(format: "%.2f", item.amount),
                        category: item.category,
                        note: item.note ?? ""
                    )
                    editCategoryByType[item.type] = item.category
                }
           }
            .id(editingIndex)
        }

	}
    }

    func saveAll() {
        dismissKeyboard()
        guard let user = supabaseService.currentUser else {
            errorMessage = "错误：用户未登录"
            Log.error("保存支出失败：无用户会话")
            return
        }
        let userId = user.id

        isSaving = true
        errorMessage = ""
        Log.info("开始保存 \(parsedItems.count) 笔支出")

        Task {
            // 批量保存：一次网络请求 + 一次性本地更新（性能优化）
            let toSave = parsedItems.enumerated().filter { !deletedIndices.contains($0.offset) }
            var validPairs: [(index: Int, expense: Expense)] = []
            var failedItems: [String] = []

            for (offset, item) in toSave {
                let nameEmpty = item.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let amountBad = item.amount <= 0
                if nameEmpty && amountBad { failedItems.append("未录入有效名称、金额"); continue }
                if nameEmpty { failedItems.append("未录入有效名称"); continue }
                if amountBad { failedItems.append("未录入有效金额"); continue }
                let expense = Expense(id: UUID(), userId: userId, type: item.type, amount: item.amount, category: item.category, merchant: item.merchant, date: Date(), note: item.note, currency: currencySymbol)
                validPairs.append((offset, expense))
            }

            var cloudSucceeded = false
            if !validPairs.isEmpty {
                do {
                    try await supabaseService.batchAddExpenses(validPairs.map { $0.expense })
                    cloudSucceeded = true
                } catch {
                    failedItems.append("云端保存失败：\(error.userFriendlyDescription)")
                }
            }

            await MainActor.run {
                isSaving = false
                if cloudSucceeded && failedItems.isEmpty {
                    Log.info("全部保存成功: \(validPairs.count) 笔")
                    Task { await UserLogManager.log(action: "进账", detail: "进账(\(validPairs.count))", supabaseService: supabaseService) }
                    onSuccess?()
                } else if cloudSucceeded {
                    // 校验失败的项保留，成功项移除
                    for (index, _) in validPairs.sorted(by: { $0.index > $1.index }) {
                        parsedItems.remove(at: index)
                    }
                    deletedIndices = []
                    errorMessage = "\(validPairs.count) 笔已进账，\(failedItems.count) 笔失败，请修改后重试"
                    Log.warn("部分保存: \(errorMessage ?? "")")
                } else {
                    errorMessage = "全部进账失败：\(failedItems.joined(separator: "；"))"
                    Log.warn("全部失败: \(errorMessage ?? "")")
                }
            }
        }
        }


}
struct ExpenseEditRow: View {
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    let item: GeminiService.ParsedExpense
    var onTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 13))
                .foregroundColor((item.type == .expense ? AppTheme.textSecondary : .green).opacity(0.5))
            Text(item.type == .expense ? "支" : "收")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(item.type == .expense ? AppTheme.textSecondary : .green)
                .frame(width: 26, height: 26)
                .background((item.type == .expense ? AppTheme.textSecondary : Color.green).opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(item.merchant.isEmpty ? "未命名" : item.merchant)
                    .font(.appBodyMedium).foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(item.category)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.categoryColor(item.category))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(AppTheme.categoryColor(item.category).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }
                if let note = item.note, !note.isEmpty {
                    Text(note.utf8.count > 6 ? note.truncatedToBytes(6) + "..." : note)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
           Text(item.type == .income ? String(format: "+" + currencySymbol + "%.2f", item.amount) : String(format: "-" + currencySymbol + "%.2f", item.amount))
               .font(.system(size: 17, weight: .regular))
               .foregroundColor(item.type == .expense ? AppTheme.textSecondary : .green)
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash").font(.system(size: 15))
                        .foregroundColor(AppTheme.brandEnd)
                }
                .frame(width: 28)
                .buttonStyle(.plain)
            }
       }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }
}


// MARK: - 带"完成"键盘工具栏的文本输入框
struct KeyboardDoneTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
   var font: UIFont = .systemFont(ofSize: 17)
   
   func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = font
        tf.textColor = UIColor(AppTheme.textPrimary)
        tf.backgroundColor = UIColor.white
        tf.delegate = context.coordinator
       tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
       let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneBtn = UIBarButtonItem(title: "完成", style: .plain, target: tf, action: #selector(UIResponder.resignFirstResponder))
        doneBtn.tintColor = UIColor(AppTheme.brandStart)
        toolbar.setItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), doneBtn], animated: false)
        tf.inputAccessoryView = toolbar
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        tf.text = text
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }
    }
}



// MARK: - 带"完成"键盘工具栏的多行文本编辑器
