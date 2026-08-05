import Foundation
import Testing
@testable import 花计2046

struct AchievementModelTests {
    @Test func badgeStateIDIsStable() {
        let state = BadgeState(badgeType: .monthGold, isHeld: false, latestAwardedAt: nil, latestRevokedAt: nil)
        #expect(state.id == "monthGold")
    }
}

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
        let records = (0..<90).map { day in
            Record(userId: UUID(), type: .expense, amount: 10, category: "餐饮", merchant: "a", date: date(2026, 5, 6) + TimeInterval(day * 86_400), currency: "¥")
        }
        let budget = AchievementEngine.effectiveMonthlyBudget(
            setting: BudgetSetting(),
            records: records,
            now: date(2026, 8, 3),
            calendar: calendar
        )
        #expect(budget == 300)
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
        #expect(abs(AchievementEngine.weeklyBudget(monthly: 4330) - 1000) < 0.01)
    }
}
