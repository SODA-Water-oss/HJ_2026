//
//  __2046Tests.swift
//  花计2046Tests
//
//  Created by PoundsZero on 2026/4/9.
//

import Testing
@testable import __2046

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
