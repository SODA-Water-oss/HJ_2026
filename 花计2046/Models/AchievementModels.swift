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
