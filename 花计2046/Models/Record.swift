import Foundation

enum RecordType: String, Codable, CaseIterable {
    case expense = "expense"
    case income = "income"

    var displayName: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        }
    }
}

struct Record: Identifiable, Codable, Equatable {
    var id: UUID
    var userId: UUID
    var type: RecordType
    var amount: Double
    var category: String
    var merchant: String
    var date: Date
    var note: String?
    var currency: String = ""

    var isExpense: Bool { type == .expense }
    var isIncome: Bool { type == .income }

    /// 带符号的金额（支出显示 -，收入显示 +）
    /// 当前记录的货币符号
    var displayCurrency: String { currency.isEmpty ? CategoryManager.currencySymbol : currency }

    /// 带货币符号的金额显示
    var formattedAmount: String {
        String(format: displayCurrency + "%.2f", amount)
    }

    /// 带符号和货币的金额
    var signedFormattedAmount: String {
        String(format: (isIncome ? "+" : "-") + displayCurrency + "%.2f", amount)
    }

    var signedAmount: Double { isIncome ? amount : -amount }

    // 所属月份标识（格式：yyyy-MM）
    var month: String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    // 月份显示文字（格式：yyyy年MM月）
    var monthDisplay: String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d年%02d月", components.year ?? 0, components.month ?? 0)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case amount
        case category
        case merchant
        case date
        case note
        case currency
    }

    /// 自定义 decoder：type 字段可缺省，兼容旧数据
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        type = try container.decodeIfPresent(RecordType.self, forKey: .type) ?? .expense
        amount = try container.decode(Double.self, forKey: .amount)
        category = try container.decode(String.self, forKey: .category)
        merchant = try container.decode(String.self, forKey: .merchant)
        date = try container.decode(Date.self, forKey: .date)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "¥"
    }

    init(id: UUID = UUID(), userId: UUID, type: RecordType = .expense, amount: Double, category: String, merchant: String, date: Date = Date(), note: String? = nil, currency: String = "¥") {
        self.id = id
        self.userId = userId
        self.type = type
        self.amount = amount
        self.category = category
        self.merchant = merchant
        self.date = date
        self.note = note; self.currency = currency
    }
}

/// 按月份分组的记录数据
struct MonthRecordGroup: Identifiable {
    let month: String          // "2024-07"
    let monthDisplay: String   // "2024年07月"
    let records: [Record]

    var id: String { month }

    var totalAmount: Double {
        records.reduce(0) { $0 + $1.amount }
    }

    /// 净收入（收入 - 支出）
    var netAmount: Double {
        records.reduce(0) { $0 + $1.signedAmount }
    }
}

extension Record {
    func matchesSearch(
        searchText: String,
        searchNote: String,
        searchCategory: String,
        searchYear: String,
        searchMonth: String
    ) -> Bool {
        let matchMerchant = searchText.isEmpty || merchant.localizedCaseInsensitiveContains(searchText)
        let matchNote = searchNote.isEmpty || (note?.localizedCaseInsensitiveContains(searchNote) ?? false)

        let matchCategory: Bool
        if searchCategory.isEmpty {
            matchCategory = true
        } else if searchCategory == "其他支出" {
            matchCategory = category == "其他" && isExpense
        } else if searchCategory == "其他收入" {
            matchCategory = category == "其他" && isIncome
        } else {
            matchCategory = category == searchCategory
        }

        let cleanYear = searchYear.replacingOccurrences(of: "年", with: "")
        let cleanMonth = searchMonth.replacingOccurrences(of: "月", with: "")
        let recordMonth = month
        let matchYear = cleanYear.isEmpty || recordMonth.hasPrefix(cleanYear)
        let matchMonth = cleanMonth.isEmpty || recordMonth.hasSuffix(cleanMonth)

        return matchMerchant && matchNote && matchCategory && matchYear && matchMonth
    }
}
