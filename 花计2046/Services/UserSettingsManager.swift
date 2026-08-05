import Foundation
import Combine
import Supabase

@MainActor
class UserSettingsManager: ObservableObject {
    static let shared = UserSettingsManager()
    
    // Published settings
    @Published var currencySymbol: String {
        didSet { UserDefaults.standard.set(currencySymbol, forKey: "currency_symbol") }
    }
    @Published var ledgerLockEnabled: Bool {
        didSet { UserDefaults.standard.set(ledgerLockEnabled, forKey: "page_lock_ledger_enabled") }
    }
    @Published var analyticsLockEnabled: Bool {
        didSet { UserDefaults.standard.set(analyticsLockEnabled, forKey: "page_lock_analytics_enabled") }
    }
    @Published var ledgerLockMode: String {
        didSet { UserDefaults.standard.set(ledgerLockMode, forKey: "ledger_lock_mode") }
    }
    @Published var analyticsLockMode: String {
        didSet { UserDefaults.standard.set(analyticsLockMode, forKey: "analytics_lock_mode") }
    }
    
    private let settingsKey = "user_settings_cache"
    
    private init() {
        currencySymbol = UserDefaults.standard.string(forKey: "currency_symbol") ?? "¥"
        ledgerLockEnabled = UserDefaults.standard.bool(forKey: "page_lock_ledger_enabled")
        analyticsLockEnabled = UserDefaults.standard.bool(forKey: "page_lock_analytics_enabled")
        ledgerLockMode = UserDefaults.standard.string(forKey: "ledger_lock_mode") ?? "pin"
        analyticsLockMode = UserDefaults.standard.string(forKey: "analytics_lock_mode") ?? "pin"
    }
    
    // MARK: - Keychain PIN access
    func getLedgerPin() -> String? {
        KeychainHelper.loadCodable(String.self, forKey: "page_lock_ledger_pin")
    }
    
    func setLedgerPin(_ pin: String?) {
        if let pin { KeychainHelper.saveCodable(pin, forKey: "page_lock_ledger_pin") }
        else { KeychainHelper.delete(key: "page_lock_ledger_pin") }
    }
    
    func getAnalyticsPin() -> String? {
        KeychainHelper.loadCodable(String.self, forKey: "page_lock_analytics_pin")
    }
    
    func setAnalyticsPin(_ pin: String?) {
        if let pin { KeychainHelper.saveCodable(pin, forKey: "page_lock_analytics_pin") }
        else { KeychainHelper.delete(key: "page_lock_analytics_pin") }
    }
    
    // MARK: - Lock verification
    func verifyLedgerPin(_ pin: String) -> Bool {
        guard let stored = getLedgerPin() else { return false }
        return pin == stored
    }
    
    func verifyAnalyticsPin(_ pin: String) -> Bool {
        guard let stored = getAnalyticsPin() else { return false }
        return pin == stored
    }
    
    // MARK: - Cloud sync
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
    
    func saveToCloud() async {
        guard !AppConfig.useMockServices,
              let userId = SupabaseService.shared.currentUser?.id else { return }
        var settings: [String: String] = [:]
        settings["currency_symbol"] = currencySymbol
        settings["page_lock_ledger_enabled"] = ledgerLockEnabled ? "true" : "false"
        settings["page_lock_analytics_enabled"] = analyticsLockEnabled ? "true" : "false"
        settings["ledger_lock_mode"] = ledgerLockMode
        settings["analytics_lock_mode"] = analyticsLockMode
        if let pin = getLedgerPin() { settings["ledger_pin"] = pin }
        if let pin = getAnalyticsPin() { settings["analytics_pin"] = pin }
        // Category settings
        for key in ["enabled_expense_cats", "enabled_income_cats", "custom_expense_cats", "custom_income_cats", "default_expense_cat", "default_income_cat"] {
            if let value = UserDefaults.standard.string(forKey: key) { settings[key] = value }
        }
        let payload = SettingsPayload(userId: userId.uuidString, settings: settings, updatedAt: ISO8601DateFormatter().string(from: Date()))
        do {
            try await SupabaseService.shared.client.from("user_settings").upsert(payload, onConflict: "user_id").execute()
            Log.info("用户设置已保存到云端")
        } catch {
            Log.error("用户设置保存失败: \(error.localizedDescription)")
        }
    }
    
    func loadFromCloud() async {
        guard !AppConfig.useMockServices,
              let userId = SupabaseService.shared.currentUser?.id else { return }
        do {
            let result: [[String: AnyCodable]] = try await SupabaseService.shared.client
                .from("user_settings").select().eq("user_id", value: userId.uuidString).limit(1).execute().value
            guard let row = result.first, let raw = row["settings"]?.value as? [String: Any] else { return }
            var dict: [String: String] = [:]
            for (k, v) in raw { dict[k] = "\(v)" }
            apply(dict)
        } catch {
            Log.info("用户设置加载跳过")
        }
    }
    
    private func apply(_ dict: [String: String]) {
        if let val = dict["currency_symbol"] { currencySymbol = val }
        if let val = dict["page_lock_ledger_enabled"] { ledgerLockEnabled = val == "true" }
        if let val = dict["page_lock_analytics_enabled"] { analyticsLockEnabled = val == "true" }
        if let val = dict["ledger_lock_mode"] { ledgerLockMode = val }
        if let val = dict["analytics_lock_mode"] { analyticsLockMode = val }
        if let val = dict["ledger_pin"] { setLedgerPin(val) }
        if let val = dict["analytics_pin"] { setAnalyticsPin(val) }
        for key in ["enabled_expense_cats", "enabled_income_cats", "custom_expense_cats", "custom_income_cats", "default_expense_cat", "default_income_cat"] {
            if let val = dict[key] { UserDefaults.standard.set(val, forKey: key) }
        }
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
