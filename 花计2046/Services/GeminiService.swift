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
            type = try container.decodeIfPresent(RecordType.self, forKey: .type) ?? .expense
            amount = try container.decode(Double.self, forKey: .amount)
            category = try container.decode(String.self, forKey: .category)
            merchant = try container.decode(String.self, forKey: .merchant)
            note = try container.decodeIfPresent(String.self, forKey: .note)
        }
    }

    struct ParseResult: Codable {
        let items: [ParsedExpense]
    }

#if DEBUG
    /// DEBUG 模式：使用 DeepSeek API 进行解析
    func parseExpense(input: String) async throws -> [ParsedExpense] {
        Log.info("DeepSeek 解析: input='\(input.prefix(200))'")

        let prompt = "你是一个智能记账助手。请从用户的输入中提取每一笔收支信息。" +
            "规则：type=expense（支出）或income（收入），根据语义判断。" +
            "merchant=名称(不含金额/单位/标点)。" +
            "amount=金额数字。支出category从[餐饮,交通,购物,娱乐,住房,日用,服饰,通讯,医疗,教育,其他]中选择。" +
            "收入category从[工资,奖金,兼职,投资收益,理财,礼金,退款,其他]中选择。" +
            "注意：多笔每笔输出一项。名称通常是金额前面的词。不要输出备注。" +
            "用户输入：" + input + "。" +
            "请以JSON格式输出：{\"items\":[{\"type\":\"expense\",\"merchant\":\"名称\",\"amount\":金额数字,\"category\":\"类别\"}]}"

        let result = try await callDeepSeek(prompt: prompt)
        Log.info("DeepSeek 解析成功: items=\(result.items.count)")
        return result.items.map { item in
            ParsedExpense(
                type: item.type,
                amount: item.amount,
                category: item.category,
                merchant: item.merchant,
                note: nil
            )
        }
    }

    /// 调用 DeepSeek Chat API
    private func callDeepSeek(prompt: String) async throws -> ParseResult {
        let url = URL(string: "https://api.deepseek.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppConfig.deepSeekAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": "你是一个精准的记账解析助手，只输出JSON格式。"],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.1,
            "max_tokens": 1024
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

        // 解析 API 响应
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let raw = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
            Log.error("DeepSeek 响应格式异常: \(raw)")
            throw NSError(domain: "DeepSeek", code: 0, userInfo: [NSLocalizedDescriptionKey: "响应格式异常"])
        }

        // 从 content 中提取 JSON
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
#endif

    /// Release 模式：使用远程后端 API 解析
    func parseExpenseFromAudio(audioData: Data) async throws -> [ParsedExpense] {
        let result: ParseResult = try await BackendAPI.shared.post(
            path: "parse-expense",
            body: ParseAudioRequest(
                audioBase64: audioData.base64EncodedString(),
                mimeType: "audio/m4a"
            )
        )
        return result.items.map { item in
            var mutable = item
            mutable.id = UUID()
            mutable.type = item.type
            return mutable
        }
    }
}

private struct ParseAudioRequest: Encodable {
    let mode = "audio"
    let audioBase64: String
    let mimeType: String
}
