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
}
