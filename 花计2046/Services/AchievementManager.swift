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
        let goal = FinancialGoal(
            name: name,
            targetAmount: targetAmount,
            startingAmount: startingAmount,
            deadline: deadline,
            isActive: current.goals.isEmpty,
            sortOrder: current.goals.count
        )
        current.goals.append(goal)
        publish(current)
    }

    func deleteGoal(id: UUID) {
        guard var current = snapshot else { return }
        current.goals.removeAll { $0.id == id }
        if !current.goals.contains(where: { $0.isActive }), let first = current.goals.first,
           let index = current.goals.firstIndex(where: { $0.id == first.id }) {
            current.goals[index].isActive = true
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

            let budgetSetting = existing?.budget ?? BudgetSetting()
            let monthlyBudget = AchievementEngine.effectiveMonthlyBudget(setting: budgetSetting, records: records, now: now, calendar: calendar)
            let weeklyBudget = AchievementEngine.weeklyBudget(monthly: monthlyBudget)
            let health = AchievementEngine.health(summaries: summaries, budget: budgetSetting, now: now, calendar: calendar)
            let monthCount = AchievementEngine.qualifyingMonthCount(summaries: summaries, monthlyBudget: monthlyBudget, calendar: calendar)
            let derived = AchievementEngine.derivedBadgeStates(qualifyingMonthCount: monthCount)
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
                budget: budgetSetting,
                periodSummaries: summaries,
                weekStreak: 0,
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
