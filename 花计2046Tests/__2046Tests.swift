//
//  __2046Tests.swift
//  花计2046Tests
//
//  Created by PoundsZero on 2026/4/9.
//

import Foundation
import Testing
@testable import 花计2046

struct __2046Tests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

}

struct MathCalculatorTests {

    @Test func simpleAddition() {
        #expect(MathCalculator.evaluate("35+20") == 55)
    }

    @Test func multiplicationPrecedence() {
        #expect(MathCalculator.evaluate("3+2*4") == 11)
    }

    @Test func pureText_noFormula() {
        #expect(MathCalculator.containsFormula("午餐") == false)
    }

    @Test func chineseMixedText() {
        #expect(MathCalculator.preprocess("午餐35+20超市") == "午餐55 (35+20)超市")
    }

    @Test func chainedAddition() {
        #expect(MathCalculator.preprocess("35+20+15") == "70 (35+20+15)")
    }

    @Test func zeroInput_returnsNil() {
        #expect(MathCalculator.evaluate("") == nil)
    }

    @Test func fullWidthOperators() {
        #expect(MathCalculator.evaluate("3×4") == 12)
        #expect(MathCalculator.evaluate("8÷2") == 4)
    }

    @Test func subtraction() {
        #expect(MathCalculator.evaluate("100-35") == 65)
    }

    @Test func division() {
        #expect(MathCalculator.evaluate("10/3") == (10.0 / 3.0))
    }
}
 
 struct SearchFilterTests {
     private let testExpense = Record(
         id: UUID(), userId: UUID(), type: .expense,
         amount: 35.5, category: "餐饮", merchant: "星巴克咖啡",
         date: Date(), note: "周末消费"
     )
     private let testIncome = Record(
         id: UUID(), userId: UUID(), type: .income,
         amount: 5000, category: "工资", merchant: "公司",
         date: Date(), note: "七月工资"
     )
     private let testOtherExpense = Record(
         id: UUID(), userId: UUID(), type: .expense,
         amount: 100, category: "其他", merchant: "杂项",
         date: Date(), note: nil
     )
 
     @Test func emptySearch_matchesAll() {
         #expect(testExpense.matchesSearch(searchText: "", searchNote: "", searchCategory: "", searchYear: "", searchMonth: ""))
         #expect(testIncome.matchesSearch(searchText: "", searchNote: "", searchCategory: "", searchYear: "", searchMonth: ""))
         #expect(testOtherExpense.matchesSearch(searchText: "", searchNote: "", searchCategory: "", searchYear: "", searchMonth: ""))
     }
 
     @Test func searchByMerchant() {
         #expect(testExpense.matchesSearch(searchText: "星巴克", searchNote: "", searchCategory: "", searchYear: "", searchMonth: ""))
         #expect(testIncome.matchesSearch(searchText: "星巴克", searchNote: "", searchCategory: "", searchYear: "", searchMonth: "") == false)
         #expect(testOtherExpense.matchesSearch(searchText: "星巴克", searchNote: "", searchCategory: "", searchYear: "", searchMonth: "") == false)
     }
 
     @Test func searchByCategory() {
         #expect(testExpense.matchesSearch(searchText: "", searchNote: "", searchCategory: "餐饮", searchYear: "", searchMonth: ""))
         #expect(testIncome.matchesSearch(searchText: "", searchNote: "", searchCategory: "餐饮", searchYear: "", searchMonth: "") == false)
     }
 
     @Test func searchOtherExpense() {
         #expect(testOtherExpense.matchesSearch(searchText: "", searchNote: "", searchCategory: "其他支出", searchYear: "", searchMonth: ""))
         #expect(testExpense.matchesSearch(searchText: "", searchNote: "", searchCategory: "其他支出", searchYear: "", searchMonth: "") == false)
         #expect(testIncome.matchesSearch(searchText: "", searchNote: "", searchCategory: "其他支出", searchYear: "", searchMonth: "") == false)
     }
 
     @Test func searchByNote() {
         #expect(testExpense.matchesSearch(searchText: "", searchNote: "周末", searchCategory: "", searchYear: "", searchMonth: ""))
         #expect(testIncome.matchesSearch(searchText: "", searchNote: "周末", searchCategory: "", searchYear: "", searchMonth: "") == false)
     }
 
     @Test func combinedSearch() {
         #expect(testExpense.matchesSearch(
             searchText: "星巴克", searchNote: "周末", searchCategory: "餐饮",
             searchYear: "2026", searchMonth: ""
         ))
         #expect(testIncome.matchesSearch(
             searchText: "星巴克", searchNote: "", searchCategory: "",
             searchYear: "", searchMonth: ""
         ) == false)
     }
 
     @Test func nilNote_doesNotCrash() {
         #expect(testOtherExpense.matchesSearch(searchText: "", searchNote: "消费", searchCategory: "", searchYear: "", searchMonth: "") == false)
     }
 }

 struct AnalyticsChartIDTests {

     @Test func barPointID_isStableForSameMonthAndType() {
         let a = AnalyticsBarPoint(month: "07/26", type: "收入", amount: 10)
         let b = AnalyticsBarPoint(month: "07/26", type: "收入", amount: 99)
         #expect(a.id == b.id)
     }

     @Test func barPointID_differsWhenMonthOrTypeChanges() {
         let a = AnalyticsBarPoint(month: "07/26", type: "收入", amount: 10)
         let b = AnalyticsBarPoint(month: "07/26", type: "支出", amount: 10)
         #expect(a.id != b.id)
     }

     @Test func linePointID_isStableForSameMonth() {
         let a = AnalyticsLinePoint(month: "2026-07", monthDisplay: "07/26", net: 5)
         let b = AnalyticsLinePoint(month: "2026-07", monthDisplay: "07/26", net: -5)
         #expect(a.id == b.id)
     }

     @Test func dotPointID_isStableForSameDayAndType() {
         let a = AnalyticsDotPoint(day: 15, type: "收入", amount: 1)
         let b = AnalyticsDotPoint(day: 15, type: "收入", amount: 100)
         #expect(a.id == b.id)
     }

     @Test func dotPointID_differsWhenTypeChanges() {
         let a = AnalyticsDotPoint(day: 15, type: "收入", amount: 1)
         let b = AnalyticsDotPoint(day: 15, type: "支出", amount: 1)
         #expect(a.id != b.id)
     }
 }
