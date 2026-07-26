# EditRow Refactor & Test Coverage — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract duplicate edit modal logic into shared EditRowOverlay/TypeToggle components, add Record.matchesSearch pure function, and cover MathCalculator + search filter with unit tests.

**Architecture:** Two new reusable components (TypeToggle, EditRowOverlay) replace inline duplicated code in AIConfirmView, ManualEntryView, and EditExpenseView. Record gets a pure-function extension for filter logic. Tests go in the existing test target.

**Tech Stack:** SwiftUI, Swift Testing, Xcode project (花计2046.xcodeproj)

---

### Task 1: Create TypeToggle component

**Files:**
- Create: `Views/TypeToggle.swift`

A stateless presentational component: two-button segmented control for 收入/支出. Does NOT use `@Binding` — parent passes current type via `let` and handles state via `onSelect` callback.

Button colors match existing convention:
- 收入 active: green bg + white text; inactive: white bg + green text
- 支出 active: brandStart bg + white text; inactive: white bg + brandStart text

- [ ] **Step 1: Create TypeToggle.swift**

```swift
import SwiftUI

struct TypeToggle: View {
    let type: RecordType
    let onSelect: (RecordType) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { onSelect(.income) }) {
                Text("收入")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(type == .income ? .white : .green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(type == .income ? Color.green : Color.white)
                    .cornerRadius(7)
            }
            Button(action: { onSelect(.expense) }) {
                Text("支出")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(type == .expense ? .white : AppTheme.brandStart)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(type == .expense ? AppTheme.brandStart : Color.white)
                    .cornerRadius(7)
            }
        }
        .background(AppTheme.background)
        .cornerRadius(8)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add 花计2046/Views/TypeToggle.swift
git commit -m "feat: add TypeToggle component for 收入/支出 toggle"
```

---

### Task 2: Refactor EditExpenseView — use TypeToggle

**Files:**
- Modify: `Views/EditExpenseView.swift`

Replace the inline HStack (lines 62-91) with TypeToggle. Keep the `.onChange(of: recordType)` + categoryByType logic exactly as-is. Also keep `.padding(.horizontal, 16)` on the toggle.

- [ ] **Step 1: Replace inline HStack with TypeToggle**

Find lines 61-91 in EditExpenseView.swift:
```swift
// 收支类型
HStack(spacing: 0) {
    Button(action: { recordType = .income }) { ... }
    Button(action: { recordType = .expense }) { ... }
}
.background(AppTheme.background)
.cornerRadius(8)
.padding(.horizontal, 16)
.onChange(of: recordType) { newType in ... }
```

Replace with:
```swift
TypeToggle(type: recordType, onSelect: { recordType = $0 })
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
```

- [ ] **Step 2: Commit**

```bash
git add 花计2046/Views/EditExpenseView.swift
git commit -m "refactor: replace inline 收支 toggle with TypeToggle in EditExpenseView"
```

---

### Task 3: Create EditRowOverlay component

**Files:**
- Create: `Views/EditRowOverlay.swift`

Shared overlay for editing a single expense/income row. Internal state management:
- Initializes `@State private var editAmount: Double` from `fields.amount` on appear
- On save: converts editAmount back to String in `fields.amount`
- Category picker uses existing `CategoryWheelPicker`
- Name field uses `KeyboardDoneTextField` (defined in AIConfirmView.swift)
- Note field uses `KeyboardDoneTextEditor` (defined in AIConfirmView.swift)
- Byte limits: name 50 UTF-8 bytes, note 200 UTF-8 bytes

- [ ] **Step 1: Create EditRowOverlay.swift**

```swift
import SwiftUI

struct EditRowOverlay: View {
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

    private let expenseCategories = ["餐饮", "交通", "购物", "娱乐", "住房", "日用", "服饰", "通讯", "医疗", "教育", "其他"]
    private let incomeCategories = ["工资", "奖金", "兼职", "投资收益", "理财", "礼金", "退款", "其他"]
    private var categories: [String] { editType == .expense ? expenseCategories : incomeCategories }

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
            .frame(maxWidth: .infinity)
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
                                .foregroundColor(editType == .expense ? .white : AppTheme.brandStart)
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                                .background(editType == .expense ? AppTheme.brandStart : Color.clear)
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
                            Text("¥").font(.system(size: 17, weight: .medium)).foregroundColor(AppTheme.textTertiary)
                            AmountTextField(amount: $editAmount, font: .systemFont(ofSize: 17), textColor: editType == .income ? UIColor.systemGreen : UIColor(AppTheme.textSecondary))
                                .frame(maxWidth: .infinity)
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
            let cats = editType == .expense ? expenseCategories : incomeCategories
            CategoryWheelPicker(selection: $editCategory, options: cats)
                .presentationDetents([.height(260)])
        }
    }

    private func switchType(to newType: RecordType) {
        categoryByType[editType] = editCategory
        editType = newType
        editCategory = categoryByType[newType] ?? (newType == .income ? "工资" : "餐饮")
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
```

- [ ] **Step 2: Commit**

```bash
git add 花计2046/Views/EditRowOverlay.swift
git commit -m "feat: add EditRowOverlay shared edit modal component"
```

---

### Task 4: Refactor AIConfirmView — use EditRowOverlay + TypeToggle

**Files:**
- Modify: `Views/AIConfirmView.swift`

Replace the inline edit overlay (the large `if editingIndex != nil { ... }` block starting around line 230) with `EditRowOverlay`. Replace the inline type toggle HStack inside the edit overlay with TypeToggle. Keep `typeHistory`, `editCategoryByType` in the parent view.

The parent AIConfirmView maintains:
- `editingIndex` (controls show/hide)
- `editFields: EditableFields` (state for the overlay binding)
- `editCategoryByType` (shared with overlay via `@Binding`)

- [ ] **Step 1: Replace inline edit overlay + TypeToggle with EditRowOverlay + TypeToggle**

Add state to AIConfirmView:
```swift
@State private var editFields = EditRowOverlay.EditableFields(
    type: .expense, merchant: "", amount: "", category: "餐饮", note: ""
)
```

Replace the `if editingIndex != nil { ... }` block (the overlay + type toggle inside it) with:
```swift
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
```

Also remove these now-unused @State vars from AIConfirmView:
- `editType`, `editName`, `editAmount`, `editCategory`, `editNote`, `isNewEditRow`, `showCategoryPicker`

Keep `typeHistory` (used by batch toggle logic) and `editCategoryByType`.

- [ ] **Step 2: Commit**

```bash
git add 花计2046/Views/AIConfirmView.swift
git commit -m "refactor: replace inline edit modal with EditRowOverlay in AIConfirmView"
```

---

### Task 5: Refactor ManualEntryView — use EditRowOverlay + TypeToggle

**Files:**
- Modify: `Views/ManualEntryView.swift`

Same pattern as Task 4. Replace inline edit overlay with EditRowOverlay + TypeToggle.

The `isNewRow` logic stays in ManualEntryView's `confirmEdit()` function.

- [ ] **Step 1: Replace inline edit overlay + TypeToggle with EditRowOverlay + TypeToggle**

Add state:
```swift
@State private var editFields = EditRowOverlay.EditableFields(
    type: .expense, merchant: "", amount: "", category: "餐饮", note: ""
)
```

Replace the `if editingIndex != nil { ... }` block with:
```swift
if editingIndex != nil {
    Color.black.opacity(0.35)
        .ignoresSafeArea()
        .onTapGesture { cancelEdit() }

    EditRowOverlay(
        fields: $editFields,
        categoryByType: $editCategoryByType,
        onSave: {
            if isNewRow {
                var r = ManualEntryRow()
                r.type = editFields.type
                r.merchant = editFields.merchant
                r.amount = editFields.amount
                r.category = editFields.category
                r.note = editFields.note
                rows.append(r)
            } else if let idx = editingIndex, idx < rows.count {
                let oldType = rows[idx].type
                rows[idx].type = editFields.type
                rows[idx].merchant = editFields.merchant
                rows[idx].amount = editFields.amount
                rows[idx].category = editFields.category
                rows[idx].note = editFields.note
                if oldType != editFields.type {
                    var h = typeHistory[rows[idx].id, default: [:]]
                    h[oldType] = rows[idx].category
                    typeHistory[rows[idx].id] = h
                }
            }
            isNewRow = false
            editingIndex = nil
        },
        onCancel: { cancelEdit() }
    )
    .onAppear {
        editType = editingIndex.map { rows[$0].type } ?? .expense
        if let idx = editingIndex, idx < rows.count {
            let row = rows[idx]
            editFields = EditRowOverlay.EditableFields(
                type: row.type,
                merchant: row.merchant,
                amount: row.amount,
                category: row.category,
                note: row.note
            )
            editCategoryByType[row.type] = row.category
        } else {
            editFields = EditRowOverlay.EditableFields(
                type: .expense, merchant: "", amount: "", category: rows.last?.category ?? "餐饮", note: ""
            )
        }
    }
    .id(editingIndex)
}
```

Remove now unused @State vars: `editType`, `editMerchant`, `editAmount`, `editCategory`, `editNote`, `showEditCategoryPicker`.

Keep `isNewRow`, `typeHistory`, `editCategoryByType`.

The `cancelEdit()` and `confirmEdit()` functions remain but `confirmEdit()` no longer needs to set individual fields (overlay handles that). Actually `confirmEdit()` can be removed — its logic is now in the `onSave` callback.

Remove the `rowCardView` `.sheet` modifier for `showEditCategoryPicker` (overlay handles it internally).

- [ ] **Step 2: Commit**

```bash
git add 花计2046/Views/ManualEntryView.swift
git commit -m "refactor: replace inline edit modal with EditRowOverlay in ManualEntryView"
```

---

### Task 6: Extract Record.matchesSearch + refactor ExpenseListView

**Files:**
- Modify: `Models/Record.swift`
- Modify: `Views/ExpenseListView.swift`

Add a pure function extension on Record for search/filter logic. Replace the inline filter in `searchGrouped` with a call to `matchesSearch`.

- [ ] **Step 1: Add matchesSearch extension to Record.swift**

Add after the `Record` struct (before or after `MonthRecordGroup`):
```swift
extension Record {
    func matchesSearch(
        searchText: String,
        searchNote: String,
        searchCategory: String,
        searchYear: String,
        searchMonth: String
    ) -> Bool {
        let matchMerchant = searchText.isEmpty || merchant.localizedCaseInsensitiveContains(searchText)
        let matchNote = searchNote.isEmpty || (note?.localizedCaseInsensitiveContains(searchNote) ?? false)

        let matchCategory: Bool
        if searchCategory.isEmpty {
            matchCategory = true
        } else if searchCategory == "其他支出" {
            matchCategory = category == "其他" && isExpense
        } else if searchCategory == "其他收入" {
            matchCategory = category == "其他" && isIncome
        } else {
            matchCategory = category == searchCategory
        }

        let cleanYear = searchYear.replacingOccurrences(of: "年", with: "")
        let cleanMonth = searchMonth.replacingOccurrences(of: "月", with: "")
        let matchYear = cleanYear.isEmpty || month.hasPrefix(cleanYear)
        let matchMonth = cleanMonth.isEmpty || month.hasSuffix(cleanMonth)

        return matchMerchant && matchNote && matchCategory && matchYear && matchMonth
    }
}
```

- [ ] **Step 2: Update ExpenseListView.searchGrouped to use matchesSearch**

In ExpenseListView.swift, replace the filter block inside `searchGrouped`:
```swift
// BEFORE (inside searchGrouped computed property):
let filtered = typeFiltered.filter { e in
    let matchMerchant = supabaseService.sharedSearchText.isEmpty || ...
    ...
}

// AFTER:
let filtered = typeFiltered.filter { e in
    e.matchesSearch(
        searchText: supabaseService.sharedSearchText,
        searchNote: supabaseService.sharedSearchNote,
        searchCategory: supabaseService.sharedSearchCategory,
        searchYear: supabaseService.sharedSearchYear,
        searchMonth: supabaseService.sharedSearchMonth
    )
}
```

- [ ] **Step 3: Commit**

```bash
git add 花计2046/Models/Record.swift 花计2046/Views/ExpenseListView.swift
git commit -m "refactor: extract Record.matchesSearch pure function, inline filter logic"
```

---

### Task 7: Write MathCalculator unit tests

**Files:**
- Modify: `__2046Tests/__2046Tests.swift`

Add MathCalculator test cases. Use Swift Testing framework (already imported).

- [ ] **Step 1: Add MathCalculatorTests struct to __2046Tests.swift**

```swift
import Testing
@testable import __2046

// ... existing __2046Tests struct ...

struct MathCalculatorTests {
    @Test func simpleAddition() {
        #expect(MathCalculator.evaluate("35+20") == 55)
    }

    @Test func multiplicationPrecedence() {
        #expect(MathCalculator.evaluate("3+2*4") == 11)
    }

    @Test func pureText_noFormula() {
        #expect(MathCalculator.containsFormula("午餐") == false)
    }

    @Test func chineseMixedText() {
        let result = MathCalculator.preprocess("午餐35+20超市")
        #expect(result == "午餐 55 (35+20) 超市")
    }

    @Test func chainedAddition() {
        let result = MathCalculator.preprocess("35+20+15")
        #expect(result == "70 (35+20+15)")
    }

    @Test func zeroInput_returnsNil() {
        let result = MathCalculator.evaluate("")
        #expect(result == nil)
    }

    @Test func fullWidthOperators() {
        #expect(MathCalculator.evaluate("3×4") == 12)
        #expect(MathCalculator.evaluate("8÷2") == 4)
    }

    @Test func subtraction() {
        #expect(MathCalculator.evaluate("100-35") == 65)
    }

    @Test func division() {
        #expect(MathCalculator.evaluate("10/3") == 3.3333333333333335)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add 花计2046/__2046Tests/__2046Tests.swift
git commit -m "test: add MathCalculator unit tests"
```

---

### Task 8: Write search filter unit tests

**Files:**
- Modify: `__2046Tests/__2046Tests.swift`

Add tests for `Record.matchesSearch`. Need test Record instances.

- [ ] **Step 1: Add SearchFilterTests struct to __2046Tests.swift**

```swift
struct SearchFilterTests {
    private let testExpense = Record(
        id: UUID(), userId: UUID(), type: .expense,
        amount: 35.5, category: "餐饮", merchant: "星巴克咖啡",
        date: Date(), note: "周末消费"
    )
    private let testIncome = Record(
        id: UUID(), userId: UUID(), type: .income,
        amount: 5000, category: "工资", merchant: "公司",
        date: Date(), note: "七月工资"
    )
    private let testOtherExpense = Record(
        id: UUID(), userId: UUID(), type: .expense,
        amount: 100, category: "其他", merchant: "杂项",
        date: Date(), note: nil
    )

    @Test func emptySearch_matchesAll() {
        #expect(testExpense.matchesSearch(
            searchText: "", searchNote: "", searchCategory: "",
            searchYear: "", searchMonth: ""
        ))
        #expect(testIncome.matchesSearch(
            searchText: "", searchNote: "", searchCategory: "",
            searchYear: "", searchMonth: ""
        ))
    }

    @Test func searchByMerchant() {
        #expect(testExpense.matchesSearch(
            searchText: "星巴克", searchNote: "", searchCategory: "",
            searchYear: "", searchMonth: ""
        ))
        #expect(!testIncome.matchesSearch(
            searchText: "星巴克", searchNote: "", searchCategory: "",
            searchYear: "", searchMonth: ""
        ))
    }

    @Test func searchByCategory() {
        #expect(testExpense.matchesSearch(
            searchText: "", searchNote: "", searchCategory: "餐饮",
            searchYear: "", searchMonth: ""
        ))
        #expect(!testIncome.matchesSearch(
            searchText: "", searchNote: "", searchCategory: "餐饮",
            searchYear: "", searchMonth: ""
        ))
    }

    @Test func searchOtherExpense() {
        #expect(testOtherExpense.matchesSearch(
            searchText: "", searchNote: "", searchCategory: "其他支出",
            searchYear: "", searchMonth: ""
        ))
        #expect(!testExpense.matchesSearch(
            searchText: "", searchNote: "", searchCategory: "其他支出",
            searchYear: "", searchMonth: ""
        ))
    }

    @Test func searchByNote() {
        #expect(testExpense.matchesSearch(
            searchText: "", searchNote: "周末", searchCategory: "",
            searchYear: "", searchMonth: ""
        ))
        #expect(!testIncome.matchesSearch(
            searchText: "", searchNote: "周末", searchCategory: "",
            searchYear: "", searchMonth: ""
        ))
    }

    @Test func combinedSearch() {
        #expect(testExpense.matchesSearch(
            searchText: "星巴克", searchNote: "周末", searchCategory: "餐饮",
            searchYear: "", searchMonth: ""
        ))
        #expect(!testExpense.matchesSearch(
            searchText: "星巴克", searchNote: "不存在", searchCategory: "餐饮",
            searchYear: "", searchMonth: ""
        ))
    }

    @Test func nilNote_doesNotCrash() {
        #expect(testOtherExpense.matchesSearch(
            searchText: "", searchNote: "任何文字", searchCategory: "",
            searchYear: "", searchMonth: ""
        ) == false)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add 花计2046/__2046Tests/__2046Tests.swift
git commit -m "test: add Record.matchesSearch unit tests"
```

---

### Self-Review Checklist

1. **Spec coverage:** All 4 spec goals covered (EditRowOverlay, TypeToggle, MathCalculator tests, search filter extraction+tests).
2. **Placeholder scan:** No TBD, TODO, or vague steps. Every step has complete code.
3. **Type consistency:** `EditableFields` type used consistently across Tasks 3-5. `matchesSearch` signatures match in Tasks 6 and 8.
4. **Safety:** No changes to EditExpenseView's full-screen edit layout. CategoryEditPicker left untouched. AmountTextField/KeyboardDoneTextField/KeyboardDoneTextEditor referenced from their existing global definitions.
