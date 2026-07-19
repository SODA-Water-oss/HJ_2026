import Foundation

/// 安全的算术表达式求值器，支持 + - * / × ÷
struct MathCalculator {

    /// 正则匹配数学表达式：数字 + 运算符 + 数字（允许多步运算）
    private static let formulaPattern = try! NSRegularExpression(
        pattern: #"([\d.]+)\s*([+\-*/×÷])\s*([\d.]+)"#
    )

    /// 预处理输入文本，将公式替换为计算结果
    /// 例如 "午餐 35+20 超市" → "午餐 55 (35+20) 超市"
    static func preprocess(_ input: String) -> String {
        let lines = input.components(separatedBy: .newlines)
        var resultLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                resultLines.append("")
                continue
            }

            if containsFormula(trimmed) {
                let processed = evaluateFormulas(in: trimmed)
                resultLines.append(processed)
                Log.info("公式计算: \"\(trimmed)\" → \"\(processed)\"")
            } else {
                resultLines.append(trimmed)
            }
        }

        return resultLines.joined(separator: "\n")
    }

    /// 判断文本是否包含数学表达式
    static func containsFormula(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return formulaPattern.firstMatch(in: text, options: [], range: range) != nil
    }

    /// 计算文本中所有数学表达式并替换
    static func evaluateFormulas(in text: String) -> String {
        // 先尝试将整个文本作为表达式求值（不含中文上下文的情况）
        if isPureFormula(text) {
            if let result = evaluate(text) {
                return "\(formatNumber(result)) (\(text))"
            }
        }

        // 否则逐段替换：先处理复合表达式如 "35+20+15"
        var result = text
        let compoundPattern = try! NSRegularExpression(
            pattern: #"([\d.]+\s*(?:[+\-*/×÷]\s*[\d.]+)+)"#
        )

        let nsRange = NSRange(result.startIndex..<result.endIndex, in: result)
        let matches = compoundPattern.matches(in: result, options: [], range: nsRange)

        // 从后往前替换，避免索引偏移
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let expr = String(result[range])
            if let value = evaluate(expr) {
                result.replaceSubrange(range, with: "\(formatNumber(value)) (\(expr))")
            }
        }

        return result
    }

    /// 判断是否为纯数学表达式（不含中文/英文单词）
    private static func isPureFormula(_ text: String) -> Bool {
        let cleaned = text
            .replacingOccurrences(of: "＋", with: "+")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
        let allowedChars = CharacterSet(charactersIn: "0123456789.+-*/() ")
        return cleaned.rangeOfCharacter(from: allowedChars.inverted) == nil
            && cleaned.contains(where: { "+-*/×÷".contains($0) })
    }

    /// 求表达式的值
    static func evaluate(_ expression: String) -> Double? {
        let cleaned = expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "＋", with: "+")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: " ", with: "")

        guard !cleaned.isEmpty else { return nil }

        let nsExpression = NSExpression(format: cleaned)
        if let value = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber {
            let doubleValue = value.doubleValue
            guard doubleValue.isFinite, doubleValue >= 0 else { return nil }
            return doubleValue
        }
        return nil
    }

    /// 格式化数字：整数不显示小数点，小数保留2位
    static func formatNumber(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}
