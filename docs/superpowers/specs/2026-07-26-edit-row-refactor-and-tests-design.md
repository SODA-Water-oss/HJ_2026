# EditRow 重构 & 测试覆盖 — 设计文档

## 背景

花计2046 中 AIConfirmView 和 ManualEntryView 各自内联了一个几乎完全重复的弹出式编辑卡（类别选择、收支切换、名称/金额/备注编辑），三处 View 也重复了相同的收支切换按钮组 + categoryByType 历史记录逻辑。同时核心业务逻辑（MathCalculator 算术求值、搜索过滤）没有单元测试覆盖。

## 目标

1. **消除 AIConfirmView 和 ManualEntryView 中的弹出编辑卡重复代码**，抽取为 `EditRowOverlay` 组件。
2. **消除三处 View 的收支切换按钮重复**，抽取为 `TypeToggle` 小组件。
3. **为 MathCalculator 增加单元测试**，覆盖求值、公式预处理、纯文本判断、边界情况。
4. **将搜索过滤逻辑从计算属性拆为可测试的函数**，增加单元测试。

## 范围

### 包含

- 新建 `Views/EditRowOverlay.swift` — 弹出式编辑卡组件
- 新建 `Views/TypeToggle.swift` — 收支切换按钮组组件
- 修改 `AIConfirmView.swift` — 用 `EditRowOverlay` 替换内联编辑弹窗
- 修改 `ManualEntryView.swift` — 用 `EditRowOverlay` 替换内联编辑弹窗
- 修改 `EditExpenseView.swift` — 用 `TypeToggle` 替换收支切换 HStack
- 修改 `AIConfirmView.swift` — 用 `TypeToggle` 替换编辑卡内的收支切换 HStack
- 修改 `ManualEntryView.swift` — 用 `TypeToggle` 替换编辑卡内的收支切换 HStack
- 为 `MathCalculator` 写单元测试（`__2046Tests` target）
- 抽取搜索过滤逻辑为 `Record.matchesSearch(searchParams:)` 扩展方法
- 为搜索过滤逻辑写单元测试

### 不包含

- 不重构 EditExpenseView 的全屏编辑布局（形态差异大，无重复）
- 不改动网络层、数据库层、GeminiService、SupabaseService
- 不改动 UI 测试
- 不改动 App 主入口、导航结构、主题
- 不引入新的第三方依赖

## 设计

### EditRowOverlay

```swift
struct EditRowOverlay: View {
    struct EditableFields {
        var type: RecordType
        var merchant: String
        var amount: String   // 保持字符串态，避免 Double 精度问题
        var category: String
        var note: String
    }

    @Binding var fields: EditableFields
    @Binding var categoryByType: [RecordType: String]  // 父视图和 overlay 共享此状态
    var onSave: () -> Void
    var onCancel: () -> Void
}
```

- 内部管理临时编辑状态（tempSelection 等）
- 类别点击触发 `CategoryWheelPicker` sheet
- 保存时将临时状态写回 `fields` 并调用 `onSave`
- 取消时恢复原始值
- 父视图控制显示/隐藏（`editingIndex != nil`）

### TypeToggle

```swift
struct TypeToggle: View {
    @Binding var type: RecordType
    var onTypeChange: ((RecordType) -> Void)?

    // 内部维护 activeType 和动画
}
```

- 纯 UI 组件，不处理 categoryByType 逻辑
- 类型变化时回调，父视图自行维护 category 切换

### Record.matchesSearch

```swift
extension Record {
    func matchesSearch(
        searchText: String,
        searchNote: String,
        searchCategory: String,
        searchYear: String,
        searchMonth: String
    ) -> Bool
}
```

- 纯函数，不依赖 SupabaseService 实例
- 可独立单元测试

## 数据流

- `EditRowOverlay` 接收 `@Binding` fields，父视图持有真实数据
- 用户在 overlay 中编辑临时状态 → 点击保存 → 写回 binding → 父视图更新 parsedItems / rows
- categoryByType 和 typeHistory 仍在父视图维护（因涉及批量切换的撤销逻辑）

## 测试计划

### MathCalculatorTests

| 测试 | 输入 | 期望 |
|------|------|------|
| 简单加法 | `"35+20"` | `evaluate` → 55 |
| 乘除优先 | `"3+2*4"` | `evaluate` → 11 |
| 纯文本 | `"午餐"` | `containsFormula` → false |
| 中文混写 | `"午餐35+20超市"` | `preprocess` → `"午餐 55 (35+20) 超市"` |
| 连算 | `"35+20+15"` | `preprocess` → `"70 (35+20+15)"` |
| 超大金额 | `"9999999.99+1"` | 实际会超上限，但求值器应正常返回 |
| 空输入 | `""` | `evaluate` → nil |
| ×÷ 全角 | `"3×4"` | `evaluate` → 12 |

### SearchFilterTests

| 测试 | 输入 | 期望 |
|------|------|------|
| 空搜索 | 默认参数 | 匹配所有记录 |
| 按名称搜索 | `searchText: "星巴克"` | 仅匹配名称含"星巴克"的记录 |
| 按类别搜索 | `searchCategory: "餐饮"` | 仅匹配餐饮类 |
| 按类型搜索 | 结合 type 过滤 | 匹配正确收/支 |
| 组合搜索 | 名称 + 类别 + 月份 | 匹配所有条件 |
| 特殊类别"其他支出" | `searchCategory: "其他支出"` | 匹配 `category == "其他" && isExpense` |
| 年份/月份前缀 | `searchYear: "2026"` | 匹配 `month.hasPrefix("2026")` |

## 风险

### 注意

- EditRowOverlay 内部用 `@State private var editAmount: Double` 管理临时金额，初始化时从 `fields.amount` 解析，保存时格式化为 String 写回。
- `CategoryEditPicker`（EditExpenseView 私有）和 `CategoryWheelPicker`（WheelPickers）视觉及行为细节不同，不做合并。
- ManualEntryView 的 amount 存为 `String`，传入 overlay 时直接绑定 `fields.amount`。
- AIConfirmView 的 amount 存为 `Double`，overlay 出现/保存时做一次 String↔Double 转换。
- 批量切换逻辑（转收入/转支出）中的 `typeHistory` 需保持独立，不与 overlay 冲突。
