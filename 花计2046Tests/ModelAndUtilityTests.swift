import Foundation
import Testing
@testable import 花计2046

// MARK: - Record 模型测试

struct RecordModelTests {
    private func makeRecord(
        type: RecordType = .expense,
        amount: Double = 100,
        category: String = "餐饮",
        merchant: String = "测试",
        date: Date = Date(timeIntervalSince1970: 1_750_000_000),
        note: String? = nil,
        currency: String = "¥"
    ) -> Record {
        Record(
            id: UUID(),
            userId: UUID(),
            type: type,
            amount: amount,
            category: category,
            merchant: merchant,
            date: date,
            note: note,
            currency: currency
        )
    }

    @Test func typeFlags() {
        let expense = makeRecord(type: .expense)
        #expect(expense.isExpense == true)
        #expect(expense.isIncome == false)

        let income = makeRecord(type: .income)
        #expect(income.isIncome == true)
        #expect(income.isExpense == false)
    }

    @Test func signedAmountDirection() {
        #expect(makeRecord(type: .expense, amount: 88.5).signedAmount == -88.5)
        #expect(makeRecord(type: .income, amount: 5000).signedAmount == 5000)
    }

    @Test func formattedAmountWithCurrency() {
        #expect(makeRecord(amount: 35, currency: "¥").formattedAmount == "¥35.00")
        #expect(makeRecord(amount: 12.5, currency: "$").formattedAmount == "$12.50")
    }

    @Test func signedFormattedAmount() {
        #expect(makeRecord(type: .expense, amount: 35, currency: "¥").signedFormattedAmount == "-¥35.00")
        #expect(makeRecord(type: .income, amount: 5000, currency: "¥").signedFormattedAmount == "+¥5000.00")
    }

    @Test func displayCurrencyFallsBackToGlobal() {
        // currency 为空时回退到 CategoryManager.currencySymbol
        let record = makeRecord(currency: "")
        #expect(record.displayCurrency == CategoryManager.currencySymbol)
    }

    @Test func monthAndMonthDisplayFormatting() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15))!
        let record = makeRecord(date: date)
        #expect(record.month == "2026-08")
        #expect(record.monthDisplay == "2026年08月")
    }

    @Test func codableRoundTripKeepsFields() throws {
        let original = makeRecord(
            type: .income,
            amount: 999.99,
            category: "工资",
            merchant: "公司",
            note: "八月工资",
            currency: "¥"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Record.self, from: data)
        #expect(decoded == original)
    }

    @Test func decoderDefaultsTypeToExpense() throws {
        // 旧数据没有 type 字段时默认 expense
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "user_id": "\(UUID().uuidString)",
            "amount": 50,
            "category": "交通",
            "merchant": "地铁",
            "date": "2026-08-01T00:00:00Z"
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Record.self, from: data)
        #expect(decoded.type == .expense)
        #expect(decoded.currency == "¥")
        #expect(decoded.amount == 50)
    }
}

// MARK: - RecordType 测试

struct RecordTypeTests {
    @Test func displayNames() {
        #expect(RecordType.expense.displayName == "支出")
        #expect(RecordType.income.displayName == "收入")
    }

    @Test func allCasesContainBothTypes() {
        #expect(RecordType.allCases.count == 2)
        #expect(RecordType.allCases.contains(.expense))
        #expect(RecordType.allCases.contains(.income))
    }
}

// MARK: - 月份分组测试

struct MonthRecordGroupTests {
    private func makeRecord(
        type: RecordType,
        amount: Double,
        month: (year: Int, month: Int) = (2026, 8)
    ) -> Record {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: month.year, month: month.month, day: 10))!
        return Record(
            id: UUID(),
            userId: UUID(),
            type: type,
            amount: amount,
            category: type == .expense ? "餐饮" : "工资",
            merchant: "测试",
            date: date
        )
    }

    @Test func totalAmountSumsRawAmounts() {
        let group = MonthRecordGroup(
            month: "2026-08",
            monthDisplay: "2026年08月",
            records: [
                makeRecord(type: .expense, amount: 100),
                makeRecord(type: .income, amount: 5000)
            ]
        )
        #expect(group.totalAmount == 5100)
    }

    @Test func netAmountIsIncomeMinusExpense() {
        let group = MonthRecordGroup(
            month: "2026-08",
            monthDisplay: "2026年08月",
            records: [
                makeRecord(type: .expense, amount: 100),
                makeRecord(type: .expense, amount: 50),
                makeRecord(type: .income, amount: 5000)
            ]
        )
        #expect(group.netAmount == 4850)
    }

    @Test func idEqualsMonth() {
        let group = MonthRecordGroup(month: "2026-08", monthDisplay: "2026年08月", records: [])
        #expect(group.id == "2026-08")
    }
}

struct MonthExpenseGroupTests {
    private func makeRecord(
        type: RecordType,
        amount: Double,
        currency: String
    ) -> Record {
        Record(
            id: UUID(),
            userId: UUID(),
            type: type,
            amount: amount,
            category: "餐饮",
            merchant: "测试",
            date: Date(),
            currency: currency
        )
    }

    @Test func totalAmountIsSignedSum() {
        let group = MonthExpenseGroup(
            month: "2026-08",
            monthDisplay: "2026年08月",
            expenses: [
                makeRecord(type: .expense, amount: 100, currency: "¥"),
                makeRecord(type: .income, amount: 300, currency: "¥")
            ]
        )
        #expect(group.totalAmount == 200)
    }

    @Test func totalByCurrencyGroupsAndSorts() {
        let group = MonthExpenseGroup(
            month: "2026-08",
            monthDisplay: "2026年08月",
            expenses: [
                makeRecord(type: .expense, amount: 100, currency: "$"),
                makeRecord(type: .expense, amount: 50, currency: "¥"),
                makeRecord(type: .income, amount: 200, currency: "$")
            ]
        )
        let totals = group.totalByCurrency
        #expect(totals.count == 2)
        // 按 key 排序：$ 在 ¥ 之前
        #expect(totals[0].currency == "$")
        #expect(totals[0].amount == 100)  // -100 + 200
        #expect(totals[1].currency == "¥")
        #expect(totals[1].amount == -50)
    }

    @Test func totalByCurrencyEmptyReturnsEmpty() {
        let group = MonthExpenseGroup(month: "2026-08", monthDisplay: "2026年08月", expenses: [])
        #expect(group.totalByCurrency.isEmpty)
    }
}

// MARK: - 每日限额测试

struct DailyLimitManagerTests {
    @Test func defaultDailyLimitIsFreeLimit() {
        // 测试环境默认无订阅缓存，应为免费额度
        #expect(DailyLimitManager.freeLimit == 30)
        #expect(DailyLimitManager.dailyLimit == 30)
    }

    @Test func incrementAndUsedCountTrackPerUser() {
        let userId = UUID()  // 每个测试用独立 UUID，避免 UserDefaults 相互污染
        let before = DailyLimitManager.usedCount(for: userId)
        DailyLimitManager.incrementUsage(for: userId)
        DailyLimitManager.incrementUsage(for: userId)
        let after = DailyLimitManager.usedCount(for: userId)
        #expect(after == before + 2)
    }

    @Test func remainingAndCanParseStayConsistent() {
        let userId = UUID()
        let startUsed = DailyLimitManager.usedCount(for: userId)
        let remaining = DailyLimitManager.remainingCount(for: userId)
        #expect(remaining == DailyLimitManager.dailyLimit - startUsed)
        #expect(DailyLimitManager.canParse(for: userId) == (remaining > 0))
    }

    @Test func remainingNeverNegative() {
        let userId = UUID()
        // 连续递增远超额度，remainingCount 不应为负
        for _ in 0..<(DailyLimitManager.dailyLimit + 50) {
            DailyLimitManager.incrementUsage(for: userId)
        }
        #expect(DailyLimitManager.remainingCount(for: userId) >= 0)
    }

    @Test func dailyLimitFixedInFreeMode() {
        // 全免费模式：每日限额固定为免费额度，不依赖任何订阅状态
        #expect(DailyLimitManager.dailyLimit == DailyLimitManager.freeLimit)
    }
}
