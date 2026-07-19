import SwiftUI

struct EditExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var supabaseService: SupabaseService
    
    let expense: Expense
    let onSave: () -> Void
    
    @State private var amount: String
   @State private var merchant: String
    @State private var category: String
    @State private var note: String
    @State private var date: Date
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSaveError = false
    @State private var recordType: RecordType
    @State private var categoryByType: [RecordType: String] = [:]
    @State private var showCategoryPicker = false
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @FocusState private var isNoteFocused: Bool
    
    let expenseCategories = ["餐饮", "交通", "购物", "娱乐", "住房", "日用", "服饰", "通讯", "医疗", "教育", "其他"]
    let incomeCategories = ["工资", "奖金", "兼职", "投资收益", "理财", "礼金", "退款", "其他"]
    var categories: [String] { recordType == .expense ? expenseCategories : incomeCategories }
    
    init(expense: Expense, onSave: @escaping () -> Void) {
        self.expense = expense
        self.onSave = onSave
        _amount = State(initialValue: String(format: "%.2f", expense.amount))
        _merchant = State(initialValue: expense.merchant)
        _category = State(initialValue: expense.category)
        _note = State(initialValue: expense.note ?? "")
        _date = State(initialValue: expense.date)
        _recordType = State(initialValue: expense.type)
   }
    
    private var amountDoubleBinding: Binding<Double> {
        Binding(get: { Double(self.amount) ?? 0 }, set: { self.amount = $0 == 0 ? "" : String(format: "%.2f", $0) })
    }
   
   var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {

                    // Amount Card
                    VStack(spacing: 6) {
                        Text("金额")
                            .font(.system(size: 17))
                            .foregroundColor(AppTheme.textSecondary)
                    AmountTextField(amount: amountDoubleBinding, font: .systemFont(ofSize: 48, weight: .semibold), textAlignment: NSTextAlignment.center, textColor: recordType == .income ? UIColor.systemGreen : UIColor(AppTheme.textSecondary))
                   }
                   .padding(.top, 24)
                    
                    // 收支类型
                    HStack(spacing: 0) {
                        Button(action: { recordType = .income }) {
                            Text("收入")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(recordType == .income ? .white : .green)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(recordType == .income ? Color.green : Color.white)
                                .cornerRadius(7)
                        }
                        Button(action: { recordType = .expense }) {
                            Text("支出")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(recordType == .expense ? .white : AppTheme.brandStart)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(recordType == .expense ? AppTheme.brandStart : Color.white)
                                .cornerRadius(7)
                        }
                    }
                    .background(AppTheme.background)
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .onChange(of: recordType) { newType in
                        let oldType: RecordType = (newType == .income) ? .expense : .income
                        categoryByType[oldType] = category
                        if let saved = categoryByType[newType] {
                            category = saved
                        } else if !categories.contains(category) {
                            category = categories.first ?? "其他"
                        }
                    }
                    
                    // Details Card
                    VStack(alignment: .leading, spacing: 12) {
                        // Category
                        VStack(alignment: .leading, spacing: 6) {
                            Text("类别").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            Button(action: { showCategoryPicker = true }) {
                                HStack {
                                    Text(category)
                                        .font(.system(size: 17))
                                        .foregroundColor(recordType == .expense ? AppTheme.brandStart : .green)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .padding(12)
                            .background(AppTheme.background)
                           .cornerRadius(AppTheme.elementRadius)
                           .sheet(isPresented: $showCategoryPicker) {
                                CategoryEditPicker(selection: $category, options: categories)
                                    .presentationDetents([.height(260)])
                            }
                        }
                        
                        AppDivider()

                        AppDivider()

                        // Merchant
                        VStack(alignment: .leading, spacing: 6) {
                            Text("名称").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            TextField("名称", text: $merchant)
                            .disabled(isSaving)
                            .byteLimited($merchant, max: 50)
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                        }
                        
                        // 日期
                        VStack(alignment: .leading, spacing: 6) {
                            Text("日期").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            Button(action: { showDatePicker = true }) {
                                HStack {
                                    Text("\(dateFormatted(date)) \(chineseWeekday(date))")
                                        .font(.system(size: 17))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                            }
                            .padding(12)
                            .background(AppTheme.background)
                            .cornerRadius(AppTheme.elementRadius)
                            .sheet(isPresented: $showDatePicker) {
                                VStack(spacing: 0) {
                                    HStack {
                                        Button(action: { showDatePicker = false }) { Text("取消").foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 6).background(Color(hex: "#4B5563")).cornerRadius(6) }
                                        Spacer()
                                        Text("选择日期").font(.system(size: 17).weight(.semibold)).foregroundColor(AppTheme.brandStart)
                                        Spacer()
                                        Button(action: { showDatePicker = false }) { Text("确定").foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 6).background(AppTheme.brandStart).cornerRadius(6) }
                                    }.padding(.horizontal, 16).padding(.vertical, 12)
                                    Divider()
                                    Text(chineseWeekday(date)).font(.system(size: 17, weight: .medium)).foregroundColor(AppTheme.textSecondary).frame(maxWidth: .infinity, alignment: .center).padding(.top, 8)
                                    DatePicker("", selection: $date, displayedComponents: .date)
                                        .datePickerStyle(.wheel).labelsHidden()
                                        .environment(\.locale, Locale(identifier: "zh_CN"))
                                }
                                .background(.ultraThinMaterial)
                                .presentationDetents([.height(300)])
                            }
                        }
                        AppDivider()
                        // 时间
                        VStack(alignment: .leading, spacing: 6) {
                            Text("时间").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            Button(action: { showTimePicker = true }) {
                                HStack {
                                    Text(timeFormatted(date))
                                        .font(.system(size: 17))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                            }
                            .padding(12)
                            .background(AppTheme.background)
                            .cornerRadius(AppTheme.elementRadius)
                        }
                        .sheet(isPresented: $showTimePicker) {
                            VStack(spacing: 0) {
                                HStack {
                                    Button(action: { showTimePicker = false }) { Text("取消").foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 6).background(Color(hex: "#4B5563")).cornerRadius(6) }
                                    Spacer()
                                    Text("选择时间").font(.system(size: 17).weight(.semibold)).foregroundColor(AppTheme.brandStart)
                                    Spacer()
                                    Button(action: { showTimePicker = false }) { Text("确定").foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 6).background(AppTheme.brandStart).cornerRadius(6) }
                                }.padding(.horizontal, 16).padding(.vertical, 12)
                                Divider()
                                DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel).labelsHidden()
                                    .environment(\.locale, Locale(identifier: "zh_CN"))
                            }
                            .background(.ultraThinMaterial)
                                .presentationDetents([.height(270)])
                        }
                        
                        AppDivider()
                        
                        // Note
                        VStack(alignment: .leading, spacing: 6) {
                            Text("备注").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            TextField("备注（可选）", text: $note, axis: .vertical)
                            .disabled(isSaving)
                            .byteLimited($note, max: 200)
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                            .lineLimit(3...6)
                            .focused($isNoteFocused)
                        }
                        HStack {
                            if note.utf8.count > 200 {
                                Text("您的输入已超上限!")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.brandGradient)
                            }
                            Spacer()
                            Text("\(note.utf8.count)/200")
                                .font(.system(size: 13))
                                .foregroundStyle(note.utf8.count > 200 ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(hex: "#888888")))
                        }
                       .id("noteField")
                   }
                   .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 16)
                    
                    // Save Button
                    VStack(spacing: 12) {
                        Button(action: saveChanges) {
                            Text(isSaving ? "保存中..." : "保存修改")
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(isSaving)
                        Button(action: { dismiss() }) {
                            Text("取消修改")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isSaving)
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 0)
                }
            }
                .onChange(of: isNoteFocused) { focused in
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation {
                                proxy.scrollTo("noteField", anchor: .center)
                            }
                        }
                    }
               }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { dismissKeyboard() }
                        .foregroundColor(AppTheme.brandStart)
                }
            }
           }
       }
       .navigationTitle("编辑记录")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("编辑记录")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
        .scrollDismissesKeyboard(.immediately)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func saveChanges() {
        if merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveError = "名称不能为空"
            showSaveError = true
            return
        }
        guard let amountValue = Double(amount), amountValue > 0 else {
            saveError = "请输入有效的金额"
            showSaveError = true
            return
        }
        let updatedExpense = Expense(
            id: expense.id,
            userId: expense.userId,
            type: recordType,
            amount: amountValue,
            category: category,
            merchant: merchant,
            date: date,
            note: note.isEmpty ? nil : note
        )
        // 乐观更新：先更新本地缓存并关闭页面
       if let idx = supabaseService.allRecords.firstIndex(where: { $0.id == updatedExpense.id }) {
           supabaseService.allRecords[idx] = updatedExpense
       }
        // 从两个分类数组移除，再按新类型加入正确数组
        supabaseService.expenses.removeAll { $0.id == updatedExpense.id }
        supabaseService.incomes.removeAll { $0.id == updatedExpense.id }
        if recordType == .expense {
            supabaseService.expenses.append(updatedExpense)
        } else {
            supabaseService.incomes.append(updatedExpense)
        }
       isSaving = false
        onSave()
        dismiss()
        // 异步同步到服务端
        Task {
            try? await supabaseService.updateExpense(updatedExpense)
        }
    }
}


// MARK: - 编辑页类别滚轮选择器
struct CategoryEditPicker: View {
    @Binding var selection: String
    let options: [String]
    @State private var tempSelection: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Button(action: { dismiss() }) { Text("取消").foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 6).background(Color(hex: "#4B5563")).cornerRadius(6) }
                
                Spacer()
                
                Text("选择类别")
                    .font(.system(size: 17).weight(.semibold))
                    .foregroundColor(AppTheme.brandStart)
                
                Spacer()
                
                Button(action: { selection = tempSelection; dismiss() }) {
                    Text("确定").foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 6).background(AppTheme.brandStart).cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            Picker("类别", selection: $tempSelection) {
                ForEach(options, id: \.self) { cat in
                    Text(cat)
                        .font(.system(size: 21, weight: .medium))
                        .tag(cat)
                }
            }
            .pickerStyle(.wheel)
        }
        .background(.ultraThinMaterial)
        .onAppear {
            tempSelection = selection
        }
    }
}


private func dateFormatted(_ d: Date) -> String {
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; return df.string(from: d)
}
private func timeFormatted(_ d: Date) -> String {
    let df = DateFormatter(); df.dateFormat = "HH:mm"; return df.string(from: d)
}

// MARK: - 日期滚轮选择器
struct DateWheelPicker: View {
    @Binding var selection: Date
    @State private var tempDate: Date = Date()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) { Text("取消").foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 6).background(Color(hex: "#4B5563")).cornerRadius(6) }
                Spacer()
                Text("选择时间")
                    .font(.system(size: 17).weight(.semibold))
                    .foregroundColor(AppTheme.brandStart)
                Spacer()
                Button(action: { selection = tempDate; dismiss() }) {
                    Text("确定").foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 6).background(AppTheme.brandStart).cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            DatePicker("", selection: $tempDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.wheel)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .labelsHidden()
        }
        .background(.ultraThinMaterial)
        .onAppear { tempDate = selection }
    }
}
