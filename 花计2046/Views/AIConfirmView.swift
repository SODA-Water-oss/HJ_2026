import SwiftUI

struct AIConfirmView: View {
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
   @State private var showCategoryPicker = false
   @State private var batchType: RecordType?
    @State private var originalParsedItems: [GeminiService.ParsedExpense]?
    @State private var typeHistory: [UUID: [RecordType: String]] = [:]
    @State private var editingIndex: Int? = nil
    @State private var editType: RecordType = .expense
    @State private var editName: String = ""
    @State private var editAmount: Double = 0
    @State private var editCategory: String = "餐饮"
    @State private var editNote: String = ""
   @State private var isNewEditRow = false
    @State private var editCategoryByType: [RecordType: String] = [:]
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
                                Text("收入 ¥\(String(format: "%.2f", totalIncomeAmount))")
                                .font(.appBodyMedium)
                                   .foregroundColor(.green)
                            }
                            if totalExpenseAmount > 0 {
                                Text("支出 ¥\(String(format: "%.2f", totalExpenseAmount))")
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
                                ExpenseEditRow(item: parsedItems[index], onTap: { editingIndex = index }, onDelete: { pendingDeleteIndex = index; showDeleteAlert = true })
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
                                .foregroundColor(AppTheme.brandStart)
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
                                let incCats = ["工资","奖金","兼职","投资收益","理财","礼金","退款","其他"]
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
                                let expCats = ["餐饮","交通","购物","娱乐","住房","日用","服饰","通讯","医疗","教育","其他"]
                                let saved = typeHistory[parsedItems[i].id]?[.expense]
                                if let s = saved, expCats.contains(s) { parsedItems[i].category = s }
                                else if !expCats.contains(parsedItems[i].category) { parsedItems[i].category = "餐饮" }
                            }
                            batchType = .expense
                        }) {
                            Text("转支出")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(batchType == .expense ? .white : Color(hex: "#C0C0C0"))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .frame(minWidth: 84)
                                .background(batchType == .expense ? AppTheme.brandStart : Color(hex: "#E8E8E8"))
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
       .sheet(isPresented: $showCategoryPicker) {
            let expenseCats = ["餐饮","交通","购物","娱乐","住房","日用","服饰","通讯","医疗","教育","其他"]
            let incomeCats = ["工资","奖金","兼职","投资收益","理财","礼金","退款","其他"]
            CategoryWheelPicker(selection: $editCategory, options: editType == .expense ? expenseCats : incomeCats)
               .presentationDetents([.height(280)])
       }
        
        if editingIndex != nil {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
               .onTapGesture { editingIndex = nil }
           VStack(spacing: 0) {

                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.brandStart)
                    Text("编辑记录")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 12)
                AppDivider().padding(.horizontal, 16)
                ScrollView {
                    VStack(spacing: 10) {
                        HStack(spacing: 0) {
                            Button(action: {
                                editCategoryByType[editType] = editCategory
                                editType = .income
                                editCategory = editCategoryByType[.income] ?? "工资"
                            }) {
                                Text("收入")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(editType == .income ? .white : .green)
                                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                                    .background(editType == .income ? Color.green : Color.clear)
                                    .cornerRadius(6)
                            }
                            Button(action: {
                                editCategoryByType[editType] = editCategory
                                editType = .expense
                                editCategory = editCategoryByType[.expense] ?? "餐饮"
                            }) {
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text("类别")
                                .font(.system(size: 17, weight: .medium)).foregroundColor(AppTheme.textSecondary)
                            Button(action: { showCategoryPicker = true }) {
                                HStack {
                                    Text(editCategory)
                                        .font(.system(size: 17))
                                        .foregroundColor(editType == .expense ? AppTheme.brandStart : .green)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .medium)).foregroundColor(AppTheme.textTertiary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(Color.white).cornerRadius(7)
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("名称")
                                .font(.system(size: 17, weight: .medium)).foregroundColor(AppTheme.textSecondary)
                            KeyboardDoneTextField(text: $editName, placeholder: "输入名称")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(Color.white).cornerRadius(7)
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("金额")
                                .font(.system(size: 17, weight: .medium)).foregroundColor(AppTheme.textSecondary)
                            HStack(spacing: 6) {
                                Text("¥").font(.system(size: 17, weight: .medium)).foregroundColor(AppTheme.textTertiary)
                                AmountTextField(amount: $editAmount, font: .systemFont(ofSize: 17), textColor: editType == .income ? UIColor.systemGreen : UIColor(AppTheme.textSecondary))
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Color.white).cornerRadius(7)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("备注")
                                .font(.system(size: 17, weight: .medium)).foregroundColor(AppTheme.textSecondary)
                           KeyboardDoneTextEditor(text: $editNote).frame(minHeight: 72)
                       }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
               AppDivider().padding(.horizontal, 16)
                HStack(spacing: 10) {
                    Button(action: { editingIndex = nil }) {
                        Text("取消")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.white).cornerRadius(7)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                    }
                  Button(action: { guard let idx = editingIndex, idx < parsedItems.count else { return }
                       parsedItems[idx].type = editType
                       parsedItems[idx].merchant = editName.trimmingCharacters(in: .whitespacesAndNewlines)
                       parsedItems[idx].amount = editAmount
                       parsedItems[idx].category = editCategory
                       parsedItems[idx].note = editNote.isEmpty ? nil : editNote
                        editingIndex = nil }) {
                        Text("保存")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(AppTheme.brandGradient).cornerRadius(7)
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
                .onAppear {
                    if let idx = editingIndex, idx < parsedItems.count {
                        let item = parsedItems[idx]
                        editType = item.type
                        editName = item.merchant
                        editAmount = item.amount
                       editCategory = item.category
                        editCategoryByType[item.type] = item.category
                       editNote = item.note ?? ""
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
            var savedCount = 0
            var savedIndices = Set<Int>()
            var failedItems: [String] = []

            // 并发保存
            let toSave = parsedItems.enumerated().filter { !deletedIndices.contains($0.offset) }
            await withTaskGroup(of: (Int, Bool, String).self) { group in
                for (offset, item) in toSave {
                    let expense = Expense(id: UUID(), userId: userId, type: item.type, amount: item.amount, category: item.category, merchant: item.merchant, date: Date(), note: item.note)
                    group.addTask { [offset] in
                        let _nE = item.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty; let _aB = item.amount <= 0; if _nE && _aB { return (offset, false, "未录入有效名称、金额") }; if _nE { return (offset, false, "未录入有效名称") }; if _aB { return (offset, false, "未录入有效金额") }
                        do { try await supabaseService.addExpense(expense); return (offset, true, "保存成功") }
                        catch { Log.error("保存失败: \(error.localizedDescription)"); return (offset, false, "\(item.merchant) ¥\(item.amount): \(error.localizedDescription)") }
                    }
                }
                for await (offset, ok, msg) in group {
                    if ok { savedCount += 1; savedIndices.insert(offset) }
                    else { failedItems.append(msg) }
                }
            if let idx = editingIndex, idx < parsedItems.count {
                let item = parsedItems[idx]
                editType = item.type
                editName = item.merchant
                editAmount = item.amount
                editCategory = item.category
                editNote = item.note ?? ""
        }

      }

            await MainActor.run {
                isSaving = false
                if failedItems.isEmpty {
                    Log.info("全部保存成功: \(savedCount) 笔")
                    onSuccess?()
                } else if savedCount > 0 {
                    // 部分成功：移除已保存的，保留失败的
                    for idx in savedIndices.sorted(by: >) {
                       parsedItems.remove(at: idx)
                   }
                   deletedIndices = []
                   errorMessage = "\(savedCount) 笔已进账，\(failedItems.count) 笔失败，请修改后重试"
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
    let item: GeminiService.ParsedExpense
    var onTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 13))
                .foregroundColor((item.type == .expense ? AppTheme.brandStart : .green).opacity(0.5))
            Text(item.type == .expense ? "支" : "收")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(item.type == .expense ? AppTheme.brandStart : .green)
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
            Text(item.type == .income ? String(format: "+¥%.2f", item.amount) : String(format: "-¥%.2f", item.amount))
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(item.type == .expense ? AppTheme.textSecondary : .green)
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
struct KeyboardDoneTextEditor: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont = .systemFont(ofSize: 17)

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = font
        view.textColor = UIColor(AppTheme.textPrimary)
        view.backgroundColor = UIColor.white
        view.layer.cornerRadius = 7
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(AppTheme.border).cgColor
        view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        view.isScrollEnabled = true
        view.delegate = context.coordinator
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneBtn = UIBarButtonItem(title: "完成", style: .plain, target: view, action: #selector(UIResponder.resignFirstResponder))
        doneBtn.tintColor = UIColor(AppTheme.brandStart)
        toolbar.setItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), doneBtn], animated: false)
        view.inputAccessoryView = toolbar
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        view.text = text
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        func textViewDidChange(_ textView: UITextView) {
            text = textView.text ?? ""
        }
    }
}

struct AmountTextField: UIViewRepresentable {
    @Binding var amount: Double
    var font: UIFont = .systemFont(ofSize: 17)
   var textAlignment: NSTextAlignment = .left
    var textColor: UIColor = UIColor(AppTheme.textPrimary)
   
   func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.backgroundColor = UIColor.white
        tf.keyboardType = .decimalPad
        tf.textAlignment = textAlignment
        tf.font = font
        tf.textColor = textColor
        tf.delegate = context.coordinator
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneBtn = UIBarButtonItem(title: "完成", style: .plain, target: tf, action: #selector(UIResponder.resignFirstResponder))
        doneBtn.tintColor = UIColor(AppTheme.brandStart)
        toolbar.setItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), doneBtn], animated: false)
        tf.inputAccessoryView = toolbar
        return tf
    }
    
  func updateUIView(_ tf: UITextField, context: Context) {
        // 颜色不受编辑状态影响，随时更新
        if tf.textColor != textColor { tf.textColor = textColor }
       guard !tf.isFirstResponder else { return }
      let cur = Double(tf.text?.replacingOccurrences(of: "¥", with: "") ?? "") ?? 0
        if abs(cur - amount) > 0.001 {
            tf.text = amount == 0 ? "" : String(format: "%.2f", amount)
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(amount: $amount) }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var amount: Double
        init(amount: Binding<Double>) { _amount = amount }
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let allowed = CharacterSet(charactersIn: "0123456789.")
            let cs = CharacterSet(charactersIn: string)
            if !allowed.isSuperset(of: cs) { return false }
            let current = textField.text ?? ""
            let newStr = (current as NSString).replacingCharacters(in: range, with: string)
            let parts = newStr.components(separatedBy: ".")
            if parts.count > 2 { return false }
            if parts.count == 2 && parts[1].count > 2 { return false }
            // 超出上限直接拒绝
            if let d = Double(newStr), d > 9_999_999.99 { return false }

           if let d = Double(newStr) { amount = d }
            return true
        }
    }
}
