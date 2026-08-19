import Foundation
import Combine
import Supabase

struct UserLog: Identifiable, Codable {
    var id: UUID
    var userId: UUID
    var action: String
    var detail: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case action
        case detail
        case createdAt = "created_at"
    }
}

@MainActor
class UserLogManager: ObservableObject {
    static let shared = UserLogManager()
    
    @Published var logs: [UserLog] = []
    @Published var isLoading = false
    
    private init() {}
    
    /// 记录一条操作记录（先写本地缓存，再写入 Supabase，云端长期保留）
    static func log(action: String, detail: String, supabaseService: SupabaseService) async {
        guard let userId = supabaseService.currentUser?.id else { return }
        
        let entry = UserLog(
            id: UUID(),
            userId: userId,
            action: action,
            detail: detail,
            createdAt: Date()
        )
        
        // 先存本地缓存（立即生效，不依赖网络）
        var cached = UserDefaults.standard.loadLogs()
        cached.insert(entry, at: 0)
        cached = cached.filter { $0.createdAt > Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date() }
        if cached.count > 200 { cached = Array(cached.prefix(200)) }
        UserDefaults.standard.saveLogs(cached)
        await MainActor.run { shared.logs = cached }
        
        // 再写云端（网络操作不阻塞本地）
        if !AppConfig.useMockServices {
            do {
                try await supabaseService.client.from("user_logs").insert(entry).execute()
            } catch {
                Log.error("写入操作日志失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 从云端拉取日志
    func fetchLogs(supabaseService: SupabaseService) async {
        guard let userId = supabaseService.currentUser?.id else { return }
        
        // 先加载本地缓存
        let cached = UserDefaults.standard.loadLogs()
        await MainActor.run { self.logs = cached }
        
        guard !AppConfig.useMockServices else { return }
        
        await MainActor.run { self.isLoading = true }
        
        do {
            let response: [UserLog] = try await supabaseService.client
                .from("user_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(500)
                .execute()
                .value
            
            UserDefaults.standard.saveLogs(response)
            await MainActor.run {
                self.logs = response
                self.isLoading = false
            }
        } catch {
            Log.error("获取操作日志失败: \(error.localizedDescription)")
            await MainActor.run { self.isLoading = false }
        }
    }
}

// MARK: - UserDefaults 缓存
extension UserDefaults {
    private static let logsKey = "user_operation_logs"
    
    func saveLogs(_ logs: [UserLog]) {
        if let data = try? JSONEncoder().encode(logs) {
            set(data, forKey: Self.logsKey)
        }
    }
    
    func loadLogs() -> [UserLog] {
        guard let data = data(forKey: Self.logsKey),
              let logs = try? JSONDecoder().decode([UserLog].self, from: data) else {
            return []
        }
        return logs
    }
}
