import Foundation

// 向后兼容: Expense → Record
typealias Expense = Record

/// 按月份分组的支出数据
struct MonthExpenseGroup: Identifiable {
    let month: String
    let monthDisplay: String
    let expenses: [Expense]

    var id: String { month }

   var totalAmount: Double {
        expenses.reduce(0) { $0 + ($1.type == .expense ? -$1.amount : $1.amount) }
   }

    /// 按货币分组的小计
    var totalByCurrency: [(currency: String, amount: Double)] {
        guard !expenses.isEmpty else { return [] }
        var dict: [String: Double] = [:]
        for exp in expenses {
            let key = exp.currency.isEmpty ? "¥" : exp.currency
            dict[key, default: 0] += exp.type == .expense ? -exp.amount : exp.amount
        }
        return dict.sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }
}
