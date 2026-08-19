import SwiftUI

struct AASplitView: View {
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    @State private var totalText = ""
    @State private var memberCount = 2
    @State private var splitMode = "平均分摊"
    @State private var memberNames: [String] = ["成员1", "成员2"]
    @State private var customAmounts: [Double] = [0, 0]
    @State private var paidAmounts: [Double] = [0, 0]

    private let splitModes = ["平均分摊", "自定义金额"]

    private var totalAmount: Double {
        Double(totalText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var customTotal: Double {
        customAmounts.reduce(0, +)
    }

    private var shares: [Double] {
        if splitMode == "平均分摊" {
            guard memberCount > 0 else { return [] }
            let share = totalAmount / Double(memberCount)
            return Array(repeating: share, count: memberCount)
        }
        return customAmounts
    }

    private var customDifference: Double {
        totalAmount - customTotal
    }

    private var isCustomBalanced: Bool {
        splitMode == "平均分摊" || abs(customDifference) < 0.01
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 4)

                    inputCard
                    if splitMode == "自定义金额" {
                        customAmountCard
                    }
                    paidCard
                    resultCard
                }
                .padding(.bottom, 24)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("AA分账")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("账单信息")
                .font(.appBodyMedium)
                .foregroundColor(AppTheme.textPrimary)

            HStack {
                Text("总金额")
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                TextField("0.00", text: $totalText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150)
                Text(currencySymbol)
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.background)
            .cornerRadius(10)

            HStack {
                Text("人数")
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Stepper(value: $memberCount, in: 1...20) {
                    Text("\(memberCount) 人")
                        .font(.appBodyMedium)
                        .foregroundColor(AppTheme.textPrimary)
                }
                .onChange(of: memberCount) { _, newValue in
                    syncMemberCount(newValue)
                }
            }

            Picker("分摊方式", selection: $splitMode) {
                ForEach(splitModes, id: \.self) { mode in
                    Text(mode).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private var customAmountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("自定义金额")
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("合计 \(currencySymbol)\(String(format: "%.2f", customTotal))")
                    .font(.appSmall)
                    .foregroundColor(isCustomBalanced ? Color.green : Color(hex: "#EF4444"))
            }

            ForEach(memberNames.indices, id: \.self) { index in
                HStack(spacing: 10) {
                    Text(memberNames[index])
                        .font(.appBody)
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 72, alignment: .leading)
                    TextField("金额", value: Binding(
                        get: { index < customAmounts.count ? customAmounts[index] : 0 },
                        set: { if index < customAmounts.count { customAmounts[index] = max(0, $0) } }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .font(.appBody)
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.background)
                    .cornerRadius(8)
                }
            }

            if !isCustomBalanced {
                Text(customDifference > 0
                     ? "还差 \(currencySymbol)\(String(format: "%.2f", customDifference))，请补充分摊金额"
                     : "多出 \(currencySymbol)\(String(format: "%.2f", abs(customDifference)))，请减少分摊金额")
                    .font(.appSmall)
                    .foregroundColor(Color(hex: "#EF4444"))
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private var paidCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("每人已付")
                .font(.appBodyMedium)
                .foregroundColor(AppTheme.textPrimary)

            ForEach(memberNames.indices, id: \.self) { index in
                HStack(spacing: 10) {
                    TextField("姓名", text: Binding(
                        get: { index < memberNames.count ? memberNames[index] : "成员\(index + 1)" },
                        set: { if index < memberNames.count { memberNames[index] = $0 } }
                    ))
                    .font(.appBody)
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 80, alignment: .leading)

                    Text("已付")
                        .font(.appSmall)
                        .foregroundColor(AppTheme.textSecondary)
                    TextField("金额", value: Binding(
                        get: { index < paidAmounts.count ? paidAmounts[index] : 0 },
                        set: { if index < paidAmounts.count { paidAmounts[index] = max(0, $0) } }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .font(.appBody)
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.background)
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("分账结果")
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if totalAmount > 0 {
                    Text("\(currencySymbol)\(String(format: "%.2f", totalAmount))")
                        .font(.appBodyMedium)
                        .foregroundColor(AppTheme.brandStart)
                }
            }

            if totalAmount <= 0 {
                Text("请输入总金额后查看分账结果")
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else if splitMode == "自定义金额" && !isCustomBalanced {
                Text("自定义金额合计与总金额不一致，请先调整")
                    .font(.appSmall)
                    .foregroundColor(Color(hex: "#EF4444"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(memberNames.indices, id: \.self) { index in
                    let share = shares[safe: index] ?? 0
                    let paid = paidAmounts[safe: index] ?? 0
                    let net = share - paid
                    HStack(spacing: 8) {
                        Text(memberNames[safe: index] ?? "成员\(index + 1)")
                            .font(.appBodyMedium)
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("应付 \(currencySymbol)\(String(format: "%.2f", share))")
                            .font(.appSmall)
                            .foregroundColor(AppTheme.textSecondary)

                        Text(net >= 0
                             ? "还应付 \(currencySymbol)\(String(format: "%.2f", net))"
                             : "应收回 \(currencySymbol)\(String(format: "%.2f", abs(net)))")
                            .font(.appSmall)
                            .foregroundColor(net >= 0 ? AppTheme.brandStart : Color.green)
                            .frame(maxWidth: 130, alignment: .trailing)
                    }
                    .padding(12)
                    .background(AppTheme.background)
                    .cornerRadius(10)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private func syncMemberCount(_ count: Int) {
        while memberNames.count < count {
            memberNames.append("成员\(memberNames.count + 1)")
            customAmounts.append(0)
            paidAmounts.append(0)
        }
        if memberNames.count > count {
            memberNames = Array(memberNames.prefix(count))
            customAmounts = Array(customAmounts.prefix(count))
            paidAmounts = Array(paidAmounts.prefix(count))
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
