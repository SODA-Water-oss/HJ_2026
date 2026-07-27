import Foundation
import SwiftUI

/// 分类管理器 — 所有类别的唯一数据源
/// 使用 @AppStorage 持久化，所有引用处实时同步
struct CategoryManager {
    // MARK: - 预设分类
    static let defaultExpenseCats = ["餐饮","交通","购物","娱乐","住房","日用","服饰","通讯","医疗","教育","其他"]
    static let defaultIncomeCats  = ["工资","奖金","兼职","投资收益","理财","礼金","退款","其他"]
    
    // MARK: - @AppStorage 键
    @AppStorage("enabled_expense_cats") static var enabledExpenseCats: String = ""
    @AppStorage("enabled_income_cats")  static var enabledIncomeCats: String = ""
    @AppStorage("custom_expense_cats") static var customExpenseCats: String = ""
    @AppStorage("custom_income_cats")  static var customIncomeCats: String = ""
    @AppStorage("default_expense_cat") static var defaultExpenseCat: String = "餐饮"
    @AppStorage("default_income_cat")  static var defaultIncomeCat: String = "工资"
    
    // MARK: - 获取可用分类
    static var expenseCats: [String] {
        ensureInitialized()
        let enabled = parseSet(enabledExpenseCats, defaults: defaultExpenseCats)
        let custom = parseList(customExpenseCats)
        return enabled + custom
    }
    
    static var incomeCats: [String] {
        ensureInitialized()
        let enabled = parseSet(enabledIncomeCats, defaults: defaultIncomeCats)
        let custom = parseList(customIncomeCats)
        return enabled + custom
    }
    
    static func cats(for type: RecordType) -> [String] {
        type == .expense ? expenseCats : incomeCats
    }
    
    static func defaultCat(for type: RecordType) -> String {
        type == .expense ? defaultExpenseCat : defaultIncomeCat
    }
    
    // MARK: - 设置管理
    static func setExpenseCatEnabled(_ cat: String, enabled: Bool) {
        ensureInitialized()
        var current = parseSet(enabledExpenseCats, defaults: defaultExpenseCats)
        if enabled { if !current.contains(cat) { current.append(cat) } }
        else { current.removeAll { $0 == cat } }
        enabledExpenseCats = current.joined(separator: ",")
    }
    
    static func setIncomeCatEnabled(_ cat: String, enabled: Bool) {
        ensureInitialized()
        var current = parseSet(enabledIncomeCats, defaults: defaultIncomeCats)
        if enabled { if !current.contains(cat) { current.append(cat) } }
        else { current.removeAll { $0 == cat } }
        enabledIncomeCats = current.joined(separator: ",")
    }
    static func isExpenseCatEnabled(_ cat: String) -> Bool {
        parseSet(enabledExpenseCats, defaults: defaultExpenseCats).contains(cat)
    }
    
    static func isIncomeCatEnabled(_ cat: String) -> Bool {
        parseSet(enabledIncomeCats, defaults: defaultIncomeCats).contains(cat)
    }
    
    // MARK: - 自定义分类
    static func addCustomExpenseCat(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var current = parseList(customExpenseCats)
        guard !current.contains(trimmed), current.count < 10 else { return }
        current.append(trimmed)
        customExpenseCats = current.joined(separator: ",")
    }
    
    static func addCustomIncomeCat(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var current = parseList(customIncomeCats)
        guard !current.contains(trimmed), current.count < 10 else { return }
        current.append(trimmed)
        customIncomeCats = current.joined(separator: ",")
    }
    
    static func removeCustomExpenseCat(_ name: String) {
        var current = parseList(customExpenseCats)
        current.removeAll { $0 == name }
        customExpenseCats = current.joined(separator: ",")
    }
    
    static func removeCustomIncomeCat(_ name: String) {
        var current = parseList(customIncomeCats)
        current.removeAll { $0 == name }
        customIncomeCats = current.joined(separator: ",")
    }
    
    // MARK: - 辅助
    private static func parseSet(_ raw: String, defaults: [String]) -> [String] {
        if raw.isEmpty { return defaults }
        return raw.components(separatedBy: ",").filter { !$0.isEmpty }
    }
    
    private static func parseList(_ raw: String) -> [String] {
        guard !raw.isEmpty else { return [] }
        return raw.components(separatedBy: ",").filter { !$0.isEmpty }
    }
    
    private static var initialized = false
    private static func ensureInitialized() {
        if !initialized {
            initialized = true
            if enabledExpenseCats.isEmpty { enabledExpenseCats = defaultExpenseCats.joined(separator: ",") }
            if enabledIncomeCats.isEmpty { enabledIncomeCats = defaultIncomeCats.joined(separator: ",") }
        }
    }

    // MARK: - 货币符号
    static var currencySymbol: String {
        UserDefaults.standard.string(forKey: "currency_symbol") ?? "¥"
    }
}
