import Foundation
import Combine

class GeminiService: ObservableObject {
    static let shared = GeminiService()

    struct ParsedExpense: Codable, Identifiable {
        var id = UUID()
        var type: RecordType = .expense
        var amount: Double
        var category: String
        var merchant: String
        var note: String?

        enum CodingKeys: String, CodingKey {
            case type, amount, category, merchant, note
        }

        init(id: UUID = UUID(), type: RecordType = .expense, amount: Double, category: String, merchant: String, note: String? = nil) {
            self.id = id
            self.type = type
            self.amount = amount
            self.category = category
            self.merchant = merchant
            self.note = note
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            amount = try container.decode(Double.self, forKey: .amount)
            category = try container.decode(String.self, forKey: .category)
            merchant = try container.decode(String.self, forKey: .merchant)
            note = try container.decodeIfPresent(String.self, forKey: .note)
            let rawType = try container.decodeIfPresent(String.self, forKey: .type) ?? "expense"
            type = Self.parseType(rawType, category: category, merchant: merchant)
        }

        private static func parseType(_ raw: String, category: String, merchant: String) -> RecordType {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if t == "income" || t == "收入" || t == "入账" || t == "进账" { return .income }
            if t == "expense" || t == "支出" || t == "消费" || t == "花费" { return .expense }
            let hint = "\(category) \(merchant)"
            let incomeKeywords = ["工资", "奖金", "兼职", "投资", "理财", "礼金", "退款", "报销", "红包", "利息", "分红", "入账", "收入", "进账"]
            return incomeKeywords.contains(where: { hint.contains($0) }) ? .income : .expense
        }
    }

    struct ParseResult: Codable {
        let items: [ParsedExpense]
    }

    /// 文字解析入口：优先用户配置的智能体，失败自动降级默认智能体
    func parseExpense(input: String) async throws -> [ParsedExpense] {
        Log.info("AI 文字解析: input='\(input.prefix(200))'")

        if let customConfig = await AgentConfigManager.shared.config, customConfig.isValid {
            do {
                let items = try await AgentConfigManager.shared.parseExpense(input: input, config: customConfig)
                Log.info("自定义智能体解析成功: \(customConfig.displayName) items=\(items.count)")
                return items
            } catch {
                let reason = (error as? AgentConfigError)?.errorDescription ?? error.localizedDescription
                await AgentConfigManager.shared.recordFailure(providerName: customConfig.displayName, reason: reason)
                Log.warn("自定义智能体解析失败，降级默认智能体: \(reason)")
            }
        }
        return try await parseWithDefault(input: input)
    }

    /// 默认智能体：DEBUG 走 DeepSeek，Release 走后端 Edge Function
    private func parseWithDefault(input: String) async throws -> [ParsedExpense] {
        #if DEBUG
        // DEBUG 模式优先使用 DeepSeek 直接解析，便于快速开发和离线测试
        return try await parseWithDeepSeek(input: input)
        #else
        // Release 模式走后端 Gemini Edge Function
        return try await parseWithBackend(input: input)
        #endif
    }

    /// Release 模式：使用远程后端 API 解析文字
    private func parseWithBackend(input: String) async throws -> [ParsedExpense] {
        let result: ParseResult = try await BackendAPI.shared.post(
            path: "parse-expense",
            body: ParseTextRequest(input: input)
        )
        return normalize(items: result.items)
    }

    /// DEBUG 模式：使用 DeepSeek API 解析文字
    private func parseWithDeepSeek(input: String) async throws -> [ParsedExpense] {
        let result: ParseResult
        do {
            result = try await callDeepSeek(input: input)
        } catch {
            let fallback = fallbackParse(input: input)
            if !fallback.isEmpty { return fallback }
            throw error
        }
        Log.info("DeepSeek 解析成功: items=\(result.items.count)")
        return normalize(items: result.items)
    }

    /// 统一后处理：修正非法类别、补全默认值
    private func normalize(items: [ParsedExpense]) -> [ParsedExpense] {
        let validCats = CategoryManager.expenseCats + CategoryManager.incomeCats
        return items.map { item in
            var finalCat = item.category
            if !validCats.contains(item.category) {
                finalCat = item.type == .expense ? CategoryManager.defaultExpenseCat : CategoryManager.defaultIncomeCat
            }
            return ParsedExpense(
                id: UUID(),
                type: item.type,
                amount: item.amount,
                category: finalCat,
                merchant: item.merchant,
                note: item.note
            )
        }
    }

    /// 本地兜底解析：正则提取数字+文字，DeepSeek失败时使用
    private func fallbackParse(input: String) -> [ParsedExpense] {
        guard let pattern = try? NSRegularExpression(pattern: #"([\u4e00-\u9fa5a-zA-Z]+)[¥￥\s]*(\d+\.?\d*)"#) else { return [] }
        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = pattern.matches(in: input, range: nsRange)
        var results: [ParsedExpense] = []
        let expenseCats = ["餐饮","交通","购物","娱乐","住房","日用","服饰","通讯","医疗","教育","其他"]
        let incomeCats = ["工资","奖金","兼职","投资","理财","礼金","退款","其他"]
        let incomeKeywords = ["工资","奖金","兼职","投资","理财","礼金","退款","报销","红包","利息","分红","入账","收入","进账"]
        for match in matches {
           guard match.numberOfRanges == 3 else { continue }
            guard let nameRange = Range(match.range(at: 1), in: input),
                  let amountRange = Range(match.range(at: 2), in: input) else { continue }
            let name = String(input[nameRange])
            guard let amount = Double(String(input[amountRange])), amount > 0, amount < 99999999 else { continue }
            let isIncome = incomeKeywords.contains(where: { name.contains($0) })
            var category = "其他"
            if isIncome {
                for cat in incomeCats where cat == name || name.contains(cat) { category = cat; break }
                if category == "其他" { category = "工资" }
            } else {
                for cat in expenseCats where cat == name || name.contains(cat.prefix(1)) { category = cat; break }
            }
            results.append(ParsedExpense(type: isIncome ? .income : .expense, amount: amount, category: category, merchant: name, note: nil))
        }
        return results
    }

    /// 调用 DeepSeek Chat API
    private func callDeepSeek(input: String) async throws -> ParseResult {
        guard let url = URL(string: "https://api.deepseek.com/v1/chat/completions") else { throw NSError(domain: "DeepSeek", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL配置错误"]) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppConfig.deepSeekAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let systemPrompt = "你是记账解析器。从输入提取每笔收支，只输出 JSON，不解释。格式：{\"items\":[{\"type\":\"expense|income\",\"amount\":数字,\"category\":\"类别\",\"merchant\":\"名称\"}]}。type 只能是 \"expense\" 或 \"income\"。工资、奖金、兼职、投资、理财、礼金、退款、报销、红包等收到钱的属于收入，type=income；花钱消费属于支出，type=expense。支出类别：餐饮,交通,购物,娱乐,住房,日用,服饰,通讯,医疗,教育,其他；收入类别：工资,奖金,兼职,投资,理财,礼金,退款,其他。多笔逐项输出。"
        let body: [String: Any] = [
           "model": "deepseek-chat",
           "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": input]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.1,
            "max_tokens": 512
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        Log.debug("→ DeepSeek POST")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            Log.error("DeepSeek 网络错误: \(error.localizedDescription)")
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "DeepSeek", code: 0, userInfo: [NSLocalizedDescriptionKey: "无HTTP响应"])
        }

        guard httpResponse.statusCode == 200 else {
            let errMsg = extractError(from: data) ?? "API请求失败(\(httpResponse.statusCode))"
            Log.error("DeepSeek API 错误: \(errMsg)")
            throw NSError(domain: "DeepSeek", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let raw = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
            Log.error("DeepSeek 响应格式异常: \(raw)")
            throw NSError(domain: "DeepSeek", code: 0, userInfo: [NSLocalizedDescriptionKey: "响应格式异常"])
        }
        if let usage = root["usage"] as? [String: Any] {
            let promptTokens = usage["prompt_tokens"] as? Int ?? 0
            let completionTokens = usage["completion_tokens"] as? Int ?? 0
            Log.info("DeepSeek token: prompt=\(promptTokens) completion=\(completionTokens) total=\(promptTokens + completionTokens)")
        }

        guard let jsonData = extractJSON(from: content) else {
            Log.error("DeepSeek 返回非JSON: \(content.prefix(300))")
            throw NSError(domain: "DeepSeek", code: 0, userInfo: [NSLocalizedDescriptionKey: "返回格式错误"])
        }

        let decoder = JSONDecoder()
        let parseResult = try decoder.decode(ParseResult.self, from: jsonData)
        return parseResult
    }

    /// 从文本中提取 JSON 部分
    private func extractJSON(from text: String) -> Data? {
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            let json = text[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            return json.data(using: .utf8)
        }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            let json = text[start...end]
            return String(json).data(using: .utf8)
        }
        return text.data(using: .utf8)
    }

    private func extractError(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let err = root["error"] as? [String: Any], let msg = err["message"] as? String { return msg }
        if let msg = root["message"] as? String { return msg }
        return nil
    }

    /// 音频解析入口：始终走后端 Edge Function
    func parseExpenseFromAudio(audioData: Data) async throws -> [ParsedExpense] {
        let result: ParseResult = try await BackendAPI.shared.post(
            path: "parse-expense",
            body: ParseAudioRequest(
                audioBase64: audioData.base64EncodedString(),
                mimeType: "audio/m4a"
            )
        )
        return normalize(items: result.items)
    }
}

private struct ParseTextRequest: Encodable {
    let mode = "text"
    let input: String
}

private struct ParseAudioRequest: Encodable {
    let mode = "audio"
    let audioBase64: String
    let mimeType: String
}
