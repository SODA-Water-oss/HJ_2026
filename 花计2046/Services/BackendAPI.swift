import Foundation

enum BackendAPIError: LocalizedError {
    case invalidResponse
    case serverMessage(String)
    case decodeError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "后端返回无效响应。"
        case .serverMessage(let message):
            return message
        case .decodeError(let detail):
            return "数据解析失败: \(detail)"
        }
    }
}

struct BackendAPI {
    static let shared = BackendAPI()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()
    private let encoder = JSONEncoder()

    func post<Request: Encodable, Response: Decodable>(
        path: String,
        body: Request,
        requiresAuth: Bool = true
    ) async throws -> Response {
        var request = URLRequest(url: AppConfig.supabaseFunctionsURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 30

        if requiresAuth, let token = await SupabaseService.shared.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        let bodyData = try encoder.encode(body)
        request.httpBody = bodyData
        let bodyPreview = String(data: bodyData, encoding: .utf8)?.prefix(200) ?? ""

        Log.debug("→ POST /\(path) body=\(bodyPreview)")

        let data: Data
        let httpResponse: HTTPURLResponse

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            data = responseData
            guard let hr = response as? HTTPURLResponse else {
                Log.error("← POST /\(path) 无HTTP响应")
                throw BackendAPIError.invalidResponse
            }
            httpResponse = hr
        } catch let urlError as URLError {
            Log.error("← POST /\(path) 网络错误: \(urlError.localizedDescription) code=\(urlError.code.rawValue)")
            throw BackendAPIError.serverMessage("网络连接失败: \(urlError.localizedDescription)")
        }

        let rawBody = String(data: data, encoding: .utf8)?.prefix(500) ?? "<binary>"
        Log.info("← POST /\(path) \(httpResponse.statusCode) body=\(rawBody)")

        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorMessage = extractErrorMessage(from: data) ?? "请求失败(\(httpResponse.statusCode))"
            Log.error("← POST /\(path) 错误: \(errorMessage)")
            throw BackendAPIError.serverMessage(errorMessage)
        }

        do {
            let decoded = try decoder.decode(Response.self, from: data)
            return decoded
        } catch let decodingError as DecodingError {
            let detail = describeDecodingError(decodingError, data: data)
            Log.error("← POST /\(path) 解码失败: \(detail)")
            throw BackendAPIError.decodeError(detail)
        } catch {
            Log.error("← POST /\(path) 未知解码错误: \(error.localizedDescription)")
            throw BackendAPIError.decodeError(error.localizedDescription)
        }
    }

    /// 从响应数据中提取错误信息，支持多种格式
    private func extractErrorMessage(from data: Data) -> String? {
        // 尝试1: 标准格式 { "error": "message" }
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let errorStr = root["error"] as? String {
                return errorStr
            }
            // 尝试2: 嵌套格式 { "error": { "message": "..." } }
            if let errorObj = root["error"] as? [String: Any],
               let msg = errorObj["message"] as? String {
                return msg
            }
            // 尝试3: { "message": "..." }
            if let msg = root["message"] as? String {
                return msg
            }
            // 尝试4: { "msg": "..." }
            if let msg = root["msg"] as? String {
                return msg
            }
        }
        return nil
    }

    /// 解码错误的详细描述
    private func describeDecodingError(_ error: DecodingError, data: Data) -> String {
        let raw = String(data: data, encoding: .utf8)?.prefix(300) ?? ""

        switch error {
        case .keyNotFound(let key, let context):
            return "缺少字段 '\(key.stringValue)' (路径: \(context.codingPath.map(\.stringValue).joined(separator: ".")))"
        case .typeMismatch(let type, let context):
            return "类型不匹配: 期望 \(type), 路径: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "空值: \(type), 路径: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let context):
            return "数据损坏: \(context.debugDescription) raw=\(raw)"
        @unknown default:
            return "解码错误: \(error.localizedDescription) raw=\(raw)"
        }
    }
}
