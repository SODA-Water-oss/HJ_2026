import Foundation
import Supabase

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
        "currency_symbol", "enabled_expense_cats", "enabled_income_cats",
        "custom_expense_cats", "custom_income_cats",
        "default_expense_cat", "default_income_cat",
        "page_lock_ledger_enabled",
        "page_lock_analytics_enabled",
        "ledger_lock_mode",
        "analytics_lock_mode"
    ]
    
    func load(supabaseService: SupabaseService) async {
        guard !AppConfig.useMockServices,
              let userId = supabaseService.currentUser?.id else { return }
        do {
            let result: [[String: AnyCodable]] = try await supabaseService.client
                .from("user_settings").select().eq("user_id", value: userId.uuidString).limit(1).execute().value
            guard let row = result.first, let dict = row["settings"]?.value as? [String: String] else { return }
            for (key, value) in dict {
                    if key == "page_lock_ledger_enabled" || key == "page_lock_analytics_enabled" {
                        UserDefaults.standard.set(value == "true", forKey: key)
                    } else if key != "ledger_pin" && key != "analytics_pin" {
                        UserDefaults.standard.set(value, forKey: key)
                    }
                }
            if let pin = dict["ledger_pin"] { KeychainHelper.saveCodable(pin, forKey: "page_lock_ledger_pin") }
            if let pin = dict["analytics_pin"] { KeychainHelper.saveCodable(pin, forKey: "page_lock_analytics_pin") }
            Log.info("用户设置已从云端加载")
        } catch { Log.info("用户设置加载跳过") }
    }
    
    func save(supabaseService: SupabaseService) async {
        guard !AppConfig.useMockServices,
              let userId = supabaseService.currentUser?.id else { return }
        var settings: [String: String] = [:]
        for key in storageKeys {
            if let value = UserDefaults.standard.string(forKey: key) {
                settings[key] = value
            } else if key == "page_lock_ledger_enabled" || key == "page_lock_analytics_enabled" {
                settings[key] = UserDefaults.standard.bool(forKey: key) ? "true" : "false"
            }
        }
        if let pin: String = KeychainHelper.loadCodable(String.self, forKey: "page_lock_ledger_pin") { settings["ledger_pin"] = pin }
        if let pin: String = KeychainHelper.loadCodable(String.self, forKey: "page_lock_analytics_pin") { settings["analytics_pin"] = pin }
        let payload = SettingsPayload(userId: userId.uuidString, settings: settings, updatedAt: ISO8601DateFormatter().string(from: Date()))
        do {
            try await supabaseService.client.from("user_settings").upsert(payload, onConflict: "user_id").execute()
            Log.info("用户设置已保存到云端")
        } catch { Log.error("用户设置保存失败: \(error.localizedDescription)") }
    }
    
    static func syncToCloud(supabaseService: SupabaseService) {
        Task { await shared.save(supabaseService: supabaseService) }
    }
}

// MARK: - AnyCodable
struct AnyCodable: Codable {
    var value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let d = try? c.decode([String: AnyCodable].self) { value = d.mapValues { $0.value } }
        else if let a = try? c.decode([AnyCodable].self) { value = a.map { $0.value } }
        else { value = "" }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if let s = value as? String { try c.encode(s) }
        else { try c.encode("") }
    }
}
