import SwiftUI
import Charts

// MARK: - 综合统计图表数据

struct AnalyticsBarPoint: Identifiable {
    let month: String
    let type: String
    let amount: Double

    var id: String { "\(month)|\(type)" }
}

struct AnalyticsLinePoint: Identifiable {
    let month: String
    let monthDisplay: String
    let net: Double

    var id: String { month }
}

struct AnalyticsDotPoint: Identifiable {
    let day: Int
    let type: String
    let amount: Double

    var id: String { "\(day)|\(type)" }
}

struct AnalyticsCurrencyPicker: View {
    let currencies: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(currencies, id: \.self) { currency in
                Button {
                    selection = currency
                } label: {
                    Text(currency)
                        .font(.system(size: 13, weight: selection == currency ? .semibold : .regular))
                        .foregroundColor(selection == currency ? .white : AppTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selection == currency ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color.clear))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AppTheme.border.opacity(0.7))
        .cornerRadius(8)
    }
}

// MARK: - 月度收支柱状图

struct MonthlyBarChartView: View {
    let points: [AnalyticsBarPoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("月份", point.month),
                y: .value("金额", point.amount),
                width: .ratio(0.62)
            )
            .foregroundStyle(by: .value("类型", point.type))
            .position(by: .value("类型", point.type))
            .cornerRadius(4)
        }
        .chartForegroundStyleScale([
            "收入": Color.green,
            "支出": AppTheme.brandStart
        ])
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine().foregroundStyle(AppTheme.border.opacity(0.4))
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(AppTheme.border.opacity(0.4))
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 月度净收入折线图

struct MonthlyNetLineChartView: View {
    let points: [AnalyticsLinePoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("月份", point.monthDisplay),
                y: .value("净收入", point.net)
            )
            .foregroundStyle(AppTheme.brandGradient)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("月份", point.monthDisplay),
                y: .value("净收入", point.net)
            )
            .foregroundStyle(point.net >= 0 ? Color.green : AppTheme.brandStart)
            .symbolSize(32)
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine().foregroundStyle(AppTheme.border.opacity(0.4))
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(AppTheme.border.opacity(0.4))
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 当月每日收支点状图

struct DailyScatterChartView: View {
    let points: [AnalyticsDotPoint]

    var body: some View {
        Chart(points) { point in
            PointMark(
                x: .value("日", point.day),
                y: .value("金额", point.amount)
            )
            .foregroundStyle(by: .value("类型", point.type))
            .symbol(by: .value("类型", point.type))
            .symbolSize(36)
        }
        .chartForegroundStyleScale([
            "收入": Color.green,
            "支出": AppTheme.brandStart
        ])
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 8)) { _ in
                AxisGridLine().foregroundStyle(AppTheme.border.opacity(0.4))
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(AppTheme.border.opacity(0.4))
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 12个月收支双折线

struct MonthlyTrendPoint: Identifiable {
    let month: String
    let monthDisplay: String
    let income: Double
    let expense: Double

    var id: String { month }
}

struct MonthlyDualLineChartView: View {
    let points: [MonthlyTrendPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("月份", point.monthDisplay),
                y: .value("收入", point.income)
            )
            .foregroundStyle(.green)
            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("月份", point.monthDisplay),
                y: .value("收入", point.income)
            )
            .foregroundStyle(.green)
            .symbolSize(28)

            LineMark(
                x: .value("月份", point.monthDisplay),
                y: .value("支出", point.expense)
            )
            .foregroundStyle(AppTheme.brandStart)
            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("月份", point.monthDisplay),
                y: .value("支出", point.expense)
            )
            .foregroundStyle(AppTheme.brandStart)
            .symbolSize(28)
        }
        .chartForegroundStyleScale([
            "收入": Color.green,
            "支出": AppTheme.brandStart
        ])
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine().foregroundStyle(AppTheme.border.opacity(0.4))
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(AppTheme.border.opacity(0.4))
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 分析页统一模块标题（图标 + 标题 + 可选右侧操作）
/// 所有分析页模块标题统一：17 semibold 文字 + brandGradient 图标，左对齐
struct AnalyticsModuleHeader<Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(icon: String, title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
    }

    init(icon: String, title: String) where Trailing == EmptyView {
        self.icon = icon
        self.title = title
        self.trailing = { EmptyView() }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.brandGradient)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
            Spacer()
            trailing()
        }
    }
}
