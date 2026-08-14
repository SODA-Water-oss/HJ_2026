import Foundation

enum AchievementEngine {
    static func weekKey(for date: Date, calendar: Calendar = .current) -> String {
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        weekCalendar.minimumDaysInFirstWeek = 4
        let weekOfYear = weekCalendar.component(.weekOfYear, from: date)
        let year = weekCalendar.component(.yearForWeekOfYear, from: date)
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
        if let current, monthly > 0 {
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

    static func weeklySummary(
        summaries: [String: PeriodSummary],
        monthlyBudget: Double,
        now: Date,
        calendar: Calendar = .current
    ) -> WeeklySummary {
        let key = weekKey(for: now, calendar: calendar)
        let budget = weeklyBudget(monthly: monthlyBudget)
        let expense = summaries[key]?.expense ?? 0
        let weekday = calendar.component(.weekday, from: now)
        let daysLeft = (8 - weekday) % 7
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

    static func qualifyingMonthCount(summaries: [String: PeriodSummary], monthlyBudget: Double, calendar: Calendar = .current) -> Int {
        summaries.values
            .filter { $0.periodType == .month && $0.recordCount > 0 && $0.expense <= monthlyBudget }
            .count
    }

    static func derivedBadgeStates(qualifyingMonthCount: Int) -> [BadgeState] {
        let monthThresholds: [(BadgeType, Int)] = [
            (.monthIron, 3), (.monthCopper, 6), (.monthSilver, 12), (.monthGold, 24)
        ]
        return monthThresholds.map { BadgeState(badgeType: $0.0, isHeld: qualifyingMonthCount >= $0.1, latestAwardedAt: nil, latestRevokedAt: nil) }
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
