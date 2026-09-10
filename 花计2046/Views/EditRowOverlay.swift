import SwiftUI

struct EditRowOverlay: View {
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    struct EditableFields {
        var type: RecordType
        var merchant: String
        var amount: String
        var category: String
        var note: String
    }

    @Binding var fields: EditableFields
    @Binding var categoryByType: [RecordType: String]
    var onSave: () -> Void
    var onCancel: () -> Void

    @State private var editType: RecordType = .expense
    @State private var editMerchant: String = ""
    @State private var editAmount: Double = 0
    @State private var editCategory: String = "餐饮"
    @State private var editNote: String = ""
    @State private var showCategoryPicker = false

    private var categories: [String] { CategoryManager.cats(for: editType) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17))
                    .foregroundColor(AppTheme.brandStart)
                Text("编辑记录")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            AppDivider().padding(.horizontal, 16)

           ScrollView {
                VStack(spacing: 10) {
                    // Type toggle
                    HStack(spacing: 0) {
                        Button(action: { switchType(to: .income) }) {
                            Text("收入")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(editType == .income ? .white : .green)
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                                .background(editType == .income ? Color.green : Color.clear)
                                .cornerRadius(6)
                        }
                        Button(action: { switchType(to: .expense) }) {
                            Text("支出")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                                .background(editType == .expense ? AppTheme.textSecondary.opacity(0.22) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(editType == .expense ? AppTheme.textSecondary.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                                .cornerRadius(6)
                        }
                    }
                    .background(AppTheme.background)
                    .cornerRadius(7)

                    // Category
                    VStack(alignment: .leading, spacing: 4) {
                        Text("类别")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        Button(action: { showCategoryPicker = true }) {
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
                            .background(Color.white).cornerRadius(7)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                        }
                    }

                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("名称")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                       KeyboardDoneTextField(text: $editMerchant, placeholder: "输入名称")
                            .frame(maxWidth: .infinity)
                           .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Color.white).cornerRadius(7)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                            .onChange(of: editMerchant) { _, newValue in
                                if newValue.utf8.count > 50 {
                                    editMerchant = String(newValue.prefix(50))
                                }
                            }
                    }

                    // Amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("金额")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        HStack(spacing: 6) {
                            Text(currencySymbol).font(.system(size: 17, weight: .medium)).foregroundColor(AppTheme.textTertiary)
                            AmountTextField(amount: $editAmount, font: .systemFont(ofSize: 17), textColor: editType == .income ? UIColor.systemGreen : UIColor(AppTheme.textSecondary))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Color.white).cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                    }

                    // Note
                    VStack(alignment: .leading, spacing: 4) {
                        Text("备注")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        KeyboardDoneTextEditor(text: $editNote)
                            .frame(maxWidth: .infinity)

                            .frame(minHeight: 72)
                            .onChange(of: editNote) { _, newValue in
                                if newValue.utf8.count > 200 {
                                    editNote = String(newValue.prefix(200))
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            AppDivider().padding(.horizontal, 16)

            // Cancel / Save buttons
            HStack(spacing: 10) {
                Button(action: onCancel) {
                   Text("取消")
                       .font(.system(size: 17, weight: .medium))
                       .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                       .background(Color.white).cornerRadius(7)
                       .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
               }
               Button(action: saveEdit) {
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
            editType = fields.type
            editMerchant = fields.merchant
            editAmount = Double(fields.amount) ?? 0
            editCategory = fields.category
            editNote = fields.note
        }
        .sheet(isPresented: $showCategoryPicker) {
            let cats = CategoryManager.cats(for: editType)
            CategoryWheelPicker(selection: $editCategory, options: cats)
                .presentationDetents([.height(260)])
        }
    }

    private func switchType(to newType: RecordType) {
        categoryByType[editType] = editCategory
        editType = newType
        editCategory = categoryByType[newType] ?? CategoryManager.defaultCat(for: newType)
    }

    private func saveEdit() {
        fields.type = editType
        fields.merchant = editMerchant
        fields.amount = editAmount == 0 ? "" : String(format: "%.2f", editAmount)
        fields.category = editCategory
        fields.note = editNote
        onSave()
    }
}
