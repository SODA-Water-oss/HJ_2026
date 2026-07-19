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

struct Record: Identifiable, Codable {
    var id: UUID
    var userId: UUID
    var type: RecordType
    var amount: Double
    var category: String
    var merchant: String
    var date: Date
    var note: String?

    var isExpense: Bool { type == .expense }
    var isIncome: Bool { type == .income }

    /// 带符号的金额（支出显示 -，收入显示 +）
    var signedAmount: Double { isIncome ? amount : -amount }

    // 所属月份标识（格式：yyyy-MM）
    var month: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df.string(from: date)
    }

    // 月份显示文字（格式：yyyy年MM月）
    var monthDisplay: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy年MM月"
        return df.string(from: date)
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
    }

    init(id: UUID = UUID(), userId: UUID, type: RecordType = .expense, amount: Double, category: String, merchant: String, date: Date = Date(), note: String? = nil) {
        self.id = id
        self.userId = userId
        self.type = type
        self.amount = amount
        self.category = category
        self.merchant = merchant
        self.date = date
        self.note = note
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
