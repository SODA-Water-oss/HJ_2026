import SwiftUI

struct AnalyticsAchievementView: View {
    @ObservedObject var manager: AchievementManager

    @State private var showRules = false

    var body: some View {
        VStack(spacing: 12) {
            healthCard
            HStack(spacing: 12) {
                goalCard
                streakCard
            }
            badgeDrawer
            weeklySummaryCard
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showRules) {
            RulesSheetView()
        }
    }

    private var healthCard: some View {
        let snapshot = manager.snapshot
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("财务健康分").font(.appTitle).foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button(action: { showRules = true }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.textTertiary)
                }
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
            HStack {
                Text("徽章").font(.appTitle).foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button(action: { showRules = true }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
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

}

/// 评分规则弹窗（问题解答模式）
struct RulesSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ruleBlock(title: "财务健康分怎么算？", content: "健康分由五个维度组成，每个维度 20 分：\n• 储蓄率\n• 预算控制\n• 支出稳定性\n• 结余趋势\n• 大额支出占比")
                    ruleBlock(title: "日健康 / 周达标怎么判断？", content: "• 日健康：当日支出不超过今日预算，且当天有结余\n• 周达标：本周支出不超过周预算")
                    ruleBlock(title: "徽章怎么获得？", content: "• 连续达标：连续 1 / 4 / 8 / 12 / 26 / 52 周\n• 月度等级：月度达标 3 / 6 / 12 / 24 个月，分别获得铁 / 铜 / 银 / 金徽章")
                    ruleBlock(title: "徽章会变化吗？", content: "徽章实时审核，数据变更后会自动颁发或撤销。")
                }
                .padding(20)
            }
            .navigationTitle("评分规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func ruleBlock(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
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

    private enum Layer {
        case outer
        case middle
        case inner
    }

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
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
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
