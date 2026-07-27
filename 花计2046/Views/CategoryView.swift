import SwiftUI

struct CategoryView: View {
    @AppStorage("enabled_expense_cats") private var expenseCatsRaw: String = ""
    @AppStorage("enabled_income_cats") private var incomeCatsRaw: String = ""
    @AppStorage("custom_expense_cats") private var customExpenseRaw: String = ""
    @AppStorage("custom_income_cats") private var customIncomeRaw: String = ""
    @AppStorage("default_expense_cat") private var defaultExpenseCat: String = "餐饮"
    @AppStorage("default_income_cat") private var defaultIncomeCat: String = "工资"
    
    @State private var newExpenseName = ""
    @State private var selectedTab = 0
    @State private var newIncomeName = ""
    
    private let allExpenseCats = CategoryManager.defaultExpenseCats
    private let allIncomeCats = CategoryManager.defaultIncomeCats
    
    private var enabledExpense: [String] { expenseCatsRaw.isEmpty ? allExpenseCats : expenseCatsRaw.components(separatedBy: ",").filter { !$0.isEmpty } }
    private var enabledIncome: [String] { incomeCatsRaw.isEmpty ? allIncomeCats : incomeCatsRaw.components(separatedBy: ",").filter { !$0.isEmpty } }
    private var customExpense: [String] { customExpenseRaw.isEmpty ? [] : customExpenseRaw.components(separatedBy: ",").filter { !$0.isEmpty } }
    private var customIncome: [String] { customIncomeRaw.isEmpty ? [] : customIncomeRaw.components(separatedBy: ",").filter { !$0.isEmpty } }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("支出").tag(0)
                    Text("收入").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                ScrollView {
                    VStack(spacing: 16) {
                        Color.clear.frame(height: 4)
                        
                        if selectedTab == 0 {
                            expenseSection
                        } else {
                            incomeSection
                        }
                        helpSection
                        
                        Spacer(minLength: 32)
                    }
                }
        }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("分类设置")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
        }
    }
    
    private var expenseSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.brandStart)
                Text("支出分类")
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("需至少保留一个")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textTertiary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
            
            ForEach(allExpenseCats, id: \.self) { cat in
                catRow(cat: cat, enabled: enabledExpense, isDefault: defaultExpenseCat == cat, onToggle: { CategoryManager.setExpenseCatEnabled(cat, enabled: $0) }, onSetDefault: { defaultExpenseCat = cat })
            }
            
            if !customExpense.isEmpty {
                Divider().padding(.horizontal, 16).padding(.vertical, 4)
                ForEach(customExpense, id: \.self) { cat in
                    HStack {
                        Image(systemName: "plus.square.fill").font(.system(size: 17)).foregroundColor(AppTheme.brandStart).frame(width: 24)
                        Text(cat).font(.appBody).foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Button(action: { CategoryManager.removeCustomExpenseCat(cat) }) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 15)).foregroundColor(AppTheme.textTertiary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            
            HStack {
                TextField("添加自定义支出分类", text: $newExpenseName)
                    .font(.appBody).textFieldStyle(.plain)
                Button("添加") {
                    CategoryManager.addCustomExpenseCat(newExpenseName)
                    newExpenseName = ""
                }
                .font(.appSmall).foregroundColor(AppTheme.brandStart)
                .disabled(newExpenseName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    private var incomeSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.brandStart)
                Text("收入分类")
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("需至少保留一个")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textTertiary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
            
            ForEach(allIncomeCats, id: \.self) { cat in
                catRow(cat: cat, enabled: enabledIncome, isDefault: defaultIncomeCat == cat, onToggle: { CategoryManager.setIncomeCatEnabled(cat, enabled: $0) }, onSetDefault: { defaultIncomeCat = cat })
            }
            
            if !customIncome.isEmpty {
                Divider().padding(.horizontal, 16).padding(.vertical, 4)
                ForEach(customIncome, id: \.self) { cat in
                    HStack {
                        Image(systemName: "plus.square.fill").font(.system(size: 17)).foregroundColor(AppTheme.brandStart).frame(width: 24)
                        Text(cat).font(.appBody).foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Button(action: { CategoryManager.removeCustomIncomeCat(cat) }) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 15)).foregroundColor(AppTheme.textTertiary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            
            HStack {
                TextField("添加自定义收入分类", text: $newIncomeName)
                    .font(.appBody).textFieldStyle(.plain)
                Button("添加") {
                    CategoryManager.addCustomIncomeCat(newIncomeName)
                    newIncomeName = ""
                }
                .font(.appSmall).foregroundColor(AppTheme.brandStart)
                .disabled(newIncomeName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("说明").font(.appBodyMedium).foregroundColor(AppTheme.textPrimary)
            Text("• 勾选的类别将出现在手动记账、解析内容、批量修改、编辑记录中").font(.appSmall).foregroundColor(AppTheme.textSecondary)
            Text("• 已录入的历史数据不受影响").font(.appSmall).foregroundColor(AppTheme.textSecondary)
            Text("• 自定义类别上限各10个").font(.appSmall).foregroundColor(AppTheme.textSecondary)
            Text("• 勾选启用类别，点击星标设为默认").font(.appSmall).foregroundColor(AppTheme.textSecondary)
            Text("类别设置需至少保留一个选项").font(.appSmall).foregroundColor(AppTheme.textTertiary.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    private func catRow(cat: String, enabled: [String], isDefault: Bool, onToggle: @escaping (Bool) -> Void, onSetDefault: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: enabled.contains(cat) ? "checkmark.square.fill" : "square")
                .font(.system(size: 17))
                .foregroundColor(enabled.contains(cat) ? AppTheme.brandStart : AppTheme.textTertiary)
            Text(cat)
                .font(.appBody)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            if isDefault {
                Text("默认")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.brandStart)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.brandStart.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { if enabled.count > 1 || !enabled.contains(cat) { onToggle(!enabled.contains(cat)) } }
        .onLongPressGesture { onSetDefault() }
    }
}
