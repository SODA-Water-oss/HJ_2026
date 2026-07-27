import Foundation
import Supabase

/// 用户设置云端同步
@MainActor
class UserSettingsSync {
    static let shared = UserSettingsSync()
    
    private struct SettingsPayload: Encodable {
        let userId: String
        let settings: [String: String]
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case settings
            case updatedAt = "updated_at"
        }
    }
    
    private let storageKeys: [String] = [
        "currency_symbol",
        "enabled_expense_cats",
        "enabled_income_cats",
        "custom_expense_cats",
        "custom_income_cats",
        "default_expense_cat",
        "default_income_cat"
    ]
    
    /// 登录后从云端加载设置 → 写入本地 UserDefaults
    func load(supabaseService: SupabaseService) async {
        guard !AppConfig.useMockServices,
              let userId = supabaseService.currentUser?.id else { return }
        
        do {
            let response: [[String: AnyCodable]] = try await supabaseService.client
                .from("user_settings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            
            if let row = response.first, let raw = row["settings"] {
                if let settingsData = try? JSONSerialization.data(withJSONObject: raw, options: []),
                   let settings = try? JSONDecoder().decode([String: String].self, from: settingsData) {
                    for (key, value) in settings {
                        UserDefaults.standard.set(value, forKey: key)
                    }
                    Log.info("用户设置已从云端加载")
                }
            }
        } catch {
            Log.info("用户设置加载失败（首次使用或无设置）: \(error.localizedDescription)")
        }
    }
    
    /// 将本地 UserDefaults 设置保存到云端
    func save(supabaseService: SupabaseService) async {
        guard !AppConfig.useMockServices,
              let userId = supabaseService.currentUser?.id else { return }
        
        var settings: [String: String] = [:]
        for key in storageKeys {
            if let value = UserDefaults.standard.string(forKey: key) {
                settings[key] = value
            }
        }
        
        let payload = SettingsPayload(
            userId: userId.uuidString,
            settings: settings,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        do {
            try await supabaseService.client
                .from("user_settings")
                .upsert(payload, onConflict: "user_id")
                .execute()
            Log.info("用户设置已保存到云端")
        } catch {
            Log.error("用户设置保存失败: \(error.localizedDescription)")
        }
    }
    
    /// 保存所有设置（便捷调用）
    static func syncToCloud(supabaseService: SupabaseService) {
        Task { await shared.save(supabaseService: supabaseService) }
    }
}

/// 辅助类型：可解码任意 JSON 值
struct AnyCodable: Codable {
    var value: Any
    
    init(_ value: Any) { self.value = value }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) { value = string }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict }
        else if let array = try? container.decode([AnyCodable].self) { value = array }
        else { value = "" }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String { try container.encode(string) }
        else if let dict = value as? [String: Any] {
            let wrapped = dict.mapValues { AnyCodable($0) }
            try container.encode(wrapped)
        }
        else { try container.encode("") }
    }
}
