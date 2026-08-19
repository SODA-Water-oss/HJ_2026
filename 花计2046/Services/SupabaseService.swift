import Foundation
import Combine
import Supabase

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    @Published var currentUser: MockUser?
    @Published var userProfile: UserProfile?
    @Published var isAuthenticated = false
    @Published var unreadExpenseCount = 0
    @Published var preloadedExpenses: [Expense] = []
    @Published var isPreloaded = false
    @Published var expenses: [Expense] = []
    @Published var incomes: [Record] = []
    @Published var allRecords: [Record] = []
    @Published var isExpensesLoading = false
    @Published var isRecordsLoading = false
    @Published var recordsLoadError = false
    @Published var batchProgress: (Int, Int)? = nil
    @Published var isGloballyProcessing = false
    @Published var globalProcessingMessage = ""
    private var lastFetchTime: Date = .distantPast
   
    private var mockExpenses: [Expense] = []
    private var mockUserId = UUID()
    
    // 按用户邮箱隔离的 UserDefaults 存储 Key
    private var expensesStorageKey: String {
        if let email = currentUser?.email {
            let uidKey = "mock_uid_" + email
            if let uid = UserDefaults.standard.string(forKey: uidKey) {
                return "expenses_\(uid)"
            }
        }
        return "expenses_default"
    }
    
    private init() {
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
        
        if AppConfig.useMockServices {
            Log.info("SupabaseService：Mock模式 - UserDefaults存储")
        } else {
            Log.info("SupabaseService：云端模式 - 已连接 Supabase")
        }
        $batchProgress
            .map { $0 != nil }
            .assign(to: &$isGloballyProcessing)
        $batchProgress
            .compactMap { bp in bp.map { "正在处理 \($0.0)/\($0.1)..." } }
            .assign(to: &$globalProcessingMessage)
    }
    
    // MARK: - Mock User
    struct MockUser {
        let id: UUID
        let email: String
    }

    // MARK: - Token
    func accessToken() async -> String? {
        if AppConfig.useMockServices { return "mock_token" }
        return try? await client.auth.session.accessToken
    }
    
    // MARK: - Auth
    func signIn(email: String, password: String) async throws {
        Log.info("登录 \(email)")
        
        if AppConfig.useMockServices {
            guard !email.isEmpty, !password.isEmpty else {
                throw NSError(domain: "auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "邮箱和密码不能为空"])
            }
            let uidKey = "mock_uid_" + email
            let uid: UUID = {
                if let saved = UserDefaults.standard.string(forKey: uidKey),
                   let u = UUID(uuidString: saved) { return u }
                let u = UUID()
                UserDefaults.standard.set(u.uuidString, forKey: uidKey)
                return u
            }()
            let user = MockUser(id: uid, email: email)
            let profile = UserProfile(id: uid, email: email, createdAt: Date())
            self.currentUser = user
            self.userProfile = profile
            self.isAuthenticated = true
            Log.info("Mock登录成功: \(email)")
            return
        }
        
        let session = try await client.auth.signIn(email: email, password: password)
        let uid = session.user.id
        let profile = UserProfile(id: uid, email: email, createdAt: Date())
        self.currentUser = MockUser(id: uid, email: email)
        self.userProfile = profile
        self.isAuthenticated = true
        Log.info("云端登录成功 userId=\(uid)")
        await fetchProfile()
    }

    /// 从云端 profiles 拉取当前用户资料（含昵称）
    func fetchProfile() async {
        guard !AppConfig.useMockServices, let userId = currentUser?.id else { return }
        do {
            let row: UserProfile = try await client.from("profiles").select()
                .eq("id", value: userId)
                .single()
                .execute().value
            self.userProfile = row
        } catch {
            Log.error("拉取用户资料失败: \(error.localizedDescription)")
        }
    }

    /// 更新用户昵称（写入 profiles.name，并同步到 auth user_metadata）
    func updateProfileName(_ name: String) async throws {
        guard !AppConfig.useMockServices, let userId = currentUser?.id else { return }
        try await client.from("profiles")
            .update(["name": name])
            .eq("id", value: userId)
            .execute()
        try? await client.auth.update(user: UserAttributes(data: ["name": AnyJSON.string(name)]))
        if var profile = self.userProfile {
            profile.name = name
            self.userProfile = profile
        }
    }

    func signUp(email: String, password: String) async throws {
        Log.info("注册 \(email)")
        if AppConfig.useMockServices {
            try await signIn(email: email, password: password)
            return
        }
        let session = try await client.auth.signUp(email: email, password: password)
        let uid = session.user.id
        let profile = UserProfile(id: uid, email: email, createdAt: Date())
        self.currentUser = MockUser(id: uid, email: email)
        self.userProfile = profile
        self.isAuthenticated = true
        Log.info("云端注册成功 userId=\(uid)")
    }

    func signOut() async throws {
        Log.info("登出")
        if !AppConfig.useMockServices { try? await client.auth.signOut() }
        self.currentUser = nil
        self.userProfile = nil
        self.isAuthenticated = false
        self.allRecords = []
        self.expenses = []
        self.incomes = []
        self.preloadedExpenses = []
        self.isPreloaded = false
    }

    // MARK: - Expenses CRUD
    
    func preloadExpenses() async throws {
        guard expenses.isEmpty else { return }
        try? await refreshExpenses()
        Log.info("后台预加载支出数据 count=\(expenses.count)")
    }

    func preloadAllRecords() async throws {
        guard allRecords.isEmpty else { return }
        try? await refreshAllRecords()
        Log.info("后台预加载全部记录 count=\(allRecords.count)")
    }
    
    /// 刷新支出数据（带 3 秒防抖，force=true 跳过防抖）
    func refreshExpenses(force: Bool = false) async {
        let now = Date()
        if !force, now.timeIntervalSince(lastFetchTime) < 3 { return }
        lastFetchTime = now
        isExpensesLoading = true
        do { expenses = try await fetchExpenses() }
        catch { Log.error("刷新支出失败: \(error)") }
        isExpensesLoading = false
    }

    func refreshIncomes(force: Bool = false) async {
        let now = Date()
        if !force, now.timeIntervalSince(lastFetchTime) < 3 { return }
        lastFetchTime = now
        do { incomes = try await fetchIncomes() }
        catch { Log.error("刷新收入失败: \(error)") }
    }

    func refreshAllRecords(force: Bool = false) async {
        let now = Date()
        if !force, now.timeIntervalSince(lastFetchTime) < 3 { return }
        lastFetchTime = now
        isRecordsLoading = true
        recordsLoadError = false
        do {
            let records = try await fetchAllRecords()
            allRecords = records
            expenses = records.filter { $0.isExpense }
            incomes = records.filter { $0.isIncome }
        } catch {
            recordsLoadError = true
            Log.error("刷新全部记录失败: \(error)")
        }
        isRecordsLoading = false
    }


    func fetchExpenses() async throws -> [Expense] {
        if AppConfig.useMockServices {
            guard let user = currentUser else { return [] }
            if mockExpenses.isEmpty { loadExpensesFromDefaults() }
            return mockExpenses.filter { $0.userId == user.id && $0.type == .expense }.sorted { $0.date > $1.date }
        }
        
        guard let userId = currentUser?.id else { return [] }
        let rows: [Expense] = try await client
            .from("records").select().eq("type", value: "expense")
            .eq("user_id", value: userId)
            .order("date", ascending: false)
            .execute().value
        Log.info("云端查询支出 count=\(rows.count)")
        return rows
    }

    func fetchIncomes() async throws -> [Record] {
        if AppConfig.useMockServices {
            guard let user = currentUser else { return [] }
            if mockExpenses.isEmpty { loadExpensesFromDefaults() }
            return mockExpenses.filter { $0.userId == user.id && $0.type == .income }.sorted { $0.date > $1.date }
        }

        guard let userId = currentUser?.id else { return [] }
        let rows: [Record] = try await client
            .from("records").select().eq("type", value: "income")
            .eq("user_id", value: userId)
            .order("date", ascending: false)
            .execute().value
        Log.info("云端查询收入 count=\(rows.count)")
        return rows
    }

    func fetchAllRecords() async throws -> [Record] {
        if AppConfig.useMockServices {
            guard let user = currentUser else { return [] }
            if mockExpenses.isEmpty { loadExpensesFromDefaults() }
            return mockExpenses.filter { $0.userId == user.id }.sorted { $0.date > $1.date }
        }

        guard let userId = currentUser?.id else { return [] }
        let rows: [Record] = try await client
            .from("records").select()
            .eq("user_id", value: userId)
            .order("date", ascending: false)
            .execute().value
        Log.info("云端查询全部记录 count=\(rows.count)")
        return rows
    }

    
   func addExpense(_ expense: Expense) async throws {
       Log.info("添加支出 amount=\(expense.amount)")
       
       if AppConfig.useMockServices {
           var newExpense = expense
           newExpense.userId = currentUser?.id ?? mockUserId
           mockExpenses.append(newExpense)
           saveExpensesToDefaults()
            // 同步到 allRecords / incomes
            allRecords.append(newExpense)
            allRecords.sort { $0.date > $1.date }
            if newExpense.isIncome { incomes.append(newExpense); incomes.sort { $0.date > $1.date } }
           unreadExpenseCount += 1
           return
       }
       
      var cloudExp = expense
      cloudExp.userId = currentUser?.id ?? cloudExp.userId
       try await client.from("records").insert(cloudExp).execute()
      var updated = self.expenses
       updated.append(expense)
       updated.sort { $0.date > $1.date }
       self.expenses = updated
        // 同步到 allRecords / incomes
        allRecords.append(expense)
        allRecords.sort { $0.date > $1.date }
        if expense.isIncome { incomes.append(expense); incomes.sort { $0.date > $1.date } }
       unreadExpenseCount += 1
       Log.info("云端添加成功")
   }
   
   /// 批量插入多条记录：一次网络请求 + 一次性本地更新（性能优化）
   func batchAddExpenses(_ newExpenses: [Expense]) async throws {
       guard !newExpenses.isEmpty else { return }
       Log.info("批量添加支出 count=\(newExpenses.count)")
       
       if AppConfig.useMockServices {
           var added = newExpenses
           for i in added.indices { added[i].userId = currentUser?.id ?? added[i].userId }
           mockExpenses.append(contentsOf: added)
           saveExpensesToDefaults()
           allRecords.append(contentsOf: added)
           allRecords.sort { $0.date > $1.date }
           for e in added {
               if e.isIncome { incomes.append(e) } else { self.expenses.append(e) }
           }
           self.expenses.sort { $0.date > $1.date }
           incomes.sort { $0.date > $1.date }
           unreadExpenseCount += added.filter(\.isExpense).count
           return
       }
       
       // 云端一次性批量插入
       var cloud = newExpenses
       for i in cloud.indices { cloud[i].userId = currentUser?.id ?? cloud[i].userId }
       try await client.from("records").insert(cloud).execute()
       
       // 本地一次性更新（只触发一次 UI 刷新）
       var updatedAll = allRecords
       updatedAll.append(contentsOf: newExpenses)
       updatedAll.sort { $0.date > $1.date }
       allRecords = updatedAll
       
       let addedIncomes = newExpenses.filter(\.isIncome)
       let addedExpenses = newExpenses.filter(\.isExpense)
       incomes.append(contentsOf: addedIncomes)
       incomes.sort { $0.date > $1.date }
       self.expenses.append(contentsOf: addedExpenses)
       self.expenses.sort { $0.date > $1.date }
       unreadExpenseCount += addedExpenses.count
       Log.info("云端批量添加成功 count=\(newExpenses.count)")
   }

   func updateExpense(_ expense: Expense) async throws {
       Log.info("更新支出 id=\(expense.id)")
       
       if AppConfig.useMockServices {
           if let index = mockExpenses.firstIndex(where: { $0.id == expense.id }) {
               mockExpenses[index] = expense
               saveExpensesToDefaults()
           }
           // 同步到 allRecords / expenses / incomes
           if let idx = allRecords.firstIndex(where: { $0.id == expense.id }) { var recs = allRecords; recs[idx] = expense; allRecords = recs }
            expenses.removeAll { $0.id == expense.id }
            incomes.removeAll { $0.id == expense.id }
            if expense.type == .expense { expenses.append(expense) } else { incomes.append(expense) }
          return
      }
      
      try await client.from("records").update(expense).eq("id", value: expense.id).execute()
       // 本地同步
       if let idx = allRecords.firstIndex(where: { $0.id == expense.id }) { var recs = allRecords; recs[idx] = expense; allRecords = recs }
        expenses.removeAll { $0.id == expense.id }
        incomes.removeAll { $0.id == expense.id }
        if expense.type == .expense { expenses.append(expense) } else { incomes.append(expense) }
      Log.info("云端更新成功")
  }
   
  func deleteExpense(_ expense: Expense) async throws {
       Log.info("删除支出 id=\(expense.id)")
       
       if AppConfig.useMockServices {
           mockExpenses.removeAll { $0.id == expense.id }
           saveExpensesToDefaults()
           // 同步到 allRecords / incomes
           allRecords.removeAll { $0.id == expense.id }
           incomes.removeAll { $0.id == expense.id }
            expenses.removeAll { $0.id == expense.id }
          unreadExpenseCount += 1
          return
       }
       
       try await client.from("records").delete().eq("id", value: expense.id).execute()
       self.expenses.removeAll { $0.id == expense.id }
        allRecords.removeAll { $0.id == expense.id }
        incomes.removeAll { $0.id == expense.id }
       Log.info("云端删除成功")
   }

    // MARK: - UserDefaults 持久化（替代文件存储）
    
    func loadExpensesFromDefaults() {
        guard AppConfig.useMockServices else { return }
        let key = expensesStorageKey
        guard let data = UserDefaults.standard.data(forKey: key),
              let loaded = try? JSONDecoder().decode([Expense].self, from: data) else {
            Log.info("无缓存数据 key=\(key)（首次使用正常）")
            return
        }
        mockExpenses = loaded
        Log.info("数据已加载 key=\(key) count=\(mockExpenses.count)")
    }
    
    private func saveExpensesToDefaults() {
        guard AppConfig.useMockServices else { return }
        let key = expensesStorageKey
        guard let data = try? JSONEncoder().encode(mockExpenses) else {
            Log.error("编码失败")
            return
        }
        UserDefaults.standard.set(data, forKey: key)
        Log.info("数据已保存 key=\(key) count=\(mockExpenses.count)")
    }
    
    func batchUpdateNote(expenses: [Expense], note: String, mode: NoteMode) async throws {
        let total = expenses.count; var completed = 0; batchProgress = (0, total)
        defer { batchProgress = nil }
        let chunks = stride(from: 0, to: total, by: 8).map { Array(expenses[$0..<min($0 + 8, total)]) }
        for chunk in chunks {
            await withTaskGroup(of: Void.self) { group in
                for expense in chunk {
                    group.addTask {
                        var updated = expense
                        switch mode {
                        case .append:
                            if let existing = updated.note, !existing.isEmpty {
                                updated.note = existing + " " + note
                            } else {
                                updated.note = note
                            }
                        case .replace:
                            updated.note = note.isEmpty ? nil : note
                        }
                        do {
                        try await self.updateExpense(updated)
                        } catch { Log.warn("批量改备注单条失败: \(error.localizedDescription)") }
                    }
                }
                for await _ in group {
                    completed += 1; batchProgress = (completed, total)
                }
            }
        }
        // 本地同步
        let noteIds = Set(expenses.map { $0.id })
        for i in self.expenses.indices {
            guard noteIds.contains(self.expenses[i].id) else { continue }
            switch mode {
            case .append:
                if let existing = self.expenses[i].note, !existing.isEmpty {
                    self.expenses[i].note = existing + " " + note
                } else { self.expenses[i].note = note }
            case .replace:
                self.expenses[i].note = note.isEmpty ? nil : note
            }
        }
    }

   func batchDeleteExpenses(ids: [UUID]) async throws {
       Log.info("批量删除 \(ids.count) 条支出")
       let total = ids.count; var completed = 0; batchProgress = (0, total)
       defer { batchProgress = nil }
      if AppConfig.useMockServices {
      mockExpenses.removeAll { ids.contains($0.id) }
      saveExpensesToDefaults()
        let idSet = Set(ids)
        allRecords = allRecords.filter { !idSet.contains($0.id) }
        incomes = incomes.filter { !idSet.contains($0.id) }
        expenses = expenses.filter { !idSet.contains($0.id) }
      return
      }
       let chunks = stride(from: 0, to: total, by: 8).map { Array(ids[$0..<min($0 + 8, total)]) }
       for chunk in chunks {
           await withTaskGroup(of: Void.self) { group in
               for id in chunk {
                   group.addTask {
                       do {
                       try await self.client.from("records").delete().eq("id", value: id).execute()
                       } catch { Log.warn("批量删除单条失败: \(error.localizedDescription)") }
                   }
               }
               for await _ in group {
                   completed += 1; batchProgress = (completed, total)
               }
           }
       }
     let delIds = Set(ids)
     self.expenses = self.expenses.filter { !delIds.contains($0.id) }
       allRecords = allRecords.filter { !delIds.contains($0.id) }
       incomes = incomes.filter { !delIds.contains($0.id) }
        // 兜底：通知所有视图刷新
        NotificationCenter.default.post(name: Notification.Name("RecordsDidUpdate"), object: nil)
     }

    func batchUpdateTime(expenses: [Expense], date: Date) async throws {
        let total = expenses.count; var completed = 0; batchProgress = (0, total)
        defer { batchProgress = nil }
        let chunks = stride(from: 0, to: total, by: 8).map { Array(expenses[$0..<min($0 + 8, total)]) }
        for chunk in chunks {
            await withTaskGroup(of: Void.self) { group in
                for expense in chunk {
                    group.addTask {
                        var updated = expense
                        updated.date = date
                            do {
                            try await self.updateExpense(updated)
                            } catch { Log.warn("批量改时间单条失败: \(error.localizedDescription)") }
                    }
                }
                for await _ in group {
                    completed += 1; batchProgress = (completed, total)
                }
            }
        }
        let mIds = Set(expenses.map { $0.id })
        for i in self.expenses.indices {
            guard mIds.contains(self.expenses[i].id) else { continue }
            self.expenses[i].date = date
        }
    }


    func batchUpdateCategory(expenses: [Expense], category: String) async throws {
        let total = expenses.count; var completed = 0; batchProgress = (0, total)
        defer { batchProgress = nil }
        let chunks = stride(from: 0, to: total, by: 8).map { Array(expenses[$0..<min($0 + 8, total)]) }
        for chunk in chunks {
            await withTaskGroup(of: Void.self) { group in
                for expense in chunk {
                    group.addTask {
                        var updated = expense
                        updated.category = category
                        do {
                        try await self.updateExpense(updated)
                        } catch { Log.warn("批量改类别单条失败: \(error.localizedDescription)") }
                    }
                }
                for await _ in group {
                    completed += 1; batchProgress = (completed, total)
                }
            }
        }
        let cIds = Set(expenses.map { $0.id })
        for i in self.expenses.indices {
            guard cIds.contains(self.expenses[i].id) else { continue }
            self.expenses[i].category = category
        }
    }

    func batchUpdateCurrency(expenses: [Expense], currencySymbol: String) async throws {
        let total = expenses.count; var completed = 0; batchProgress = (0, total)
        defer { batchProgress = nil }
        let chunks = stride(from: 0, to: total, by: 8).map { Array(expenses[$0..<min($0 + 8, total)]) }
        for chunk in chunks {
            await withTaskGroup(of: Void.self) { group in
                for expense in chunk {
                    group.addTask {
                        var updated = expense
                        updated.currency = currencySymbol
                        do { try await self.updateExpense(updated) }
                        catch { Log.warn("批量改货币单条失败: \(error.localizedDescription)") }
                    }
                }
                for await _ in group { completed += 1; batchProgress = (completed, total) }
            }
        }
        let cIds = Set(expenses.map { $0.id })
        for i in self.expenses.indices {
            guard cIds.contains(self.expenses[i].id) else { continue }
            self.expenses[i].currency = currencySymbol
        }
    }
}

// MARK: - 定期账单提醒
struct BillReminderCodable: Codable, Identifiable {
    var id: UUID
    var userId: UUID
    var name: String
    var amount: Double
    var dueDay: Int
    var dueMonth: Int
    var recurrence: String
    var isEnabled: Bool
    var currency: String
    var onceDate: String?
    var reminderTime: String?
    var paidPeriodKey: String?
    var paidDate: String?
    var createdAt: String?
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case amount
        case dueDay = "due_day"
        case dueMonth = "due_month"
        case recurrence
        case isEnabled = "is_enabled"
        case currency
        case onceDate = "once_date"
        case reminderTime = "reminder_time"
        case paidPeriodKey = "paid_period_key"
        case paidDate = "paid_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension SupabaseService {
    func fetchBillReminders() async throws -> [BillReminderCodable] {
        if AppConfig.useMockServices {
            guard let user = currentUser else { return [] }
            let key = "bill_reminders_\(user.id.uuidString)"
            guard let data = UserDefaults.standard.data(forKey: key),
                  let items = try? JSONDecoder().decode([BillReminderCodable].self, from: data) else {
                return []
            }
            return items
        }
        guard let userId = currentUser?.id else { return [] }
        return try await client.from("bill_reminders").select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: true)
            .execute().value
    }
    
    func addBillReminder(_ reminder: BillReminderCodable) async throws {
        if AppConfig.useMockServices {
            var items = try await fetchBillReminders()
            items.append(reminder)
            let key = "bill_reminders_\(currentUser!.id.uuidString)"
            if let data = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(data, forKey: key)
            }
            return
        }
        try await client.from("bill_reminders").insert(reminder).execute()
    }
    
    func updateBillReminder(_ reminder: BillReminderCodable) async throws {
        if AppConfig.useMockServices {
            var items = try await fetchBillReminders()
            if let idx = items.firstIndex(where: { $0.id == reminder.id }) {
                items[idx] = reminder
            }
            let key = "bill_reminders_\(currentUser!.id.uuidString)"
            if let data = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(data, forKey: key)
            }
            return
        }
        try await client.from("bill_reminders").update(reminder).eq("id", value: reminder.id).execute()
    }
    
    func deleteBillReminder(_ reminder: BillReminderCodable) async throws {
        if AppConfig.useMockServices {
            var items = try await fetchBillReminders()
            items.removeAll { $0.id == reminder.id }
            let key = "bill_reminders_\(currentUser!.id.uuidString)"
            if let data = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(data, forKey: key)
            }
            return
        }
        try await client.from("bill_reminders").delete().eq("id", value: reminder.id).execute()
    }
}

// MARK: - 收支目标（云端长期存储，跨设备同步）
struct GoalTargetCodable: Codable, Identifiable {
    var id: UUID
    var userId: UUID
    var name: String
    var category: String
    var timeDimension: String
    var amount: Double
    var comparison: String?
    var startDate: String?
    var endDate: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case category
        case timeDimension = "time_dimension"
        case amount
        case comparison
        case startDate = "start_date"
        case endDate = "end_date"
        case createdAt = "created_at"
    }
}

extension SupabaseService {
    func fetchGoalTargets() async throws -> [GoalTargetCodable] {
        if AppConfig.useMockServices {
            guard let user = currentUser else { return [] }
            let key = "goal_targets_\(user.id.uuidString)"
            guard let data = UserDefaults.standard.data(forKey: key),
                  let items = try? JSONDecoder().decode([GoalTargetCodable].self, from: data) else {
                return []
            }
            return items
        }
        guard let userId = currentUser?.id else { return [] }
        return try await client.from("goal_targets").select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: true)
            .execute().value
    }

    func addGoalTarget(_ item: GoalTargetCodable) async throws {
        if AppConfig.useMockServices {
            var items = try await fetchGoalTargets()
            items.append(item)
            let key = "goal_targets_\(currentUser!.id.uuidString)"
            if let data = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(data, forKey: key)
            }
            return
        }
        try await client.from("goal_targets").insert(item).execute()
    }

    func deleteGoalTarget(id: UUID) async throws {
        if AppConfig.useMockServices {
            var items = try await fetchGoalTargets()
            items.removeAll { $0.id == id }
            let key = "goal_targets_\(currentUser!.id.uuidString)"
            if let data = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(data, forKey: key)
            }
            return
        }
        try await client.from("goal_targets").delete().eq("id", value: id).execute()
    }
}

// MARK: - GoalTargetItem <-> GoalTargetCodable
extension GoalTargetItem {
    init(from codable: GoalTargetCodable) {
        self.id = codable.id
        self.name = codable.name
        self.category = codable.category
        self.timeDimension = codable.timeDimension
        self.amount = codable.amount
        self.comparison = codable.comparison ?? "大于等于"
        if let raw = codable.startDate { self.startDate = ISO8601DateFormatter().date(from: raw) }
        if let raw = codable.endDate { self.endDate = ISO8601DateFormatter().date(from: raw) }
        if let raw = codable.createdAt { self.createdAt = ISO8601DateFormatter().date(from: raw) }
    }

    func toCodable(userId: UUID) -> GoalTargetCodable {
        GoalTargetCodable(
            id: id,
            userId: userId,
            name: name,
            category: category,
            timeDimension: timeDimension,
            amount: amount,
            comparison: comparison ?? "大于等于",
            startDate: startDate.map { ISO8601DateFormatter().string(from: $0) },
            endDate: endDate.map { ISO8601DateFormatter().string(from: $0) },
            createdAt: nil  // 让数据库默认 now()
        )
    }
}

enum NoteMode { case append, replace }
