import SwiftUI
import Combine

// MARK: - 记录行 Frame 收集
struct RowFrameKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - 爪印加载动画
struct PawPrintLoading: View {
    @State private var wave: Int = 0
    private let pawCount = 9
    private let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    private func pawColor(at index: Int) -> Color {
        let fraction = CGFloat(index) / CGFloat(max(pawCount - 1, 1))
        let r = 0.357 + (0.659 - 0.357) * fraction
        let g = 0.431 + (0.333 - 0.431) * fraction
        let b = 0.941 + (0.969 - 0.941) * fraction
        return Color(red: Double(r), green: Double(g), blue: Double(b))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(0..<pawCount, id: \.self) { i in
                    let dist = (wave - i + pawCount * 2) % (pawCount * 2)
                    let lit = dist < pawCount
                    PawIcon(filled: lit, active: lit && dist == pawCount - 1, gradientColor: pawColor(at: i))
                }
            }
            .onReceive(timer) { _ in
                wave = (wave + 1) % (pawCount * 2)
            }
            Text("正在加载...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.brandGradient)
        }
    }
}

// MARK: - 月份汇总卡片
struct MonthSectionCard: View {
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    let group: MonthExpenseGroup
    
    private var currencyCount: Int { max(group.totalByCurrency.count, 1) }
    
    private var shortDate: String {
        let s = group.monthDisplay
        guard s.count >= 6 else { return s + "小计" }
        return String(s.suffix(6).prefix(2)) + String(s.suffix(4)) + "小计"
    }
    
    private var titleSize: CGFloat {
        [20, 26, 30, 34][min(currencyCount - 1, 3)]
    }
    private var amountSize: CGFloat {
        [17, 15, 14, 12][min(currencyCount - 1, 3)]
    }
    
    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: titleSize * 0.85 as! CGFloat))
                    .foregroundStyle(AppTheme.brandGradient)
                Text(shortDate)
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundStyle(AppTheme.brandGradient)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                ForEach(group.totalByCurrency, id: \.currency) { item in
                        let sign = item.amount >= 0 ? "+" : "-"
                        let absAmt = abs(item.amount)
                        Text("\(sign)\(item.currency)\(String(format: "%.2f", absAmt))")
                        .font(.system(size: amountSize, weight: .medium))
                        .foregroundStyle(AppTheme.brandGradient)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(AppTheme.brandStart.opacity(0.06))
        .overlay(Rectangle().fill(AppTheme.brandStart.opacity(0.3)).frame(height: 1), alignment: .bottom)
    }
}

// MARK: - 记录行视图
struct ExpenseRowView: View {
    let expense: Expense
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggle: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil
    var onLongPressStateChanged: ((Bool) -> Void)? = nil
    @State private var checkBounce: CGFloat = 1.0
    @State private var rowBounce: CGFloat = 1.0
    var categoryColor: Color { AppTheme.categoryColor(expense.category) }
    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Button(action: { onToggle?() }) {
                    ZStack {
                        Circle().stroke(isSelected ? AppTheme.brandStart : Color(hex: "#D0D0D0"), lineWidth: 2).frame(width: 22, height: 22)
                        if isSelected {
                            Circle().fill(AppTheme.brandStart).frame(width: 14, height: 14)
                                .scaleEffect(checkBounce)
                            Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            Circle().fill((expense.isExpense ? AppTheme.textSecondary : Color.green).opacity(0.15)).frame(width: 44, height: 44).overlay(Text(expense.isExpense ? "支" : "收").font(.system(size: 21, weight: .semibold)).foregroundColor(expense.isExpense ? AppTheme.textSecondary : .green))
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.merchant.count > 6 ? String(expense.merchant.prefix(6)) + "..." : expense.merchant).font(.appBodyMedium).foregroundColor(AppTheme.textPrimary).lineLimit(1)
                Text(expense.category).font(.system(size: 13)).foregroundColor(categoryColor).padding(.horizontal, 6).padding(.vertical, 2).background(categoryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                Text("\(dateRowFormatted(expense.date)) \(chineseWeekday(expense.date))").font(.appSmall).foregroundColor(AppTheme.textTertiary)
                if let note = expense.note, !note.isEmpty { Text(note).font(.appSmall).foregroundColor(AppTheme.textSecondary) }
            }
            Spacer()
            Text(expense.signedFormattedAmount).font(.appBodyMedium).foregroundColor(expense.isExpense ? AppTheme.textSecondary : .green)
            if !isSelectionMode {
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(AppTheme.textTertiary.opacity(0.5)).padding(.leading, 4)
            }
        }
        .padding(16).background(ZStack { Color.white; RecordWatermark(expense: expense) }).overlay(HStack(spacing: 0) { Rectangle().fill(expense.isExpense ? AppTheme.textSecondary : .green).frame(width: 3); Spacer(minLength: 0) }.allowsHitTesting(false)).cornerRadius(12).shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .scaleEffect(rowBounce)
        .background(GeometryReader { geo in
            Color.clear.preference(key: RowFrameKey.self, value: [expense.id: geo.frame(in: .named("expenseList"))])
        })
        .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 50, perform: { onLongPress?() }, onPressingChanged: { isPressing in
            onLongPressStateChanged?(isPressing)
        })
        .onChange(of: isSelected) { newValue in
            checkBounce = 1.4
            rowBounce = 1.03
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 12)) {
                checkBounce = 1.0
            }
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 15)) {
                rowBounce = 1.0
            }
        }
    }
}

func dateRowFormatted(_ d: Date) -> String { let df = DateFormatter(); df.dateFormat = "MM-dd"; return df.string(from: d) }

func chineseWeekday(_ d: Date) -> String {
    let df = DateFormatter(); df.locale = Locale(identifier: "zh_CN"); df.dateFormat = "EEE"
    return df.string(from: d)
}
