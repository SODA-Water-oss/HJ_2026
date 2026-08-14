import SwiftUI

struct ExchangeRateCalculatorView: View {
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    
    @State private var amount: String = ""
    @State private var fromCurrency: CurrencyInfo = .cny
    @State private var toCurrency: CurrencyInfo = .usd
    @State private var isUpdating = false
    @State private var liveRates: [String: Double] = [:]
    @State private var lastUpdated: Date?
    @State private var rateError: String?
    
    struct CurrencyInfo: Identifiable, Equatable {
        let id: String
        let name: String
        let symbol: String
        var rateToCNY: Double
        
        static let cny = CurrencyInfo(id: "CNY", name: "人民币", symbol: "¥", rateToCNY: 1.0)
        static let usd = CurrencyInfo(id: "USD", name: "美元", symbol: "$", rateToCNY: 1.0)
        static let eur = CurrencyInfo(id: "EUR", name: "欧元", symbol: "€", rateToCNY: 1.0)
        static let gbp = CurrencyInfo(id: "GBP", name: "英镑", symbol: "£", rateToCNY: 1.0)
        static let jpy = CurrencyInfo(id: "JPY", name: "日元", symbol: "¥", rateToCNY: 1.0)
        static let krw = CurrencyInfo(id: "KRW", name: "韩元", symbol: "₩", rateToCNY: 1.0)
        static let hkd = CurrencyInfo(id: "HKD", name: "港币", symbol: "HK$", rateToCNY: 1.0)
        static let twd = CurrencyInfo(id: "TWD", name: "台币", symbol: "NT$", rateToCNY: 1.0)
        static let thb = CurrencyInfo(id: "THB", name: "泰铢", symbol: "฿", rateToCNY: 1.0)
        static let sgd = CurrencyInfo(id: "SGD", name: "新加坡元", symbol: "S$", rateToCNY: 1.0)
        
        static let all: [CurrencyInfo] = [.cny, .usd, .eur, .gbp, .jpy, .krw, .hkd, .twd, .thb, .sgd]
    }
    
    private var amountValue: Double { Double(amount) ?? 0 }
    
    private var resultValue: Double {
        guard amountValue > 0 else { return 0 }
        let fromRate = liveRates[fromCurrency.id] ?? fromCurrency.rateToCNY
        let toRate = liveRates[toCurrency.id] ?? toCurrency.rateToCNY
        guard toRate > 0 else { return 0 }
        let baseInCNY = amountValue * fromRate
        return baseInCNY / toRate
    }
    
    private var rateDescription: String {
        if isUpdating { return "正在获取最新汇率…" }
        guard !liveRates.isEmpty else { return "--" }
        let fromRate = liveRates[fromCurrency.id] ?? fromCurrency.rateToCNY
        let toRate = liveRates[toCurrency.id] ?? toCurrency.rateToCNY
        guard toRate > 0 else { return "--" }
        let rate = fromRate / toRate
        return "1 \(fromCurrency.id) = " + String(format: "%.4f", rate) + " \(toCurrency.id)"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Color.clear.frame(height: 4)
                
                // Input Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("货币兑换")
                        .font(.appTitle)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    // From currency
                    VStack(alignment: .leading, spacing: 6) {
                        Text("从").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                        currencyPicker(selection: $fromCurrency, exclude: toCurrency)
                    }
                    
                    // Amount
                    VStack(alignment: .leading, spacing: 6) {
                        Text("金额").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                        HStack(spacing: 8) {
                            TextField("输入金额", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                                .onChange(of: amount) { newVal in
                                    let filtered = newVal.filter { $0.isNumber || $0 == "." }
                                    let parts = filtered.split(separator: ".", maxSplits: 1)
                                    if filtered.filter({ $0 == "." }).count > 1 {
                                        amount = String(parts[0]) + "." + String(parts[safe: 1]?.prefix(2) ?? "")
                                    } else if filtered.contains(".") {
                                        amount = String(parts[0]) + "." + String(parts[safe: 1]?.prefix(2) ?? "")
                                    } else {
                                        amount = filtered
                                    }
                                }
                            Text(fromCurrency.symbol)
                                .font(.appBodyMedium)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    

                    // To currency
                    VStack(alignment: .leading, spacing: 6) {
                        Text("到").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                        currencyPicker(selection: $toCurrency, exclude: fromCurrency)
                    }
                }
                .whiteCardContainer()
                
                // Result Card
                if amountValue > 0 {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("换算结果")
                                .font(.appTitle)
                                .foregroundColor(AppTheme.textPrimary)
                            if !liveRates.isEmpty {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }
                        
                        HStack(alignment: .firstTextBaseline) {
                            Text(String(format: "%.2f", amountValue))
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.textSecondary)
                            Text(fromCurrency.symbol)
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                        }
                        
                        AppDivider()
                        
                        if isUpdating {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(AppTheme.brandStart)
                                Text("汇率更新中，请稍候…")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        } else if liveRates.isEmpty {
                            Text("尚未获取最新汇率，请先点击「刷新汇率」再换算")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.textTertiary)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        } else {
                            HStack(alignment: .firstTextBaseline) {
                                Text(String(format: "%.2f", resultValue))
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(AppTheme.brandStart)
                                Text(toCurrency.symbol)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(AppTheme.brandStart)
                                Spacer()
                            }
                        }
                        
                        AppDivider()
                        
                        HStack(spacing: 6) {
                            Text(rateDescription)
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.textSecondary)
                            Button(action: swapCurrencies) {
                                Image(systemName: "arrow.left.arrow.right.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppTheme.brandGradient)
                            }
                        }
                        if let updated = lastUpdated {
                            Text("更新于 " + timeFormatted(updated))
                                .font(.appSmall)
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        if let err = rateError {
                            Text(err)
                                .font(.appSmall)
                                .foregroundColor(Color(hex: "#DC2626"))
                        }
                        
                        Button(action: { Task { await fetchRates() } }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14))
                                Text("刷新汇率")
                                    .font(.appBodyMedium)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        .disabled(isUpdating)
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
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.brandStart)
                    Text("汇率换算")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if isUpdating {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
    }
    
    private func currencyPicker(selection: Binding<CurrencyInfo>, exclude: CurrencyInfo) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CurrencyInfo.all.filter { $0.id != exclude.id }) { currency in
                    currencyButton(currency: currency, isSelected: selection.wrappedValue == currency, action: { selection.wrappedValue = currency })
                }
            }
        }
    }
    
    private func currencyButton(currency: CurrencyInfo, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(currency.id)
                    .font(.system(size: 13, weight: .semibold))
                Text(currency.name + " " + currency.symbol)
                    .font(.system(size: 10))
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(AppTheme.brandGradient))
            .frame(minWidth: 56)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Group { if isSelected { AppTheme.brandGradient } else { AppTheme.background } })
            .cornerRadius(8)
        }
    }
    
    private func swapCurrencies() {
        let temp = fromCurrency
        fromCurrency = toCurrency
        toCurrency = temp
    }
    
    private func fetchRates() async {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/CNY") else { return }
        isUpdating = true
        rateError = nil
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rates = json["rates"] as? [String: Double] {
                var merged = liveRates
                for (code, rate) in rates {
                    merged[code] = rate
                }
                merged["CNY"] = 1.0
                liveRates = merged
                lastUpdated = Date()
                
                // Update CurrencyInfo static rates for display
                var all = CurrencyInfo.all
                for i in all.indices {
                    if let rate = liveRates[all[i].id] {
                        all[i].rateToCNY = rate
                    }
                }
            }
        } catch {
            rateError = liveRates.isEmpty ? "获取汇率失败，请检查网络后重试" : "获取汇率失败，使用上次缓存"
        }
        isUpdating = false
    }
    
    private func timeFormatted(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: d)
    }
}
