import Foundation
import Combine

// MARK: - 智能体服务商

struct AgentProvider: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let baseURL: String
    let defaultModel: String

    static let all: [AgentProvider] = [
        AgentProvider(id: "deepseek", name: "DeepSeek", baseURL: "https://api.deepseek.com/v1/chat/completions", defaultModel: "deepseek-chat"),
        AgentProvider(id: "openai", name: "OpenAI", baseURL: "https://api.openai.com/v1/chat/completions", defaultModel: "gpt-4o-mini"),
        AgentProvider(id: "moonshot", name: "Kimi（Moonshot）", baseURL: "https://api.moonshot.cn/v1/chat/completions", defaultModel: "moonshot-v1-8k"),
        AgentProvider(id: "qwen", name: "通义千问", baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", defaultModel: "qwen-plus"),
        AgentProvider(id: "zhipu", name: "智谱 GLM", baseURL: "https://open.bigmodel.cn/api/paas/v4/chat/completions", defaultModel: "glm-4-flash"),
        AgentProvider(id: "gemini", name: "Gemini", baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions", defaultModel: "gemini-2.0-flash"),
        AgentProvider(id: "doubao", name: "豆包（火山方舟）", baseURL: "https://ark.cn-beijing.volces.com/api/v3/chat/completions", defaultModel: "doubao-1-5-lite-32k-250115"),
        AgentProvider(id: "custom", name: "OpenAI 兼容自定义", baseURL: "", defaultModel: "")
    ]

    static func find(id: String) -> AgentProvider? {
        all.first { $0.id == id }
    }

    static let modelOptions: [String: [String]] = [
        "deepseek": ["deepseek-chat", "deepseek-reasoner"],
        "openai": ["gpt-4o-mini", "gpt-4o", "gpt-4.1-mini"],
        "moonshot": ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"],
        "qwen": ["qwen-plus", "qwen-turbo", "qwen-max"],
        "zhipu": ["glm-4-flash", "glm-4-plus", "glm-4-air"],
        "gemini": ["gemini-2.0-flash", "gemini-2.5-flash", "gemini-2.5-pro"],
        "doubao": ["doubao-1-5-lite-32k-250115", "doubao-1-5-pro-32k-250115"],
        "custom": ["自定义模型"]
    ]
}

// MARK: - 智能体配置

struct AgentConfig: Codable, Equatable {
    var providerID: String
    var model: String
    var apiKey: String
    var baseURL: String
    var updatedAt: Date

    var provider: AgentProvider? { AgentProvider.find(id: providerID) }

    var displayName: String {
        (provider?.name ?? "自定义智能体") + " · " + (model.isEmpty ? "未设置模型" : model)
    }

    var isValid: Bool {
        !providerID.isEmpty && !model.isEmpty && !apiKey.isEmpty && !baseURL.isEmpty
    }
}

// MARK: - 异常定义

enum AgentConfigError: LocalizedError {
    case invalidKey
    case quotaExceeded
    case rateLimited
    case modelNotFound
    case invalidConfig(String)
    case network(String)
    case server(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "请正确配置智能体：API Key 无效，请检查后重试"
        case .quotaExceeded:
            return "当前智能体配置异常：已欠费或余额不足，请重新配置"
        case .rateLimited:
            return "当前智能体配置异常：请求过于频繁，请稍后再试"
        case .modelNotFound:
            return "请正确配置智能体：模型不存在，请检查模型名称"
        case .invalidConfig(let msg):
            return "请正确配置智能体：" + (msg.isEmpty ? "接口或模型参数有误" : msg)
        case .network(let msg):
            return "当前智能体配置异常：网络连接失败" + (msg.isEmpty ? "" : "（\(msg)）")
        case .server(let msg):
            return "当前智能体配置异常：服务暂时不可用" + (msg.isEmpty ? "" : "（\(msg)）")
        case .unknown(let msg):
            return "当前智能体配置异常：" + (msg.isEmpty ? "未知错误" : msg)
        }
    }
}

struct AgentFailure: Equatable {
    let providerName: String
    let reason: String
    let occurredAt: Date

    var message: String {
        "你的智能体（\(providerName)）异常：\(reason)。已临时使用默认智能体接管，请重新配置。"
    }
}

// MARK: - 智能体配置管理器

@MainActor
final class AgentConfigManager: ObservableObject {
    static let shared = AgentConfigManager()

    @Published private(set) var config: AgentConfig?
    @Published private(set) var lastFailure: AgentFailure?

    private let defaultKey = "com.nsoft.huaji2046.agent_config_default"
    private let configuredFlag = "agent_configured"
    private var currentUserID: UUID?

    private init() {
        config = loadFromKeychain(key: defaultKey)
        updateConfiguredFlag()
    }

    var hasCustomAgent: Bool { config?.isValid == true }

    nonisolated static var cachedHasCustomAgent: Bool {
        UserDefaults.standard.bool(forKey: "agent_configured")
    }

    /// 绑定当前登录用户，智能体配置按用户隔离；登录时会把未登录状态下暂存的配置迁移到该用户。
    func bind(userID: UUID?) {
        currentUserID = userID
        if let userID {
            let userKey = keychainKey(for: userID)
            if let saved = loadFromKeychain(key: userKey) {
                config = saved
            } else if let pending = loadFromKeychain(key: defaultKey) {
                _ = KeychainHelper.saveCodable(pending, forKey: userKey)
                KeychainHelper.delete(key: defaultKey)
                config = pending
            } else {
                config = nil
            }
        } else {
            config = nil
        }
        updateConfiguredFlag()
        lastFailure = nil
    }

    func save(_ newConfig: AgentConfig) {
        _ = KeychainHelper.saveCodable(newConfig, forKey: keychainKey(for: currentUserID))
        config = newConfig
        updateConfiguredFlag()
        lastFailure = nil
    }

    func clear() {
        KeychainHelper.delete(key: keychainKey(for: currentUserID))
        config = nil
        updateConfiguredFlag()
        lastFailure = nil
    }

    /// 结构化解析任务使用低成本模型，避免推理模型产生高额思考 token。
    private func modelForStructuredTasks(_ config: AgentConfig) -> AgentConfig {
        guard config.providerID == "deepseek", config.model.lowercased().contains("reasoner") else {
            return config
        }
        Log.info("DeepSeek reasoner 不用于结构化解析，临时切换为 deepseek-chat 以节省 token")
        var copy = config
        copy.model = "deepseek-chat"
        return copy
    }

    /// 删除指定用户的智能体配置（注销账号时调用）
    func delete(userID: UUID) {
        KeychainHelper.delete(key: keychainKey(for: userID))
        if currentUserID == userID {
            config = nil
            updateConfiguredFlag()
            lastFailure = nil
        }
    }

    func recordFailure(providerName: String, reason: String) {
        lastFailure = AgentFailure(providerName: providerName, reason: reason, occurredAt: Date())
    }

    func clearFailure() {
        lastFailure = nil
    }

    // MARK: - 校验

    func verify(_ draft: AgentConfig) async throws {
        _ = try await callChat(
            config: draft,
            messages: [["role": "user", "content": "ping"]],
            jsonMode: false,
            maxTokens: 8
        )
    }

    // MARK: - 记账解析

    func parseExpense(input: String, config: AgentConfig) async throws -> [GeminiService.ParsedExpense] {
        let systemPrompt = "你是记账解析器。从输入提取每笔收支，只输出 JSON，不解释。格式：{\"items\":[{\"type\":\"expense|income\",\"amount\":数字,\"category\":\"类别\",\"merchant\":\"名称\"}]}。type 只能是 \"expense\" 或 \"income\"。判定规则：工资、奖金、兼职、投资、理财、礼金、退款、报销、红包、利息、分红等收到钱的属于收入，type=income；花钱消费、付款、转账给别人、缴纳费用等属于支出，type=expense。支出类别：餐饮,交通,购物,娱乐,住房,日用,服饰,通讯,医疗,教育,其他；收入类别：工资,奖金,兼职,投资,理财,礼金,退款,其他。多笔逐项输出。"

        let raw = try await callChat(
            config: modelForStructuredTasks(config),
            messages: [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": input]
            ],
            jsonMode: true,
            maxTokens: 512
        )

        guard let jsonData = extractJSON(from: raw) else {
            throw AgentConfigError.unknown("返回数据格式异常")
        }
        let result = try JSONDecoder().decode(GeminiService.ParseResult.self, from: jsonData)
        return normalize(items: result.items)
    }

    // MARK: - 最近收支点评

    func generateReview(config: AgentConfig, records: [Record]) async throws -> String {
        let summary = buildSummary(records)
        let prompt = [
            "你是一个爱写手帐、说话俏皮的记账达人，正在给用户写一段最近收支手帐点评。",
            "根据下面的数据，写一段 25-35 字的中文点评，只保留最核心、最有智慧的一句。",
            "要求：",
            "1. 主体全部使用正常中文文字，不要用 emoji 代替文字，也不要堆砌图标",
            "2. 最多在结尾加 1 个小表情表达态度，例如 🌱、✨、💪，不加也可以",
            "3. 既要结合近30天收支的具体观察，也要结合近12个月整体趋势，用一句话点出关键",
            "4. 客观、幽默、善意，可以调侃消费习惯，但绝不低俗、不嘲讽、不伤害用户",
            "5. 数据自然融入，不罗列数字，可适度夸张；结尾给一点温暖鼓励",
            "6. 直接输出点评文本，用「你」称呼，不要引号、不要任何前缀、不要分点编号、不要解释",
            "",
            "数据如下：",
            summary
        ].joined(separator: "\n")

        let raw = try await callChat(
            config: config,
            messages: [
                ["role": "system", "content": "你是花计2046的轻松生活点评助手。"],
                ["role": "user", "content": prompt]
            ],
            jsonMode: false,
            maxTokens: 160
        )
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AgentConfigError.unknown("返回内容为空") }
        return text
    }

    // MARK: - OpenAI 兼容请求

    private func callChat(
        config: AgentConfig,
        messages: [[String: String]],
        jsonMode: Bool,
        maxTokens: Int
    ) async throws -> String {
        guard let url = URL(string: config.baseURL), !config.apiKey.isEmpty else {
            throw AgentConfigError.invalidConfig("接口地址或 API Key 为空")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        var payload: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": 0.2
        ]
        if jsonMode {
            payload["response_format"] = ["type": "json_object"]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let httpResponse: HTTPURLResponse
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AgentConfigError.network("无 HTTP 响应")
            }
            data = responseData
            httpResponse = http
        } catch let error as AgentConfigError {
            throw error
        } catch {
            throw AgentConfigError.network(error.localizedDescription)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw mapError(statusCode: httpResponse.statusCode, data: data)
        }

        struct ChatResponse: Decodable {
            struct Usage: Decodable {
                let promptTokens: Int
                let completionTokens: Int

                enum CodingKeys: String, CodingKey {
                    case promptTokens = "prompt_tokens"
                    case completionTokens = "completion_tokens"
                }
            }
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
            let usage: Usage?
        }

        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            if let usage = decoded.usage {
                Log.info("智能体 token: \(config.displayName) prompt=\(usage.promptTokens) completion=\(usage.completionTokens) total=\(usage.promptTokens + usage.completionTokens)")
            }
            guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
                throw AgentConfigError.unknown("返回内容为空")
            }
            return content
        } catch let error as AgentConfigError {
            throw error
        } catch {
            throw AgentConfigError.unknown("响应解析失败")
        }
    }

    private func mapError(statusCode: Int, data: Data) -> AgentConfigError {
        let message = extractErrorMessage(from: data)
        switch statusCode {
        case 401:
            return .invalidKey
        case 402, 403:
            return .quotaExceeded
        case 404:
            return .modelNotFound
        case 429:
            return .rateLimited
        case 400:
            return .invalidConfig(message ?? "请求参数有误")
        case 500...599:
            return .server(message ?? "服务暂时不可用")
        default:
            return .unknown(message ?? "请求失败（\(statusCode)）")
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = root["error"] as? [String: Any], let msg = error["message"] as? String { return msg }
        if let msg = root["error"] as? String { return msg }
        if let msg = root["message"] as? String { return msg }
        return nil
    }

    // MARK: - 数据处理

    private func normalize(items: [GeminiService.ParsedExpense]) -> [GeminiService.ParsedExpense] {
        let validCats = CategoryManager.expenseCats + CategoryManager.incomeCats
        return items.map { item in
            var finalCat = item.category
            if !validCats.contains(item.category) {
                finalCat = item.type == .expense ? CategoryManager.defaultExpenseCat : CategoryManager.defaultIncomeCat
            }
            return GeminiService.ParsedExpense(
                id: UUID(),
                type: item.type,
                amount: item.amount,
                category: finalCat,
                merchant: item.merchant,
                note: item.note
            )
        }
    }

    private func extractJSON(from text: String) -> Data? {
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            let json = text[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            return json.data(using: .utf8)
        }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end]).data(using: .utf8)
        }
        return text.data(using: .utf8)
    }

    private func buildSummary(_ records: [Record]) -> String {
        let now = Date()
        let calendar = Calendar.current
        let recentStart = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let trendStart = calendar.date(byAdding: .month, value: -12, to: now) ?? now
        let recentRecords = records.filter { $0.date >= recentStart }
        let trendRecords = records.filter { $0.date >= trendStart }

        let recent = summarizeRecords(recentRecords)
        let trend = monthlyTrend(trendRecords)

        let summary: [String: Any] = [
            "recent": recent,
            "trend": trend
        ]
        if let data = try? JSONSerialization.data(withJSONObject: summary),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    private func summarizeRecords(_ records: [Record]) -> [String: Any] {
        var expense = 0.0
        var income = 0.0
        var count = 0
        var maxExpense = (amount: 0.0, merchant: "无")
        var categoryExpense: [String: Double] = [:]

        for record in records {
            count += 1
            if record.isIncome {
                income += record.amount
            } else {
                expense += record.amount
                categoryExpense[record.category, default: 0] += record.amount
                if record.amount > maxExpense.amount {
                    maxExpense = (record.amount, record.merchant.isEmpty ? "无" : record.merchant)
                }
            }
        }

        let topCategory = categoryExpense.sorted { $0.value > $1.value }.first?.key ?? "无"
        let diningRatio = expense > 0 ? Int((categoryExpense["餐饮"] ?? 0) / expense * 100) : 0
        let avgExpense = count > 0 ? Int(expense / Double(count)) : 0
        return [
            "expense": Int(expense),
            "income": Int(income),
            "recordCount": count,
            "maxExpenseMerchant": maxExpense.merchant,
            "maxExpenseAmount": maxExpense.amount,
            "topCategory": topCategory,
            "diningRatio": diningRatio,
            "avgExpense": avgExpense
        ]
    }

    private func monthlyTrend(_ records: [Record]) -> [String: Any] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        var monthly: [String: (income: Double, expense: Double)] = [:]
        for record in records {
            let key = formatter.string(from: record.date)
            var bucket = monthly[key] ?? (0, 0)
            if record.isIncome {
                bucket.income += record.amount
            } else {
                bucket.expense += record.amount
            }
            monthly[key] = bucket
        }

        let months = monthly.keys.sorted().suffix(12)
        let incomeTrend = months.map { Int(monthly[$0]?.income ?? 0) }
        let expenseTrend = months.map { Int(monthly[$0]?.expense ?? 0) }
        let totalIncome = incomeTrend.reduce(0, +)
        let totalExpense = expenseTrend.reduce(0, +)

        var trendDirection = "平稳"
        if expenseTrend.count >= 2 {
            let latest = expenseTrend[expenseTrend.count - 1]
            let previous = expenseTrend[expenseTrend.count - 2]
            if previous > 0 {
                if latest > Int(Double(previous) * 1.15) {
                    trendDirection = "上升"
                } else if latest < Int(Double(previous) * 0.85) {
                    trendDirection = "下降"
                }
            }
        }

        let maxExpense = expenseTrend.max() ?? 0
        let peakMonth = expenseTrend.firstIndex(of: maxExpense)
            .map { months[months.index(months.startIndex, offsetBy: $0)] } ?? ""

        return [
            "months": Array(months),
            "incomeTrend": incomeTrend,
            "expenseTrend": expenseTrend,
            "totalIncome": totalIncome,
            "totalExpense": totalExpense,
            "trendDirection": trendDirection,
            "peakMonth": peakMonth
        ]
    }

    private func keychainKey(for userID: UUID?) -> String {
        guard let userID else { return defaultKey }
        return "com.nsoft.huaji2046.agent_config.\(userID.uuidString)"
    }

    private func loadFromKeychain(key: String) -> AgentConfig? {
        KeychainHelper.loadCodable(AgentConfig.self, forKey: key)
    }

    private func updateConfiguredFlag() {
        UserDefaults.standard.set(config?.isValid == true, forKey: configuredFlag)
    }
}
