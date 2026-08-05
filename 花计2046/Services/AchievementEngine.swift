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
