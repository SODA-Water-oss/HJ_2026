import Foundation
import Testing
@testable import 花计2046

struct AchievementPersistenceTests {
    @Test func roundTripKeepsState() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = AchievementPersistence(fileURL: url)
        let snapshot = AchievementSnapshot(
            goals: [FinancialGoal(name: "旅行", targetAmount: 10000, createdAt: Date(timeIntervalSince1970: 1_700_000_000))],
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
