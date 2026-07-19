import Foundation
import Security

// MARK: - Keychain 安全存储
struct KeychainHelper {
    
    // MARK: - 存储
    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        // 先删除旧值
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // 添加新值
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - 读取
    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    // MARK: - 删除
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - 便捷方法：Codable 对象存取
    static func saveCodable<T: Codable>(_ value: T, forKey key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return save(key: key, data: data)
    }
    
    static func loadCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = load(key: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
