import Foundation
import Testing
@testable import 花计2046

struct AchievementModelTests {
    @Test func badgeStateIDIsStable() {
        let state = BadgeState(badgeType: .monthGold, isHeld: false, latestAwardedAt: nil, latestRevokedAt: nil)
        #expect(state.id == "monthGold")
    }
}
