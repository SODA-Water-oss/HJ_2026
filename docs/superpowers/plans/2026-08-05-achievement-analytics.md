# 个人收支成就系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在分析页新增「成就总览」，包含财务健康分、冲刺目标、周 streak、24 角星徽章（周里程碑 + 铁铜银金月度等级），并支持本地持久化与异常保护。

**Architecture:** 独立 `AchievementEngine` 负责纯计算（周期汇总、健康分、streak、徽章审核），`AchievementManager` 作为 `@MainActor ObservableObject` 订阅账本数据、调用 Engine、原子持久化并发布快照，`AnalyticsAchievementView` 和 `GoalManagementSheet` 只读快照并负责 UI。所有新数据先本地 JSON 持久化，接口预留云同步。

**Tech Stack:** SwiftUI、Combine、Swift Testing、Xcode 工程（iOS 17，文件系统同步组自动包含新文件）。

---

## File Structure

- Create: `花计2046/Models/AchievementModels.swift` — 成就数据模型。
- Create: `花计2046/Services/AchievementEngine.swift` — 纯计算引擎。
- Create: `花计2046/Services/AchievementPersistence.swift` — 原子 JSON 持久化。
- Create: `花计2046/Services/AchievementManager.swift` — 状态管理、订阅、协调。
- Create: `花计2046/Views/AnalyticsAchievementView.swift` — 成就总览 UI。
- Create: `花计2046/Views/GoalManagementSheet.swift` — 目标管理 Sheet。
- Create: `花计2046Tests/AchievementEngineTests.swift` — Engine 单元测试。
- Create: `花计2046Tests/AchievementPersistenceTests.swift` — 持久化单元测试。
- Modify: `花计2046/Services/SupabaseService.swift` — 增加记录加载错误标记。
- Modify: `花计2046/Views/AnalyticsView.swift` — 在顶部接入成就区块。

## Execution Prerequisite

当前 `develop` 工作区包含已完成的账本搜索优化、分析页快照优化、用户设置统一等未提交改动。开始本计划前，先与用户确认将这些改动提交（例如 `feat: 优化搜索与分析页性能`），或明确以当前工作区为基础继续，避免后续 diff 混杂。

---

### Task 1: SupabaseService 记录加载错误标记

**Files:**
- Modify: `花计2046/Services/SupabaseService.swift`

- [ ] **Step 1: 添加 Published 错误标记**

在 `SupabaseService` 的 `@Published var isRecordsLoading` 后新增：

```swift
@Published var recordsLoadError = false
```

- [ ] **Step 2: 刷新失败时置位、成功时复位**

把 `refreshAllRecords(force:)` 改为：

```swift
func refreshAllRecords(force: Bool = false) async {
    let now = Date()
    if !force, now.timeIntervalSince(lastFetchTime) < 3 { return }
    lastFetchTime = now
    isRecordsLoading = true
    recordsLoadError = false
    do {
        let records = try await fetchAllRecords()
        allRecords = records
        expenses = records.filter { $0.isExpense }
        incomes = records.filter { $0.isIncome }
    } catch {
        recordsLoadError = true
        Log.error("刷新全部记录失败: \(error)")
    }
    isRecordsLoading = false
}
```

- [ ] **Step 3: 构建验证**

Run: `xcodebuild build -project 花计2046.xcodeproj -scheme 花计2046 -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath Build -clonedSourcePackagesDirPath 花计2046.xcodeproj/project.xcworkspace/xcshareddata/swiftpm`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: 提交**

```bash
git add 花计2046/Services/SupabaseService.swift
git commit -m "feat: 增加记录加载错误标记"
```

---

### Task 2: AchievementModels 与模型测试

**Files:**
- Create: `花计2046/Models/AchievementModels.swift`
- Create: `花计2046Tests/AchievementEngineTests.swift`

- [ ] **Step 1: 写模型行为测试**

在 `花计2046Tests/AchievementEngineTests.swift` 写入：

```swift
import Foundation
import Testing
@testable import 花计2046

struct AchievementModelTests {
    @Test func goalProgressPercent() {
        let goal = FinancialGoal(name: "旅行", targetAmount: 10000, startingAmount: 2000)
        let progress = AchievementEngine.goalProgress(goal: goal, savedAmount: 5000)
        #expect(progress.percent == 50)
    }

    @Test func badgeStateIDIsStable() {
        let state = BadgeState(badgeType: .monthGold, isHeld: false, latestAwardedAt: nil, latestRevokedAt: nil)
        #expect(state.id == "monthGold")
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild test -project 花计2046.xcodeproj -scheme 花计2046 -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath Build -clonedSourcePackagesDirPath 花计2046.xcodeproj/project.xcworkspace/xcshareddata/swiftpm -only-testing:花计2046Tests/AchievementModelTests`
Expected: FAIL，编译报类型不存在。

- [ ] **Step 3: 创建模型文件**

`花计2046/Models/AchievementModels.swift`：

```swift
import Foundation

enum AchievementPeriodType: String, Codable {
    case week
    case month
}

struct FinancialGoal: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var targetAmount: Double
    var startingAmount: Double
    var deadline: Date?
    var isActive: Bool
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Double,
        startingAmount: Double = 0,
        deadline: Date? = nil,
        isActive: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.startingAmount = startingAmount
        self.deadline = deadline
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

struct BudgetSetting: Codable, Equatable {
    var monthlyBudget: Double?

    init(monthlyBudget: Double? = nil) {
        self.monthlyBudget = monthlyBudget
    }
}

struct PeriodSummary: Codable, Equatable {
    let key: String
    let periodType: AchievementPeriodType
    var income: Double
    var expense: Double
    var largestExpense: Double
    var recordCount: Int
    var updatedAt: Date

    init(
        key: String,
        periodType: AchievementPeriodType,
        income: Double = 0,
        expense: Double = 0,
        largestExpense: Double = 0,
        recordCount: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.key = key
        self.periodType = periodType
        self.income = income
        self.expense = expense
        self.largestExpense = largestExpense
        self.recordCount = recordCount
        self.updatedAt = updatedAt
    }
}

enum BadgeType: String, Codable, CaseIterable, Equatable {
    case week1
    case week4
    case week8
    case week12
    case week26
    case week52
    case monthIron
    case monthCopper
    case monthSilver
    case monthGold
}

enum BadgeEventType: String, Codable {
    case awarded
    case revoked
}

struct BadgeAwardEvent: Codable, Equatable {
    let badgeType: BadgeType
    let periodKey: String
    let event: BadgeEventType
    let occurredAt: Date

    init(badgeType: BadgeType, periodKey: String, event: BadgeEventType, occurredAt: Date = Date()) {
        self.badgeType = badgeType
        self.periodKey = periodKey
        self.event = event
        self.occurredAt = occurredAt
    }
}

struct BadgeState: Codable, Equatable, Identifiable {
    let badgeType: BadgeType
    var isHeld: Bool
    var latestAwardedAt: Date?
    var latestRevokedAt: Date?

    var id: String { badgeType.rawValue }

    init(badgeType: BadgeType, isHeld: Bool, latestAwardedAt: Date?, latestRevokedAt: Date?) {
        self.badgeType = badgeType
        self.isHeld = isHeld
        self.latestAwardedAt = latestAwardedAt
        self.latestRevokedAt = latestRevokedAt
    }
}

struct HealthDimensionScore: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let score: Int
    let value: Double?

    init(id: String, name: String, score: Int, value: Double?) {
        self.id = id
        self.name = name
        self.score = score
        self.value = value
    }
}

struct HealthMetrics: Codable, Equatable {
    let score: Int
    let savingsRate: Double?
    let budgetControl: Double?
    let stability: Double?
    let trend: Double?
    let largeExpenseRatio: Double?
    let dimensions: [HealthDimensionScore]

    init(
        score: Int,
        savingsRate: Double?,
        budgetControl: Double?,
        stability: Double?,
        trend: Double?,
        largeExpenseRatio: Double?,
        dimensions: [HealthDimensionScore]
    ) {
        self.score = score
        self.savingsRate = savingsRate
        self.budgetControl = budgetControl
        self.stability = stability
        self.trend = trend
        self.largeExpenseRatio = largeExpenseRatio
        self.dimensions = dimensions
    }
}

struct GoalProgress: Codable, Equatable {
    let goal: FinancialGoal
    let savedAmount: Double
    let percent: Double
    let estimatedCompletion: Date?

    init(goal: FinancialGoal, savedAmount: Double, percent: Double, estimatedCompletion: Date?) {
        self.goal = goal
        self.savedAmount = savedAmount
        self.percent = percent
        self.estimatedCompletion = estimatedCompletion
    }
}

struct WeeklySummary: Codable, Equatable {
    let weekKey: String
    let budget: Double
    let expense: Double
    let isOnTrack: Bool
    let daysLeft: Int

    init(weekKey: String, budget: Double, expense: Double, isOnTrack: Bool, daysLeft: Int) {
        self.weekKey = weekKey
        self.budget = budget
        self.expense = expense
        self.isOnTrack = isOnTrack
        self.daysLeft = daysLeft
    }
}

struct AchievementSnapshot: Codable, Equatable {
    var goals: [FinancialGoal]
    var budget: BudgetSetting
    var periodSummaries: [String: PeriodSummary]
    var weekStreak: Int
    var badgeStates: [BadgeState]
    var badgeEvents: [BadgeAwardEvent]
    var health: HealthMetrics
    var hasCurrentMonthRecords: Bool
    var currentGoalProgress: GoalProgress?
    var weeklySummary: WeeklySummary?
    var schemaVersion: Int

    init(
        goals: [FinancialGoal] = [],
        budget: BudgetSetting = BudgetSetting(),
        periodSummaries: [String: PeriodSummary] = [:],
        weekStreak: Int = 0,
        badgeStates: [BadgeState] = [],
        badgeEvents: [BadgeAwardEvent] = [],
        health: HealthMetrics,
        hasCurrentMonthRecords: Bool = false,
        currentGoalProgress: GoalProgress? = nil,
        weeklySummary: WeeklySummary? = nil,
        schemaVersion: Int = 1
    ) {
        self.goals = goals
        self.budget = budget
        self.periodSummaries = periodSummaries
        self.weekStreak = weekStreak
        self.badgeStates = badgeStates
        self.badgeEvents = badgeEvents
        self.health = health
        self.hasCurrentMonthRecords = hasCurrentMonthRecords
        self.currentGoalProgress = currentGoalProgress
        self.weeklySummary = weeklySummary
        self.schemaVersion = schemaVersion
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild test -project 花计2046.xcodeproj -scheme 花计2046 -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath Build -clonedSourcePackagesDirPath 花计2046.xcodeproj/project.xcworkspace/xcshareddata/swiftpm -only-testing:花计2046Tests/AchievementModelTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add 花计2046/Models/AchievementModels.swift 花计2046Tests/AchievementEngineTests.swift
git commit -m "feat: 成就数据模型"
```

---

### Task 3: 周期汇总与预算口径

**Files:**
- Modify: `花计2046/Services/AchievementEngine.swift`
- Modify: `花计2046Tests/AchievementEngineTests.swift`

- [ ] **Step 1: 写周期汇总测试**

在测试文件追加：

```swift
struct AchievementPeriodTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func weekKeyUsesMondayStart() {
        #expect(AchievementEngine.weekKey(for: date(2026, 8, 3), calendar: calendar) == "2026-W32")
        #expect(AchievementEngine.weekKey(for: date(2026, 8, 9), calendar: calendar) == "2026-W32")
    }

    @Test func monthKeyFormat() {
        #expect(AchievementEngine.monthKey(for: date(2026, 8, 3), calendar: calendar) == "2026-08")
    }

    @Test func summaryAggregatesRecords() {
        let expense1 = Record(userId: UUID(), type: .expense, amount: 30, category: "餐饮", merchant: "a", date: date(2026, 8, 3), currency: "¥")
        let expense2 = Record(userId: UUID(), type: .expense, amount: 70, category: "交通", merchant: "b", date: date(2026, 8, 4), currency: "¥")
        let income = Record(userId: UUID(), type: .income, amount: 500, category: "工资", merchant: "c", date: date(2026, 8, 5), currency: "¥")
        let summary = AchievementEngine.summary(records: [expense1, expense2, income], periodKey: "2026-08", periodType: .month)
        #expect(summary.income == 500)
        #expect(summary.expense == 100)
        #expect(summary.largestExpense == 70)
        #expect(summary.recordCount == 3)
    }

    @Test func referenceBudgetUses90DayAverage() {
        let records = (1...90).map { day in
            Record(userId: UUID(), type: .expense, amount: 10, category: "餐饮", merchant: "a", date: date(2026, 5, 1) + TimeInterval(day * 86_400), currency: "¥")
        }
        let budget = AchievementEngine.effectiveMonthlyBudget(
            setting: BudgetSetting(),
            records: records,
            now: date(2026, 8, 3),
            calendar: calendar
        )
        #expect(budget == 10)
    }

    @Test func manualBudgetWins() {
        let budget = AchievementEngine.effectiveMonthlyBudget(
            setting: BudgetSetting(monthlyBudget: 3000),
            records: [],
            now: date(2026, 8, 3),
            calendar: calendar
        )
        #expect(budget == 3000)
    }

    @Test func weeklyBudgetDerivation() {
        #expect(AchievementEngine.weeklyBudget(monthly: 4330) == 1000)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild test ... -only-testing:花计2046Tests/AchievementPeriodTests`
Expected: FAIL，函数不存在。

- [ ] **Step 3: 实现 Engine 周期与预算部分**

`花计2046/Services/AchievementEngine.swift`：

```swift
import Foundation

enum AchievementEngine {
    static func weekKey(for date: Date, calendar: Calendar = .current) -> String {
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return String(format: "%04d-W%02d", year, weekOfYear)
    }

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    static func summary(records: [Record], periodKey: String, periodType: AchievementPeriodType) -> PeriodSummary {
        var income = 0.0
        var expense = 0.0
        var largest = 0.0
        for record in records {
            if record.isIncome {
                income += record.amount
            } else {
                expense += record.amount
                largest = max(largest, record.amount)
            }
        }
        return PeriodSummary(
            key: periodKey,
            periodType: periodType,
            income: income,
            expense: expense,
            largestExpense: largest,
            recordCount: records.count
        )
    }

    static func summaries(records: [Record], calendar: Calendar = .current) -> [String: PeriodSummary] {
        var monthRecords: [String: [Record]] = [:]
        var weekRecords: [String: [Record]] = [:]
        for record in records {
            let month = monthKey(for: record.date, calendar: calendar)
            monthRecords[month, default: []].append(record)
            let week = weekKey(for: record.date, calendar: calendar)
            weekRecords[week, default: []].append(record)
        }
        var result: [String: PeriodSummary] = [:]
        for (key, items) in monthRecords {
            result[key] = summary(records: items, periodKey: key, periodType: .month)
        }
        for (key, items) in weekRecords {
            result[key] = summary(records: items, periodKey: key, periodType: .week)
        }
        return result
    }

    static func effectiveMonthlyBudget(setting: BudgetSetting, records: [Record], now: Date, calendar: Calendar = .current) -> Double {
        if let manual = setting.monthlyBudget, manual > 0 { return manual }
        let start = calendar.date(byAdding: .day, value: -89, to: now) ?? now
        let recent = records.filter { $0.isExpense && $0.date >= start && $0.date <= now }
        let total = recent.reduce(0) { $0 + $1.amount }
        let days = 90
        return total / Double(days) * 30.0
    }

    static func weeklyBudget(monthly: Double) -> Double {
        monthly / 4.33
    }

    static func dailyBudget(monthly: Double, monthKey: String, calendar: Calendar = .current) -> Double {
        let parts = monthKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2,
              let monthDate = calendar.date(from: DateComponents(year: parts[0], month: parts[1])),
              let dayCount = calendar.range(of: .day, in: .month, for: monthDate)?.count else {
            return monthly / 30
        }
        return monthly / Double(dayCount)
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild test ... -only-testing:花计2046Tests/AchievementPeriodTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add 花计2046/Services/AchievementEngine.swift 花计2046Tests/AchievementEngineTests.swift
git commit -m "feat: 成就周期汇总与预算口径"
```

---

### Task 4: 五维健康分

**Files:**
- Modify: `花计2046/Services/AchievementEngine.swift`
- Modify: `花计2046Tests/AchievementEngineTests.swift`

- [ ] **Step 1: 写健康分测试**

```swift
struct AchievementHealthTests {
    private let calendar = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func healthScoreWeightsSavingsRate() {
        let summaries: [String: PeriodSummary] = [
            "2026-08": PeriodSummary(key: "2026-08", periodType: .month, income: 1000, expense: 500, largestExpense: 100, recordCount: 10),
            "2026-07": PeriodSummary(key: "2026-07", periodType: .month, income: 1000, expense: 600, largestExpense: 200, recordCount: 10),
            "2026-06": PeriodSummary(key: "2026-06", periodType: .month, income: 1000, expense: 700, largestExpense: 300, recordCount: 10)
        ]
        let health = AchievementEngine.health(
            summaries: summaries,
            budget: BudgetSetting(monthlyBudget: 1000),
            now: date(2026, 8, 3),
            calendar: calendar
        )
        #expect(health.score > 0)
        #expect(health.savingsRate == 50)
        #expect(health.budgetControl == 100)
    }

    @Test func emptyDataKeepsScoreZero() {
        let health = AchievementEngine.health(
            summaries: [:],
            budget: BudgetSetting(),
            now: date(2026, 8, 3),
            calendar: calendar
        )
        #expect(health.score == 0)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild test ... -only-testing:花计2046Tests/AchievementHealthTests`
Expected: FAIL，函数不存在。

- [ ] **Step 3: 实现 health**

在 `AchievementEngine.swift` 追加：

```swift
extension AchievementEngine {
    static func health(
        summaries: [String: PeriodSummary],
        budget: BudgetSetting,
        now: Date,
        calendar: Calendar = .current
    ) -> HealthMetrics {
        let currentKey = monthKey(for: now, calendar: calendar)
        let previousKey = previousMonthKey(for: currentKey, calendar: calendar)
        let current = summaries[currentKey]
        let previous = summaries[previousKey]
        let monthly = effectiveMonthlyBudget(setting: budget, records: [], now: now, calendar: calendar)

        let savings = current.map { summary -> Double in
            guard summary.income > 0 else { return 0 }
            return (summary.income - summary.expense) / summary.income * 100
        }
        let savingsScore: Int
        switch savings ?? -1 {
        case ..<0: savingsScore = 0
        case ..<10: savingsScore = 8
        case ..<20: savingsScore = 12
        case ..<30: savingsScore = 16
        default: savingsScore = 20
        }

        let budgetScore: Int
        if let current {
            budgetScore = current.expense <= monthly ? 20 : max(0, 20 - Int((current.expense - monthly) / monthly * 100))
        } else {
            budgetScore = 0
        }

        let stabilityScore: Int
        if let current, current.expense > 0 {
            stabilityScore = current.expense <= monthly * 0.6 ? 20 : current.expense <= monthly ? 16 : current.expense <= monthly * 1.2 ? 10 : 4
        } else {
            stabilityScore = 0
        }

        let trendScore: Int
        if let current, let previous {
            let currentNet = current.income - current.expense
            let previousNet = previous.income - previous.expense
            trendScore = currentNet >= 0 && currentNet >= previousNet ? 20 : currentNet >= 0 ? 14 : previousNet > currentNet ? 6 : 10
        } else {
            trendScore = 0
        }

        let largeExpenseScore: Int
        if let current, current.expense > 0 {
            let ratio = current.largestExpense / current.expense
            largeExpenseScore = ratio <= 0.2 ? 20 : ratio <= 0.35 ? 14 : ratio <= 0.5 ? 8 : 4
        } else {
            largeExpenseScore = 0
        }

        let dimensions = [
            HealthDimensionScore(id: "savings", name: "储蓄率", score: savingsScore, value: savings),
            HealthDimensionScore(id: "budget", name: "预算控制", score: budgetScore, value: current.map { $0.expense }),
            HealthDimensionScore(id: "stability", name: "支出稳定性", score: stabilityScore, value: current?.expense),
            HealthDimensionScore(id: "trend", name: "结余趋势", score: trendScore, value: current.map { $0.income - $0.expense }),
            HealthDimensionScore(id: "large", name: "大额支出占比", score: largeExpenseScore, value: current.map { $0.largestExpense / max($0.expense, 1) * 100 })
        ]
        return HealthMetrics(
            score: dimensions.reduce(0) { $0 + $1.score },
            savingsRate: savings,
            budgetControl: current.map { monthly > 0 ? min(100, $0.expense / monthly * 100) : 0 },
            stability: current?.expense,
            trend: current.map { $0.income - $0.expense },
            largeExpenseRatio: current.map { $0.expense > 0 ? $0.largestExpense / $0.expense * 100 : 0 },
            dimensions: dimensions
        )
    }

    static func previousMonthKey(for monthKey: String, calendar: Calendar = .current) -> String {
        let parts = monthKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1])),
              let previous = calendar.date(byAdding: .month, value: -1, to: date) else { return monthKey }
        return self.monthKey(for: previous, calendar: calendar)
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild test ... -only-testing:花计2046Tests/AchievementHealthTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add 花计2046/Services/AchievementEngine.swift 花计2046Tests/AchievementEngineTests.swift
git commit -m "feat: 五维健康分"
```

---

### Task 5: 周 streak

**Files:**
- Modify: `花计2046/Services/AchievementEngine.swift`
- Modify: `花计2046Tests/AchievementEngineTests.swift`

- [ ] **Step 1: 写 streak 测试**

```swift
struct AchievementStreakTests {
    private let calendar = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func streakCountsConsecutiveQualifyingWeeks() {
        let budget = 1000.0
        let summaries: [String: PeriodSummary] = [
            "2026-W30": PeriodSummary(key: "2026-W30", periodType: .week, expense: 500, recordCount: 2),
            "2026-W31": PeriodSummary(key: "2026-W31", periodType: .week, expense: 600, recordCount: 2),
            "2026-W32": PeriodSummary(key: "2026-W32", periodType: .week, expense: 800, recordCount: 2)
        ]
        let streak = AchievementEngine.currentStreak(
            summaries: summaries,
            weeklyBudget: budget,
            now: date(2026, 8, 9),
            calendar: calendar
        )
        #expect(streak == 3)
    }

    @Test func streakBreaksOnOverBudgetWeek() {
        let summaries: [String: PeriodSummary] = [
            "2026-W30": PeriodSummary(key: "2026-W30", periodType: .week, expense: 1200, recordCount: 2),
            "2026-W31": PeriodSummary(key: "2026-W31", periodType: .week, expense: 600, recordCount: 2),
            "2026-W32": PeriodSummary(key: "2026-W32", periodType: .week, expense: 800, recordCount: 2)
        ]
        let streak = AchievementEngine.currentStreak(
            summaries: summaries,
            weeklyBudget: 1000,
            now: date(2026, 8, 9),
            calendar: calendar
        )
        #expect(streak == 2)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild test ... -only-testing:花计2046Tests/AchievementStreakTests`
Expected: FAIL。

- [ ] **Step 3: 实现 currentStreak 与 weeklySummary**

```swift
extension AchievementEngine {
    static func currentStreak(
        summaries: [String: PeriodSummary],
        weeklyBudget: Double,
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard var components = weekDateComponents(weekKey(for: now, calendar: calendar), calendar: calendar),
              var weekDate = calendar.date(from: components) else { return 0 }
        var streak = 0
        var guardCount = 0
        while guardCount < 520 {
            let week = weekKey(for: weekDate, calendar: calendar)
            guard let summary = summaries[week], summary.recordCount > 0, summary.expense <= weeklyBudget else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: weekDate),
                  let nextComponents = weekDateComponents(weekKey(for: previous, calendar: calendar), calendar: calendar),
                  let nextDate = calendar.date(from: nextComponents) else { break }
            weekDate = nextDate
            guardCount += 1
        }
        return streak
    }

    static func weeklySummary(
        summaries: [String: PeriodSummary],
        monthlyBudget: Double,
        now: Date,
        calendar: Calendar = .current
    ) -> WeeklySummary {
        let key = weekKey(for: now, calendar: calendar)
        let budget = weeklyBudget(monthly: monthlyBudget)
        let expense = summaries[key]?.expense ?? 0
        let nextSunday = calendar.nextWeekend(startingAfter: now)?.start ?? now
        let daysLeft = max(0, calendar.dateComponents([.day], from: now, to: nextSunday).day ?? 0)
        return WeeklySummary(
            weekKey: key,
            budget: budget,
            expense: expense,
            isOnTrack: expense <= budget,
            daysLeft: daysLeft
        )
    }

    private static func weekDateComponents(_ weekKey: String, calendar: Calendar) -> DateComponents? {
        let parts = weekKey.replacingOccurrences(of: "W", with: "-").split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return DateComponents(weekOfYear: parts[1], yearForWeekOfYear: parts[0])
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild test ... -only-testing:花计2046Tests/AchievementStreakTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add 花计2046/Services/AchievementEngine.swift 花计2046Tests/AchievementEngineTests.swift
git commit -m "feat: 周 streak 与周小结"
```

---

### Task 6: 徽章实时审核

**Files:**
- Modify: `花计2046/Services/AchievementEngine.swift`
- Modify: `花计2046Tests/AchievementEngineTests.swift`

- [ ] **Step 1: 写徽章审核测试**

```swift
struct AchievementBadgeTests {
    private let calendar = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func weekMilestonesDeriveFromStreak() {
        let states = AchievementEngine.derivedBadgeStates(weekStreak: 12, qualifyingMonthCount: 3)
        #expect(states.first(where: { $0.badgeType == .week1 })?.isHeld == true)
        #expect(states.first(where: { $0.badgeType == .week12 })?.isHeld == true)
        #expect(states.first(where: { $0.badgeType == .week52 })?.isHeld == false)
        #expect(states.first(where: { $0.badgeType == .monthIron })?.isHeld == true)
        #expect(states.first(where: { $0.badgeType == .monthGold })?.isHeld == false)
    }

    @Test func auditAppendsAwardAndRevokeEvents() {
        let now = date(2026, 8, 3)
        let before = AchievementEngine.derivedBadgeStates(weekStreak: 11, qualifyingMonthCount: 0)
        let after = AchievementEngine.derivedBadgeStates(weekStreak: 12, qualifyingMonthCount: 0)
        let result = AchievementEngine.auditBadges(previous: before, current: after, now: now)
        #expect(result.events.contains { $0.badgeType == .week12 && $0.event == .awarded })
        #expect(!result.events.contains { $0.badgeType == .week12 && $0.event == .revoked })

        let dropped = AchievementEngine.derivedBadgeStates(weekStreak: 11, qualifyingMonthCount: 0)
        let revoked = AchievementEngine.auditBadges(previous: after, current: dropped, now: now)
        #expect(revoked.events.contains { $0.badgeType == .week12 && $0.event == .revoked })
    }

    @Test func qualifyingMonthCount() {
        let summaries: [String: PeriodSummary] = [
            "2026-04": PeriodSummary(key: "2026-04", periodType: .month, expense: 800, recordCount: 2),
            "2026-05": PeriodSummary(key: "2026-05", periodType: .month, expense: 900, recordCount: 2),
            "2026-06": PeriodSummary(key: "2026-06", periodType: .month, expense: 1100, recordCount: 2)
        ]
        let count = AchievementEngine.qualifyingMonthCount(summaries: summaries, monthlyBudget: 1000, calendar: calendar)
        #expect(count == 2)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild test ... -only-testing:花计2046Tests/AchievementBadgeTests`
Expected: FAIL。

- [ ] **Step 3: 实现徽章审核**

```swift
extension AchievementEngine {
    static func qualifyingMonthCount(summaries: [String: PeriodSummary], monthlyBudget: Double, calendar: Calendar = .current) -> Int {
        summaries.values
            .filter { $0.periodType == .month && $0.recordCount > 0 && $0.expense <= monthlyBudget }
            .count
    }

    static func derivedBadgeStates(weekStreak: Int, qualifyingMonthCount: Int) -> [BadgeState] {
        let weekThresholds: [(BadgeType, Int)] = [
            (.week1, 1), (.week4, 4), (.week8, 8), (.week12, 12), (.week26, 26), (.week52, 52)
        ]
        let monthThresholds: [(BadgeType, Int)] = [
            (.monthIron, 3), (.monthCopper, 6), (.monthSilver, 12), (.monthGold, 24)
        ]
        let weekStates = weekThresholds.map { BadgeState(badgeType: $0.0, isHeld: weekStreak >= $0.1, latestAwardedAt: nil, latestRevokedAt: nil) }
        let monthStates = monthThresholds.map { BadgeState(badgeType: $0.0, isHeld: qualifyingMonthCount >= $0.1, latestAwardedAt: nil, latestRevokedAt: nil) }
        return weekStates + monthStates
    }

    static func auditBadges(previous: [BadgeState], current: [BadgeState], now: Date) -> (states: [BadgeState], events: [BadgeAwardEvent]) {
        var events: [BadgeAwardEvent] = []
        var merged: [BadgeState] = []
        for state in current {
            let old = previous.first(where: { $0.badgeType == state.badgeType })
            var latestAward = old?.latestAwardedAt
            var latestRevoke = old?.latestRevokedAt
            if state.isHeld, old?.isHeld != true {
                latestAward = now
                events.append(BadgeAwardEvent(badgeType: state.badgeType, periodKey: state.badgeType.rawValue, event: .awarded, occurredAt: now))
            }
            if !state.isHeld, old?.isHeld == true {
                latestRevoke = now
                events.append(BadgeAwardEvent(badgeType: state.badgeType, periodKey: state.badgeType.rawValue, event: .revoked, occurredAt: now))
            }
            merged.append(BadgeState(badgeType: state.badgeType, isHeld: state.isHeld, latestAwardedAt: latestAward, latestRevokedAt: latestRevoke))
        }
        return (merged, events)
    }

    static func goalProgress(goal: FinancialGoal, savedAmount: Double) -> GoalProgress {
        let progress = goal.targetAmount > 0 ? savedAmount / goal.targetAmount * 100 : 0
        return GoalProgress(goal: goal, savedAmount: savedAmount, percent: progress, estimatedCompletion: nil)
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild test ... -only-testing:花计2046Tests/AchievementBadgeTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add 花计2046/Services/AchievementEngine.swift 花计2046Tests/AchievementEngineTests.swift
git commit -m "feat: 徽章实时审核"
```

---

### Task 7: 原子持久化

**Files:**
- Create: `花计2046/Services/AchievementPersistence.swift`
- Create: `花计2046Tests/AchievementPersistenceTests.swift`

- [ ] **Step 1: 写持久化测试**

```swift
import Foundation
import Testing
@testable import 花计2046

struct AchievementPersistenceTests {
    @Test func roundTripKeepsState() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = AchievementPersistence(fileURL: url)
        let snapshot = AchievementSnapshot(
            goals: [FinancialGoal(name: "旅行", targetAmount: 10000)],
            health: HealthMetrics(score: 50, savingsRate: nil, budgetControl: nil, stability: nil, trend: nil, largeExpenseRatio: nil, dimensions: [])
        )
        try store.save(snapshot)
        let loaded = store.load()
        #expect(loaded?.goals == snapshot.goals)
        try? FileManager.default.removeItem(at: url)
    }

    @Test func corruptFileFallsBackToNil() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try Data("not json".utf8).write(to: url)
        let store = AchievementPersistence(fileURL: url)
        #expect(store.load() == nil)
        try? FileManager.default.removeItem(at: url)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild test ... -only-testing:花计2046Tests/AchievementPersistenceTests`
Expected: FAIL。

- [ ] **Step 3: 实现持久化**

```swift
import Foundation

struct AchievementPersistence {
    let fileURL: URL

    init(fileURL: URL = AchievementPersistence.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func load() -> AchievementSnapshot? {
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: fileURL),
           let snapshot = try? decoder.decode(AchievementSnapshot.self, from: data) {
            return snapshot
        }
        let backupURL = backupURL()
        if let data = try? Data(contentsOf: backupURL),
           let snapshot = try? decoder.decode(AchievementSnapshot.self, from: data) {
            return snapshot
        }
        return nil
    }

    func save(_ snapshot: AchievementSnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: backupURL())
            try? FileManager.default.copyItem(at: fileURL, to: backupURL())
        }
        try data.write(to: fileURL, options: .atomic)
    }

    private func backupURL() -> URL {
        URL(fileURLWithPath: fileURL.path + ".bak")
    }

    private static func defaultFileURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = directory.appendingPathComponent("花计2046", isDirectory: true)
        return appDirectory.appendingPathComponent("achievements.json")
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild test ... -only-testing:花计2046Tests/AchievementPersistenceTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add 花计2046/Services/AchievementPersistence.swift 花计2046Tests/AchievementPersistenceTests.swift
git commit -m "feat: 成就原子持久化"
```

---

### Task 8: AchievementManager

**Files:**
- Create: `花计2046/Services/AchievementManager.swift`

- [ ] **Step 1: 实现 Manager**

```swift
import Foundation
import Combine

@MainActor
final class AchievementManager: ObservableObject {
    static let shared = AchievementManager()

    @Published private(set) var snapshot: AchievementSnapshot?
    @Published private(set) var isReady = false
    @Published private(set) var hasLoadError = false

    private let persistence: AchievementPersistence
    private var cancellables: Set<AnyCancellable> = []
    private var lastRecordIDs: [UUID: Record] = [:]
    private var activeRebuildID = UUID()

    private init(persistence: AchievementPersistence = AchievementPersistence()) {
        self.persistence = persistence
        snapshot = persistence.load()
        isReady = snapshot != nil

        SupabaseService.shared.$allRecords
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleReconcile() }
            .store(in: &cancellables)

        SupabaseService.shared.$isRecordsLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                guard let self, !loading else { return }
                self.scheduleReconcile()
            }
            .store(in: &cancellables)

        SupabaseService.shared.$recordsLoadError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in self?.hasLoadError = error }
            .store(in: &cancellables)
    }

    func setMonthlyBudget(_ value: Double?) {
        var current = snapshot ?? emptySnapshot()
        current.budget = BudgetSetting(monthlyBudget: value)
        publish(current)
    }

    func addGoal(name: String, targetAmount: Double, startingAmount: Double = 0, deadline: Date? = nil) {
        var current = snapshot ?? emptySnapshot()
        let goal = FinancialGoal(name: name, targetAmount: targetAmount, startingAmount: startingAmount, deadline: deadline, isActive: current.goals.isEmpty, sortOrder: current.goals.count)
        current.goals.append(goal)
        publish(current)
    }

    func deleteGoal(id: UUID) {
        guard var current = snapshot else { return }
        current.goals.removeAll { $0.id == id }
        if !current.goals.contains(where: { $0.isActive }), let first = current.goals.first {
            current.goals[current.goals.firstIndex(where: { $0.id == first.id })!].isActive = true
        }
        publish(current)
    }

    func setActiveGoal(id: UUID) {
        guard var current = snapshot else { return }
        for index in current.goals.indices {
            current.goals[index].isActive = current.goals[index].id == id
        }
        publish(current)
    }

    func reconcile() {
        let service = SupabaseService.shared
        guard !service.isRecordsLoading, !service.recordsLoadError else { return }
        let requestID = UUID()
        activeRebuildID = requestID
        let records = service.allRecords.filter { $0.displayCurrency == CategoryManager.currencySymbol }
        let existing = snapshot
        let calendar = Calendar.current
        let now = Date()
        let changedKeys = Self.changedPeriodKeys(old: lastRecordIDs, new: records, calendar: calendar)
        let existingSummaries = existing?.periodSummaries ?? [:]

        Task.detached {
            var summaries = existingSummaries
            let activeKeys = Set(records.flatMap { [
                AchievementEngine.monthKey(for: $0.date, calendar: calendar),
                AchievementEngine.weekKey(for: $0.date, calendar: calendar)
            ] })
            summaries = summaries.filter { activeKeys.contains($0.key) }
            let weekKeys = changedKeys.filter { $0.contains("W") }
            let monthKeys = changedKeys.filter { !$0.contains("W") }
            for key in weekKeys {
                let items = records.filter { AchievementEngine.weekKey(for: $0.date, calendar: calendar) == key }
                summaries[key] = AchievementEngine.summary(records: items, periodKey: key, periodType: .week)
            }
            for key in monthKeys {
                let items = records.filter { AchievementEngine.monthKey(for: $0.date, calendar: calendar) == key }
                summaries[key] = AchievementEngine.summary(records: items, periodKey: key, periodType: .month)
            }
            let monthlyBudget = AchievementEngine.effectiveMonthlyBudget(setting: existing?.budget ?? BudgetSetting(), records: records, now: now, calendar: calendar)
            let weeklyBudget = AchievementEngine.weeklyBudget(monthly: monthlyBudget)
            let health = AchievementEngine.health(summaries: summaries, budget: existing?.budget ?? BudgetSetting(), now: now, calendar: calendar)
            let streak = AchievementEngine.currentStreak(summaries: summaries, weeklyBudget: weeklyBudget, now: now, calendar: calendar)
            let monthCount = AchievementEngine.qualifyingMonthCount(summaries: summaries, monthlyBudget: monthlyBudget, calendar: calendar)
            let derived = AchievementEngine.derivedBadgeStates(weekStreak: streak, qualifyingMonthCount: monthCount)
            let audit = AchievementEngine.auditBadges(previous: existing?.badgeStates ?? [], current: derived, now: now)
            let goals = existing?.goals ?? []
            let activeGoal = goals.first(where: { $0.isActive }) ?? goals.first
            let goalStart = activeGoal?.createdAt
            let accumulated = summaries.values
                .filter { summary in
                    guard summary.periodType == .month else { return false }
                    guard let goalStart else { return true }
                    let parts = summary.key.split(separator: "-").compactMap { Int($0) }
                    guard parts.count == 2,
                          let monthDate = calendar.date(from: DateComponents(year: parts[0], month: parts[1])) else { return false }
                    return monthDate >= goalStart
                }
                .reduce(0) { $0 + max(0, $1.income - $1.expense) }
            let savedAmount = (activeGoal?.startingAmount ?? 0) + accumulated
            let progress = activeGoal.map { AchievementEngine.goalProgress(goal: $0, savedAmount: savedAmount) }
            let weekly = AchievementEngine.weeklySummary(summaries: summaries, monthlyBudget: monthlyBudget, now: now, calendar: calendar)
            let hasCurrentMonth = summaries[AchievementEngine.monthKey(for: now, calendar: calendar)]?.recordCount ?? 0 > 0
            let next = AchievementSnapshot(
                goals: goals,
                budget: existing?.budget ?? BudgetSetting(),
                periodSummaries: summaries,
                weekStreak: streak,
                badgeStates: audit.states,
                badgeEvents: (existing?.badgeEvents ?? []) + audit.events,
                health: health,
                hasCurrentMonthRecords: hasCurrentMonth,
                currentGoalProgress: progress,
                weeklySummary: weekly
            )
            await MainActor.run {
                guard self.activeRebuildID == requestID else { return }
                self.publish(next)
            }
        }
    }

    private func scheduleReconcile() {
        reconcile()
    }

    private func publish(_ snapshot: AchievementSnapshot) {
        self.snapshot = snapshot
        self.isReady = true
        self.hasLoadError = false
        try? persistence.save(snapshot)
        self.lastRecordIDs = Dictionary(uniqueKeysWithValues: SupabaseService.shared.allRecords.map { ($0.id, $0) })
    }

    private func emptySnapshot() -> AchievementSnapshot {
        AchievementSnapshot(
            health: HealthMetrics(score: 0, savingsRate: nil, budgetControl: nil, stability: nil, trend: nil, largeExpenseRatio: nil, dimensions: [])
        )
    }

    private static func changedPeriodKeys(old: [UUID: Record], new: [Record], calendar: Calendar) -> Set<String> {
        var newByID = Dictionary(uniqueKeysWithValues: new.map { ($0.id, $0) })
        var keys = Set<String>()
        for (id, record) in old {
            if let updated = newByID.removeValue(forKey: id) {
                guard updated != record else { continue }
                keys.insert(AchievementEngine.monthKey(for: record.date, calendar: calendar))
                keys.insert(AchievementEngine.monthKey(for: updated.date, calendar: calendar))
                keys.insert(AchievementEngine.weekKey(for: record.date, calendar: calendar))
                keys.insert(AchievementEngine.weekKey(for: updated.date, calendar: calendar))
            } else {
                keys.insert(AchievementEngine.monthKey(for: record.date, calendar: calendar))
                keys.insert(AchievementEngine.weekKey(for: record.date, calendar: calendar))
            }
        }
        for record in newByID.values {
            keys.insert(AchievementEngine.monthKey(for: record.date, calendar: calendar))
            keys.insert(AchievementEngine.weekKey(for: record.date, calendar: calendar))
        }
        return keys
    }
}
```

- [ ] **Step 2: 构建验证**

Run: `xcodebuild build ...`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 提交**

```bash
git add 花计2046/Services/AchievementManager.swift
git commit -m "feat: 成就管理器"
```

---

### Task 9: AnalyticsAchievementView

**Files:**
- Create: `花计2046/Views/AnalyticsAchievementView.swift`

- [ ] **Step 1: 实现成就总览 UI**

```swift
import SwiftUI

struct AnalyticsAchievementView: View {
    @ObservedObject var manager: AchievementManager

    var body: some View {
        VStack(spacing: 12) {
            healthCard
            HStack(spacing: 12) {
                goalCard
                streakCard
            }
            badgeDrawer
            weeklySummaryCard
            rulesCard
        }
        .frame(maxWidth: .infinity)
    }

    private var healthCard: some View {
        let snapshot = manager.snapshot
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("财务健康分").font(.appTitle).foregroundColor(AppTheme.textPrimary)
                Spacer()
                if let score = snapshot?.health.score {
                    Text("\(score)").font(.system(size: 34, weight: .semibold)).foregroundColor(AppTheme.brandStart)
                }
            }
            if let dimensions = snapshot?.health.dimensions {
                ForEach(dimensions) { dimension in
                    HStack(spacing: 8) {
                        Text(dimension.name).font(.appSmall).foregroundColor(AppTheme.textSecondary).frame(width: 72, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(AppTheme.border)
                                RoundedRectangle(cornerRadius: 3).fill(AppTheme.brandGradient).frame(width: geo.size.width * CGFloat(dimension.score) / 20)
                            }
                        }
                        .frame(height: 6)
                        Text("\(dimension.score)").font(.appSmall).foregroundColor(AppTheme.textPrimary).frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("冲刺目标").font(.appSmall).foregroundColor(AppTheme.textSecondary)
            if let progress = manager.snapshot?.currentGoalProgress {
                Text(progress.goal.name).font(.appTitle).foregroundColor(AppTheme.textPrimary).lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(AppTheme.border)
                        RoundedRectangle(cornerRadius: 4).fill(Color.green).frame(width: geo.size.width * min(1, progress.percent / 100))
                    }
                }
                .frame(height: 8)
                Text(String(format: "%.0f%% 已存 ¥%.0f", progress.percent, progress.savedAmount))
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("设第一个目标").font(.appBody).foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .cardStyle()
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("连续达标").font(.appSmall).foregroundColor(AppTheme.textSecondary)
            Text("\(manager.snapshot?.weekStreak ?? 0) 周").font(.system(size: 28, weight: .semibold)).foregroundColor(AppTheme.brandStart)
            Text("每周支出在预算内").font(.appTiny).foregroundColor(AppTheme.textTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .cardStyle()
    }

    private var badgeDrawer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("徽章").font(.appTitle).foregroundColor(AppTheme.textPrimary)
            if let states = manager.snapshot?.badgeStates {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 10) {
                    ForEach(states) { state in
                        Badge24View(badgeType: state.badgeType, isHeld: state.isHeld, latestAwardedAt: state.latestAwardedAt)
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var weeklySummaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("本周小结").font(.appTitle).foregroundColor(AppTheme.textPrimary)
            if let weekly = manager.snapshot?.weeklySummary {
                Text("预算 ¥\(String(format: "%.0f", weekly.budget)) · 支出 ¥\(String(format: "%.0f", weekly.expense))")
                    .font(.appBody).foregroundColor(AppTheme.textPrimary)
                Text(weekly.isOnTrack ? "本周预算内，继续保持" : "已超出周预算，注意控制")
                    .font(.appSmall)
                    .foregroundColor(weekly.isOnTrack ? .green : AppTheme.brandStart)
                Text("还有 \(weekly.daysLeft) 天结算").font(.appTiny).foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("评分规则").font(.appTitle).foregroundColor(AppTheme.textPrimary)
            Text("健康分五维各 20 分：储蓄率、预算控制、支出稳定性、结余趋势、大额支出占比。")
                .font(.appSmall).foregroundColor(AppTheme.textSecondary)
            Text("日健康：支出不超今日预算且当天有结余。周达标：周支出不超周预算。")
                .font(.appSmall).foregroundColor(AppTheme.textSecondary)
            Text("徽章：连续 1/4/8/12/26/52 周；月度达标 3/6/12/24 个月得铁/铜/银/金。")
                .font(.appSmall).foregroundColor(AppTheme.textSecondary)
            Text("徽章实时审核，数据变更后自动颁发或撤销。")
                .font(.appSmall).foregroundColor(AppTheme.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct Badge24View: View {
    let badgeType: BadgeType
    let isHeld: Bool
    let latestAwardedAt: Date?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                starShape.fill(color(for: .outer))
                starShape.fill(color(for: .middle)).scaleEffect(0.78)
                starShape.fill(color(for: .inner)).scaleEffect(0.64)
                trophyIcon
            }
            .frame(width: 58, height: 58)
            .opacity(isHeld ? 1 : 0.35)

            Text(badgeType.shortName).font(.system(size: 11, weight: .medium)).foregroundColor(AppTheme.textPrimary)
            if let date = latestAwardedAt, isHeld {
                Text(date, format: .dateTime.month().day()).font(.system(size: 9)).foregroundColor(AppTheme.textTertiary)
            } else if !isHeld {
                Text("未持有").font(.system(size: 9)).foregroundColor(AppTheme.textTertiary)
            }
        }
    }

    private enum Layer { case outer, middle, inner }

    private func color(for layer: Layer) -> Color {
        let colors: [Color]
        switch badgeType {
        case .week1, .week4, .week8, .week12, .week26, .week52:
            colors = [Color(hex: "#A855F7"), Color(hex: "#E9D5FF"), Color(hex: "#7E22CE")]
        case .monthIron:
            colors = [Color(hex: "#6B7280"), Color(hex: "#D1D5DB"), Color(hex: "#374151")]
        case .monthCopper:
            colors = [Color(hex: "#D97706"), Color(hex: "#FDE68A"), Color(hex: "#92400E")]
        case .monthSilver:
            colors = [Color(hex: "#9CA3AF"), Color(hex: "#F3F4F6"), Color(hex: "#4B5563")]
        case .monthGold:
            colors = [Color(hex: "#EAB308"), Color(hex: "#FEF9C3"), Color(hex: "#854D0E")]
        }
        switch layer {
        case .outer: return colors[0]
        case .middle: return colors[1]
        case .inner: return colors[2]
        }
    }

    private var starShape: some Shape {
        PolygonStar(points: 24, outerRadius: 50, innerRadius: 45)
    }

    @ViewBuilder private var trophyIcon: some View {
        Image(systemName: trophyName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)
    }

    private var trophyName: String {
        switch badgeType {
        case .week1, .monthIron: return "trophy"
        case .week4, .monthCopper: return "trophy.fill"
        case .week8, .monthSilver: return "medal.fill"
        case .week12: return "star.circle.fill"
        case .week26: return "crown.fill"
        case .week52, .monthGold: return "crown"
        }
    }
}

struct PolygonStar: Shape {
    let points: Int
    let outerRadius: Double
    let innerRadius: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let count = points * 2
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) * .pi * 2 / Double(count) - .pi / 2
            let radius = index % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + CGFloat(radius) * CGFloat(cos(angle)) * rect.width / 100
            let y = center.y + CGFloat(radius) * CGFloat(sin(angle)) * rect.height / 100
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }
}

extension BadgeType {
    var shortName: String {
        switch self {
        case .week1: return "起步"
        case .week4: return "坚持"
        case .week8: return "习惯"
        case .week12: return "季度"
        case .week26: return "半年"
        case .week52: return "年度"
        case .monthIron: return "铁"
        case .monthCopper: return "铜"
        case .monthSilver: return "银"
        case .monthGold: return "金"
        }
    }
}
```

注意：`PolygonStar` 中 `outerRadius`/`innerRadius` 是逻辑坐标，`scaleEffect` 后需要配合 shape 自适应；该实现以 100 为基准缩放，可作为第一版并视觉调整。

- [ ] **Step 2: 构建验证**

Run: `xcodebuild build ...`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 提交**

```bash
git add 花计2046/Views/AnalyticsAchievementView.swift
git commit -m "feat: 成就总览 UI"
```

---

### Task 10: GoalManagementSheet

**Files:**
- Create: `花计2046/Views/GoalManagementSheet.swift`

- [ ] **Step 1: 实现目标管理 Sheet**

```swift
import SwiftUI

struct GoalManagementSheet: View {
    @ObservedObject var manager: AchievementManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var target = ""
    @State private var starting = ""
    @State private var deadline = Date().addingTimeInterval(60 * 60 * 24 * 365)

    var body: some View {
        NavigationStack {
            Form {
                Section("当前目标") {
                    ForEach(manager.snapshot?.goals ?? []) { goal in
                        HStack {
                            Image(systemName: goal.isActive ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(goal.isActive ? AppTheme.brandStart : AppTheme.textTertiary)
                            VStack(alignment: .leading) {
                                Text(goal.name).font(.appBody).foregroundColor(AppTheme.textPrimary)
                                Text(String(format: "¥%.0f / ¥%.0f", goal.startingAmount, goal.targetAmount))
                                    .font(.appTiny).foregroundColor(AppTheme.textSecondary)
                            }
                            Spacer()
                            Button("冲刺") { manager.setActiveGoal(id: goal.id) }
                                .font(.appSmall)
                                .disabled(goal.isActive)
                            Button(role: .destructive) { manager.deleteGoal(id: goal.id) } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
                Section("新增目标") {
                    TextField("名称", text: $name)
                    TextField("目标金额", text: $target).keyboardType(.decimalPad)
                    TextField("已有积蓄", text: $starting).keyboardType(.decimalPad)
                    DatePicker("截止日期", selection: $deadline, displayedComponents: .date)
                    Button("添加") {
                        let targetValue = Double(target) ?? 0
                        guard !name.isEmpty, targetValue > 0 else { return }
                        manager.addGoal(name: name, targetAmount: targetValue, startingAmount: Double(starting) ?? 0, deadline: deadline)
                        name = ""; target = ""; starting = ""
                    }
                }
                Section("月度预算") {
                    TextField("预算金额（留空自动参考近 90 天均值）", value: Binding(
                        get: { manager.snapshot?.budget.monthlyBudget ?? 0 },
                        set: { manager.setMonthlyBudget($0 > 0 ? $0 : nil) }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("财务目标")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 2: 构建验证**

Run: `xcodebuild build ...`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 提交**

```bash
git add 花计2046/Views/GoalManagementSheet.swift
git commit -m "feat: 目标管理 Sheet"
```

---

### Task 11: AnalyticsView 集成

**Files:**
- Modify: `花计2046/Views/AnalyticsView.swift`

- [ ] **Step 1: 在分析页顶部接入成就区块**

在 `AnalyticsView` 的 ScrollView 内、`sectionHeader("收支综合", ...)` 之前插入：

```swift
AnalyticsAchievementView(manager: AchievementManager.shared)
```

并在分析页搜索面板区域（`searchPanel` 附近）增加「管理目标」入口，按钮打开：

```swift
.sheet(isPresented: $showGoalManagement) {
    GoalManagementSheet(manager: AchievementManager.shared)
}
```

同时在 `AnalyticsView` 增加 `@State private var showGoalManagement = false`。

- [ ] **Step 2: 构建验证**

Run: `xcodebuild build ...`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 提交**

```bash
git add 花计2046/Views/AnalyticsView.swift
git commit -m "feat: 分析页接入成就总览"
```

---

### Task 12: 全量验证

**Files:** 无

- [ ] **Step 1: 全量测试**

Run: `xcodebuild test -project 花计2046.xcodeproj -scheme 花计2046 -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath Build -clonedSourcePackagesDirPath 花计2046.xcodeproj/project.xcworkspace/xcshareddata/swiftpm -only-testing:花计2046Tests`
Expected: `TEST SUCCEEDED`

- [ ] **Step 2: 最终提交**

```bash
git add -A
git commit -m "feat: 完成成就系统"
```

---

## Self-Review

覆盖检查：
- 数据模型与持久化：Task 2、Task 7。
- 周期汇总、预算、健康分：Task 3、Task 4。
- 日/周/月达标与 streak：Task 3、Task 5。
- 徽章实时审核与补发：Task 6。
- 目标与冲刺：Task 2、Task 8、Task 10。
- 数据完整性门控与错误处理：Task 1、Task 8。
- UI 与规则说明卡：Task 9、Task 11。

已知后续可调项（不在本计划阻塞范围）：目标预计完成时间暂返回 nil，可在 UI 后续接入近 90 天平均结余；`PolygonStar` 视觉参数在 Task 9 构建后按截图微调。
