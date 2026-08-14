import SwiftUI

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}


struct InterestCalculatorView: View {
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    @Environment(\.dismiss) var dismiss
    
    @State private var principal: String = ""
    @State private var annualRate: String = ""
    @State private var years: Int = 1
    @State private var months: Int = 0
    @State private var calcType: InterestType = .simple
    @State private var compoundFreq: CompoundFrequency = .monthly
    
    enum InterestType: String, CaseIterable {
        case simple = "简单利息"
        case compound = "复利"
    }
    
    enum CompoundFrequency: String, CaseIterable {
        case annually = "每年"
        case semiannually = "每半年"
        case quarterly = "每季度"
        case monthly = "每月"
        
        var timesPerYear: Int {
            switch self {
            case .annually: return 1
            case .semiannually: return 2
            case .quarterly: return 4
            case .monthly: return 12
            }
        }
    }
    
    private var principalValue: Double { Double(principal) ?? 0 }
    private var rateValue: Double { (Double(annualRate) ?? 0) / 100.0 }
    private var totalMonths: Int { years * 12 + months }
    private var termYears: Double { Double(totalMonths) / 12.0 }
    
    private var interestResult: Double {
        guard principalValue > 0, rateValue > 0, totalMonths > 0 else { return 0 }
        let p = principalValue
        let r = rateValue
        let t = termYears
        
        if calcType == .simple {
            return p * r * t
        } else {
            let n = compoundFreq.timesPerYear
            return p * pow(1 + r / Double(n), Double(n) * t) - p
        }
    }
    
    private var totalResult: Double { principalValue + interestResult }
    
    private var effectiveAnnualRate: Double {
        guard calcType == .compound, rateValue > 0 else { return rateValue * 100 }
        let n = compoundFreq.timesPerYear
        return (pow(1 + rateValue / Double(n), Double(n)) - 1) * 100
    }
    
    @ViewBuilder
    private var interestTypeToggle: some View {
        HStack(spacing: 0) {
            ForEach(InterestType.allCases, id: \.self) { type in
                Button(action: { calcType = type }) {
                    Text(type.rawValue)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(calcType == type ? AnyShapeStyle(Color.white) : AnyShapeStyle(AppTheme.brandGradient))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Group { if calcType == type { AppTheme.brandGradient } else { AppTheme.background } })
                        .cornerRadius(7)
                }
            }
        }
        .background(AppTheme.background)
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var compoundFreqToggle: some View {
        HStack(spacing: 0) {
            ForEach(CompoundFrequency.allCases, id: \.self) { freq in
                Button(action: { compoundFreq = freq }) {
                    Text(freq.rawValue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(compoundFreq == freq ? AnyShapeStyle(Color.white) : AnyShapeStyle(AppTheme.brandGradient))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Group { if compoundFreq == freq { AppTheme.brandGradient } else { AppTheme.background } })
                        .cornerRadius(7)
                }
            }
        }
        .background(AppTheme.background)
        .cornerRadius(8)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Color.clear.frame(height: 4)
                
                // Input Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("输入参数")
                        .font(.appTitle)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    // Principal
                    VStack(alignment: .leading, spacing: 6) {
                        Text("本金").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                        HStack(spacing: 8) {
                            TextField("输入本金金额", text: $principal)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                                .onChange(of: principal) { newVal in
                                    let filtered = newVal.filter { $0.isNumber || $0 == "." }
                                    let parts = filtered.split(separator: ".", maxSplits: 1)
                                    if filtered.filter({ $0 == "." }).count > 1 {
                                        principal = String(parts[0]) + "." + String(parts[safe: 1]?.prefix(2) ?? "")
                                    } else if filtered.contains(".") {
                                        principal = String(parts[0]) + "." + String(parts[safe: 1]?.prefix(2) ?? "")
                                    } else {
                                        principal = filtered
                                    }
                                }
                            Text(currencySymbol)
                                .font(.appBodyMedium)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    
                    // Annual Rate
                    VStack(alignment: .leading, spacing: 6) {
                        Text("年利率（%）").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                        HStack(spacing: 8) {
                            TextField("输入年利率", text: $annualRate)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                                .onChange(of: annualRate) { newVal in
                                    let filtered = newVal.filter { $0.isNumber || $0 == "." }
                                    let parts = filtered.split(separator: ".", maxSplits: 1)
                                    if filtered.filter({ $0 == "." }).count > 1 {
                                        annualRate = String(parts[0]) + "." + String(parts[safe: 1]?.prefix(2) ?? "")
                                    } else if filtered.contains(".") {
                                        annualRate = String(parts[0]) + "." + String(parts[safe: 1]?.prefix(2) ?? "")
                                    } else {
                                        annualRate = filtered
                                    }
                                }
                            Text("%")
                                .font(.appBodyMedium)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    
                    // Term
                    VStack(alignment: .leading, spacing: 6) {
                        Text("期限").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                        HStack(spacing: 12) {
                            Picker("年", selection: $years) {
                                ForEach(0...50, id: \.self) { y in
                                    Text("\(y)年").tag(y)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.brandStart)
                            
                            Picker("月", selection: $months) {
                                ForEach(0...11, id: \.self) { m in
                                    Text("\(m)个月").tag(m)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.brandStart)
                        }
                    }
                    
                    // Type toggle
                    VStack(alignment: .leading, spacing: 6) {
                        Text("计息方式").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                        interestTypeToggle
                    }
                    
                    // Compound frequency (only for compound)
                    if calcType == .compound {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("复利频率").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            compoundFreqToggle
                        }
                    }
                }
                .whiteCardContainer()
                
                // Result Card
                if principalValue > 0, rateValue > 0, totalMonths > 0 {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("计算结果")
                            .font(.appTitle)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        resultRow(label: "利息总额", value: interestResult, currency: currencySymbol, highlight: true)
                        AppDivider()
                        resultRow(label: "本息合计", value: totalResult, currency: currencySymbol, highlight: false)
                        
                        if calcType == .compound {
                            AppDivider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("有效年化收益率")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textSecondary)
                                Text(String(format: "%.2f%%", effectiveAnnualRate))
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(AppTheme.brandStart)
                            }
                        }
                    }
                    .whiteCardContainer()
                }
                
                Spacer(minLength: 24)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.brandStart)
                    Text("利息计算器")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
    }
    
    private func resultRow(label: String, value: Double, currency: String, highlight: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 17))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(currency + String(format: "%.2f", value))
                .font(.system(size: 20, weight: highlight ? .semibold : .medium))
                .foregroundColor(highlight ? AppTheme.brandStart : AppTheme.textPrimary)
        }
    }
}
