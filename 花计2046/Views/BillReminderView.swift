import SwiftUI
import UserNotifications

struct NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if !granted {
                print("通知权限未授权")
            }
        }
    }
    
    static func scheduleBillNotification(bill: BillItem) {
        guard let dueDate = bill.nextDueDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = bill.name + " 到期提醒"
        let symbol = bill.currency
        content.body = bill.name + " " + symbol + String(format: "%.2f", bill.amount) + " 即将到期"
        content.sound = .default
        content.badge = 1
        content.userInfo = ["bill_id": bill.id.uuidString]
        
        // 提醒时间（时:分），默认 9:00
        let hour = Calendar.current.component(.hour, from: bill.reminderTime ?? Date())
        let minute = Calendar.current.component(.minute, from: bill.reminderTime ?? Date())
        
        // 一次性提醒：按指定日期 + 提醒时间触发一次
        if bill.recurrence == .once {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: bill.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
            return
        }
        
        // 周期提醒：到期日 + 提醒时间
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: bill.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
        // Also schedule 1 day before at same reminder time
        if let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: dueDate) {
            var earlyComponents = Calendar.current.dateComponents([.year, .month, .day], from: dayBefore)
            earlyComponents.hour = hour
            earlyComponents.minute = minute
            let earlyTrigger = UNCalendarNotificationTrigger(dateMatching: earlyComponents, repeats: false)
            let earlyRequest = UNNotificationRequest(identifier: bill.id.uuidString + "_early", content: content, trigger: earlyTrigger)
            UNUserNotificationCenter.current().add(earlyRequest)
        }
    }
    
    static func cancelBillNotification(billId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [billId, billId + "_early"])
    }
}



struct BillItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: Double
    var dueDay: Int  // 1-31
    var dueMonth: Int = 0  // 0=每月, 1-12=季度首月/每年月份
    var recurrence: Recurrence
    var isEnabled: Bool = true
    var lastNotified: Date?
    var currency: String = "¥"
    var onceDate: Date?  // 一次性提醒的日期
    var reminderTime: Date?  // 提醒时间（时:分，周期/一次性通用）
    var paidPeriodKey: String?  // 周期账单：已付的周期标识
    var paidDate: Date?         // 一次性账单：完成时间
    
    enum Recurrence: String, Codable, CaseIterable {
        case monthly = "每月"
        case quarterly = "每季度"
        case yearly = "每年"
        case once = "一次性"
    }
    
   var nextDueDate: Date? {
       let cal = Calendar.current
       let now = Date()
       let year = cal.component(.year, from: now)
       let month = cal.component(.month, from: now)
       
        // 1. Determine target year and month
        var targetYear: Int
        var targetMonth: Int
        
        if recurrence == .once {
            return onceFullDate
        }
        
        switch recurrence {
        case .once:
            return onceDate
        case .monthly:
            targetYear = year
            targetMonth = month
        case .quarterly:
            var found = false; targetYear = year; targetMonth = month
            for offset in 0..<12 {
                let m = ((month + offset - 1) % 12) + 1
                let y = year + (month + offset - 1) / 12
                if (m - dueMonth) % 3 == 0 {
                    targetYear = y; targetMonth = m; found = true; break
                }
            }
            guard found else { return nil }
        case .yearly:
            let m = dueMonth > 0 ? dueMonth : 1
            if month > m {
                targetYear = year + 1; targetMonth = m
            } else {
                targetYear = year; targetMonth = m
            }
        }
        
        // 2. Cap day to the target month's actual last day
        guard let targetDate = cal.date(from: DateComponents(year: targetYear, month: targetMonth)) else { return nil }
        let maxDay = cal.range(of: .day, in: .month, for: targetDate)?.count ?? 30
        let day = min(dueDay, maxDay)
        return cal.date(from: DateComponents(year: targetYear, month: targetMonth, day: day))
    }
    
    var isDueSoon: Bool {
        guard let due = nextDueDate else { return false }
        let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
        return daysLeft >= 0 && daysLeft <= 3
    }
    
    /// 当前周期标识（周期账单用于判断"本期是否已付"）
    var currentPeriodKey: String {
        let cal = Calendar.current
        let now = Date()
        switch recurrence {
        case .monthly:
            let comp = cal.dateComponents([.year, .month], from: now)
            return String(format: "%04d-%02d", comp.year ?? 0, comp.month ?? 0)
        case .quarterly:
            let comp = cal.dateComponents([.year, .month], from: now)
            let m = comp.month ?? 1
            let quarterStart = ((m - 1) / 3) * 3 + 1
            return String(format: "%04d-%02d", comp.year ?? 0, quarterStart)
        case .yearly:
            return String(cal.component(.year, from: now))
        case .once:
            return ""
        }
    }

    /// 周期账单：本期已标记已付
    var isPaidThisPeriod: Bool {
        recurrence != .once && paidPeriodKey == currentPeriodKey
    }

    /// 一次性账单：已完成
    var isCompleted: Bool {
        recurrence == .once && paidDate != nil
    }

    /// 一次性提醒的完整时间（日期 + 提醒时间）
    var onceFullDate: Date? {
        guard let onceDate else { return nil }
        let cal = Calendar.current
        let dayComp = cal.dateComponents([.year, .month, .day], from: onceDate)
        let hour = reminderTime.map { cal.component(.hour, from: $0) } ?? 9
        let minute = reminderTime.map { cal.component(.minute, from: $0) } ?? 0
        return cal.date(from: DateComponents(year: dayComp.year, month: dayComp.month, day: dayComp.day, hour: hour, minute: minute))
    }

    /// 一次性账单：已过期（完整提醒时间已过且未完成）
    var isExpiredOnce: Bool {
        recurrence == .once && paidDate == nil && onceFullDate != nil && onceFullDate! < Date()
    }

    var isOverdue: Bool {
        guard let due = nextDueDate else { return false }
        return Calendar.current.compare(Date(), to: due, toGranularity: .day) == .orderedDescending
    }
    
    var daysUntilDue: Int {
        guard let due = nextDueDate else { return 999 }
        return Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 999
    }
    
    var dueDateDisplay: String {
        if recurrence == .once {
            if let full = onceFullDate {
                let f = DateFormatter()
                f.locale = Locale(identifier: "zh_CN")
                f.dateFormat = "yyyy年M月d日 HH:mm"
                return f.string(from: full)
            }
            return ""
        }
        switch recurrence {
        case .once: return ""
        case .monthly: return "每月" + String(dueDay) + "日"
        case .quarterly:
            let names = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
            let q = [names[(dueMonth-1)%12], names[(dueMonth+2)%12], names[(dueMonth+5)%12], names[(dueMonth+8)%12]]
            return q.joined(separator: "/") + String(dueDay) + "日"
        case .yearly:
            let m = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
            return m[dueMonth-1] + String(dueDay) + "日"
        }
    }

    /// 提醒模式显示名
    var recurrenceDisplay: String {
        recurrence.rawValue
    }
}

struct BillReminderView: View {
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var bills: [BillItem] = []
    @State private var showAddSheet = false
    @State private var editBill: BillItem?
    
    var sortedBills: [BillItem] {
        bills.filter { $0.isEnabled }.sorted { $0.daysUntilDue < $1.daysUntilDue } +
        bills.filter { !$0.isEnabled }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Color.clear.frame(height: 4)
                
                if bills.isEmpty {
                    emptyState
                }
                
                ForEach(Array(sortedBills.enumerated()), id: \.element.id) { _, bill in
                    billCard(bill: bill)
                }
                
                addBillButton
                
                Spacer(minLength: 24)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.brandStart)
                    Text("账单提醒")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

        }
        .sheet(isPresented: $showAddSheet) {
            BillFormView(onSave: { newBill in
                bills.append(newBill)
                saveBills()
            })
        }
        .sheet(item: $editBill) { bill in
            BillFormView(bill: bill, onSave: { updatedBill in
                if let idx = bills.firstIndex(where: { $0.id == bill.id }) {
                    bills[idx] = updatedBill
                    saveBills()
                }
            }, onDelete: {
                if let idx = bills.firstIndex(where: { $0.id == bill.id }) {
                    bills.remove(at: idx)
                    saveBills()
                    // 同步删除云端数据并取消本地通知，避免切换页面后重新出现
                    let codable = bill.toCodable(userId: supabaseService.currentUser?.id ?? UUID())
                    Task {
                        try? await supabaseService.deleteBillReminder(codable)
                        NotificationManager.cancelBillNotification(billId: bill.id.uuidString)
                    }
                }
            })
        }
        .onAppear {
            loadBills()
        }
    }
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.textTertiary)
            Text("暂无账单提醒")
                .font(.appTitle)
                .foregroundColor(AppTheme.textPrimary)
            Text("点击下方添加提醒账单开始")
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    private var addBillButton: some View {
        Button(action: { showAddSheet = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("添加提醒账单")
                    .font(.appBodyMedium)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .padding(.horizontal, 20)
    }
    
    private func markPaid(_ bill: BillItem) {
        if let idx = bills.firstIndex(where: { $0.id == bill.id }) {
            if bill.recurrence == .once {
                bills[idx].paidDate = Date()
            } else {
                bills[idx].paidPeriodKey = bill.currentPeriodKey
            }
            saveBills()
        }
    }
    
    private func billCard(bill: BillItem) -> some View {
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(bill.isPaidThisPeriod || bill.isCompleted ? Color.green.opacity(0.15) : bill.isExpiredOnce || bill.isOverdue ? Color.red.opacity(0.15) : bill.isDueSoon ? Color.orange.opacity(0.15) : AppTheme.brandStart.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: bill.isPaidThisPeriod || bill.isCompleted ? "checkmark" : bill.isExpiredOnce || bill.isOverdue ? "exclamationmark" : bill.isDueSoon ? "bell.fill" : "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(bill.isPaidThisPeriod || bill.isCompleted ? .green : bill.isExpiredOnce || bill.isOverdue ? .red : bill.isDueSoon ? .orange : AppTheme.brandStart)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bill.name)
                        .font(.appBodyMedium)
                        .foregroundColor(AppTheme.textPrimary)
                        .strikethrough(!bill.isEnabled)
                        Text(bill.currency + String(format: "%.2f", bill.amount))
                            .font(.appBody)
                            .foregroundColor(AppTheme.brandStart)
                        // 提醒模式一行
                        Text(bill.recurrenceDisplay)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        // 年月日时分单独一行
                        Text(bill.dueDateDisplay)
                            .font(.appSmall)
                            .foregroundColor(AppTheme.textTertiary)
                }
                
                Spacer()
                
                // 状态 + 标记已付/完成
                VStack(alignment: .trailing, spacing: 6) {
                    if bill.isPaidThisPeriod {
                        Text("✓ 本期已付")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    } else if bill.isCompleted {
                        Text("✓ 已完成")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    } else if bill.isExpiredOnce {
                        Text("已过期")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                    } else if bill.isEnabled {
                        if bill.isOverdue {
                            Text("本月已过" + String(abs(bill.daysUntilDue)) + "天")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        } else if bill.isDueSoon {
                            Text("剩" + String(bill.daysUntilDue) + "天")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                        } else {
                            Text("剩" + String(bill.daysUntilDue) + "天")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                    
                    // 标记已付/完成按钮
                    if !bill.isPaidThisPeriod && !bill.isCompleted {
                        Button(action: { markPaid(bill) }) {
                            Text(bill.recurrence == .once ? "标记完成" : "标记已付")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.brandStart)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppTheme.brandStart.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minWidth: 44)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture { editBill = bill }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    private func recurrenceToggle(selection: Binding<BillItem.Recurrence>) -> some View {
        return HStack(spacing: 0) {
            ForEach(BillItem.Recurrence.allCases, id: \.self) { freq in
                Button(action: { selection.wrappedValue = freq }) {
                    Text(freq.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selection.wrappedValue == freq ? AnyShapeStyle(Color.white) : AnyShapeStyle(AppTheme.brandGradient))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Group { if selection.wrappedValue == freq { AppTheme.brandGradient } else { AppTheme.background } })
                        .cornerRadius(6)
                }
            }
        }
        .background(AppTheme.background)
        .cornerRadius(8)
        .frame(maxWidth: 240)
    }
    
    private func saveBills() {
        // Local cache for instant load
        if let data = try? JSONEncoder().encode(bills) {
            UserDefaults.standard.set(data, forKey: "bill_reminders_cache")
        }
        Task {
            for bill in bills {
                let codable = bill.toCodable(userId: supabaseService.currentUser?.id ?? UUID())
                if let existing = try? await supabaseService.fetchBillReminders().first(where: { $0.id == bill.id }) {
                    try? await supabaseService.updateBillReminder(codable)
                } else {
                    try? await supabaseService.addBillReminder(codable)
                }
            }
            scheduleNotifications()
        }
    }
    
    private func scheduleNotifications() {
        NotificationManager.requestPermission()
        // Remove all pending notifications for bills
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        for bill in bills where bill.isEnabled && !bill.isPaidThisPeriod && !bill.isCompleted && !bill.isExpiredOnce {
            NotificationManager.scheduleBillNotification(bill: bill)
        }
    }
    
    private func loadBills() {
        // Instant load from local cache
        if let data = UserDefaults.standard.data(forKey: "bill_reminders_cache"),
           let cached = try? JSONDecoder().decode([BillItem].self, from: data) {
            bills = cached
        }
        // Background sync from database
        Task {
            guard let loaded = try? await supabaseService.fetchBillReminders() else { return }
            bills = loaded.map { BillItem(from: $0) }
            // Update cache
            if let data = try? JSONEncoder().encode(bills) {
                UserDefaults.standard.set(data, forKey: "bill_reminders_cache")
            }
        }
    }
}

// MARK: - BillItem <-> BillReminderCodable
extension BillItem {
    init(from codable: BillReminderCodable) {
        self.id = codable.id
        self.name = codable.name
        self.amount = codable.amount
        self.dueDay = codable.dueDay
        self.dueMonth = codable.dueMonth
        self.isEnabled = codable.isEnabled
        self.currency = codable.currency
        self.paidPeriodKey = codable.paidPeriodKey
        if let raw = codable.paidDate {
            self.paidDate = ISO8601DateFormatter().date(from: raw)
        }
        if let raw = codable.reminderTime, let t = Self.parseTime(raw) {
            self.reminderTime = t
        }
        switch codable.recurrence {
        case "monthly": self.recurrence = .monthly
        case "quarterly": self.recurrence = .quarterly
        case "yearly": self.recurrence = .yearly
        case "once":
            self.recurrence = .once
            if let raw = codable.onceDate {
                self.onceDate = ISO8601DateFormatter().date(from: raw)
            }
        default: self.recurrence = .monthly
        }
    }
    
    private static func formatTime(_ date: Date) -> String {
        let cal = Calendar.current
        return String(format: "%02d:%02d", cal.component(.hour, from: date), cal.component(.minute, from: date))
    }
    
    private static func parseTime(_ raw: String) -> Date? {
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, let base = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()) else { return nil }
        return base
    }
    
    func toCodable(userId: UUID) -> BillReminderCodable {
        let dbRec: String = {
            switch recurrence {
            case .monthly: return "monthly"
            case .quarterly: return "quarterly"
            case .yearly: return "yearly"
            case .once: return "once"
            }
        }()
        return BillReminderCodable(
            id: id,
            userId: userId,
            name: name,
            amount: amount,
            dueDay: dueDay,
            dueMonth: recurrence == .monthly ? 0 : dueMonth,
            recurrence: dbRec,
            isEnabled: isEnabled,
            currency: currency,
            onceDate: recurrence == .once ? onceDate.map { ISO8601DateFormatter().string(from: $0) } : nil,
            reminderTime: reminderTime.map { Self.formatTime($0) },
            paidPeriodKey: paidPeriodKey,
            paidDate: paidDate.map { ISO8601DateFormatter().string(from: $0) }
        )
    }
}

// MARK: - 账单添加/编辑表单
struct BillFormView: View {
    @Environment(\.dismiss) var dismiss
    let bill: BillItem?
    let onSave: (BillItem) -> Void
    var onDelete: (() -> Void)? = nil
    
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var dueDay: Int = 1
    @State private var dueMonth: Int = 1
   @State private var recurrence: BillItem.Recurrence = .monthly
    @State private var onceDate: Date = Date().addingTimeInterval(24 * 60 * 60)
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showValidationAlert = false
   @State private var validationMessage = ""
    @State private var showDeleteConfirm = false
    
   private var currentMaxDay: Int {
        switch recurrence {
        case .monthly, .once:
            return 31
        case .quarterly:
            let m = dueMonth > 0 ? dueMonth : 1
            let date = Calendar.current.date(from: DateComponents(year: 2024, month: m))!
            return Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
        case .yearly:
            let m = dueMonth > 0 ? dueMonth : 1
            let date = Calendar.current.date(from: DateComponents(year: 2024, month: m))!
            return Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
        }
    }
    
    init(bill: BillItem? = nil, onSave: @escaping (BillItem) -> Void, onDelete: (() -> Void)? = nil) {
        self.bill = bill
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: bill?.name ?? "")
        _amount = State(initialValue: bill.map { String(format: "%.2f", $0.amount) } ?? "")
        let today = Calendar.current.component(.day, from: Date())
        let thisMonth = Calendar.current.component(.month, from: Date())
        _dueDay = State(initialValue: bill?.dueDay ?? today)
        _dueMonth = State(initialValue: bill?.dueMonth ?? thisMonth)
        _recurrence = State(initialValue: bill?.recurrence ?? .monthly)
        _onceDate = State(initialValue: bill?.onceDate ?? Date().addingTimeInterval(24 * 60 * 60))
        _reminderTime = State(initialValue: bill?.reminderTime ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date())
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 4)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(bill == nil ? "添加提醒账单" : "编辑账单")
                            .font(.appTitle)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        // Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("名称").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            TextField("如：房租、会员费", text: $name)
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textPrimary)
                                .tint(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                                .onChange(of: name) { _, newVal in
                                    if newVal.count > 20 { name = String(newVal.prefix(20)) }
                                }
                        }
                        
                        // Amount
                        VStack(alignment: .leading, spacing: 6) {
                            Text("金额").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            TextField("输入金额", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                                .onChange(of: amount) { newVal in
                                    let filtered = newVal.filter { $0.isNumber || $0 == "." }
                                    let parts = filtered.split(separator: ".", maxSplits: 1)
                                    amount = filtered.filter({ $0 == "." }).count > 1
                                        ? String(parts[0]) + "." + String(parts[safe: 1]?.prefix(2) ?? "")
                                        : filtered.contains(".")
                                        ? String(parts[0]) + "." + String(parts[safe: 1]?.prefix(2) ?? "")
                                        : filtered
                                }
                        }
                        
                        // Recurrence
                        VStack(alignment: .leading, spacing: 6) {
                            Text("周期").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            HStack(spacing: 0) {
                                ForEach(BillItem.Recurrence.allCases, id: \.self) { freq in
                                    Button(action: {
                                        recurrence = freq
                                        if freq != .monthly && dueMonth == 0 { dueMonth = 1 }
                                    }) {
                                        Text(freq.rawValue)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(recurrence == freq ? AnyShapeStyle(Color.white) : AnyShapeStyle(AppTheme.brandGradient))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Group { if recurrence == freq { AppTheme.brandGradient } else { AppTheme.background } })
                                            .cornerRadius(7)
                                    }
                                }
                            }
                            .background(AppTheme.background)
                            .cornerRadius(8)
                    }
                    
                    // 一次性：指定日期 + 时间
                    if recurrence == .once {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("提醒日期").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            DatePicker("日期", selection: $onceDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                            Text("提醒时间").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            DatePicker("时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                            Text("到指定日期时间提醒一次")
                                .font(.appSmall)
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                    
                    // Month grid (季度/年份)
                    if recurrence == .quarterly || recurrence == .yearly {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(recurrence == .quarterly ? "季度起始月" : "月份")
                                .font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                                ForEach(1...12, id: \.self) { m in
                                    Button(action: { dueMonth = m }) {
                                        Text(String(m) + "月")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(dueMonth == m ? AnyShapeStyle(Color.white) : AnyShapeStyle(AppTheme.brandGradient))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Group { if dueMonth == m { AppTheme.brandGradient } else { AppTheme.background } })
                                            .cornerRadius(6)
                                    }
                                }
                            }
                            .id(recurrence)
                            .background(AppTheme.background)
                            .cornerRadius(8)
                        }
                    }
                    
                    // Due day（周期模式）
                    if recurrence != .once {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("到期日").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                        
                        HStack(spacing: 16) {
                            Button(action: { if dueDay > 1 { dueDay -= 1 } }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppTheme.brandGradient)
                            }
                            
                            VStack(spacing: 2) {
                                Text(String(dueDay))
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .frame(minWidth: 60)
                                let dayLabel: String = {
                                    switch recurrence {
                                    case .once: return "一次性"
                                    case .monthly: return "每月" + String(dueDay) + "日"
                                    case .quarterly:
                                        let names = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
                                        let d = max(1, dueMonth)
                                        let q = [names[(d-1)%12], names[(d+2)%12], names[(d+5)%12], names[(d+8)%12]]
                                        return q.joined(separator: "/") + String(dueDay) + "日"
                                    case .yearly:
                                        let names = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
                                        return names[max(0, dueMonth-1)] + String(dueDay) + "日"
                                    }
                                }()
                                Text(dayLabel)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            Button(action: { if dueDay < currentMaxDay { dueDay += 1 } }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppTheme.brandGradient)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        
                    }
                    .onChange(of: dueMonth) { _, _ in
                        if recurrence == .quarterly {
                            if dueDay > currentMaxDay { dueDay = currentMaxDay }
                        } else if recurrence == .yearly {
                            if dueDay > currentMaxDay { dueDay = currentMaxDay }
                        }
                    }
                    .onChange(of: recurrence) { _, newVal in
                        if newVal != .monthly && dueMonth == 0 { dueMonth = 1 }
                        if newVal == .quarterly {
                            if dueDay > currentMaxDay { dueDay = currentMaxDay }
                        } else if newVal == .yearly {
                            if dueDay > currentMaxDay { dueDay = currentMaxDay }
                        }
                    }
                    }

                    // 周期模式：提醒时间（时:分）
                    if recurrence != .once {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("提醒时间").font(.system(size: 17)).foregroundColor(AppTheme.textSecondary)
                            DatePicker("时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(AppTheme.elementRadius)
                        }
                    }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        Button(action: save) {
                            Text("保存")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        
                        Button(action: { dismiss() }) {
                            Text("取消")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        
                        if bill != nil {
                            Button(action: { showDeleteConfirm = true }) {
                                Text("删除提醒")
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                            .confirmationDialog("删除提醒", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                                Button("删除", role: .destructive) {
                                    onDelete?()
                                    dismiss()
                                }
                                Button("取消", role: .cancel) { }
                            } message: {
                                Text("确定要删除该提醒吗？删除后不可恢复。")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 16)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(bill == nil ? "添加提醒账单" : "编辑账单")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .alert("提示", isPresented: $showValidationAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
    }
    
    private func save() {
        let nameTrimmed = name.trimmingCharacters(in: .whitespaces)
        if nameTrimmed.isEmpty {
            validationMessage = "请填写账单名称"
            showValidationAlert = true
            return
        }
        guard let amountVal = Double(amount), amountVal > 0 else {
            validationMessage = "请填写有效金额"
            showValidationAlert = true
            return
        }
        let newBill = BillItem(
            id: bill?.id ?? UUID(),
            name: nameTrimmed,
            amount: amountVal,
            dueDay: dueDay,
            dueMonth: recurrence == .monthly ? 0 : dueMonth,
            recurrence: recurrence,
            isEnabled: bill?.isEnabled ?? true,
            lastNotified: bill?.lastNotified,
            currency: UserDefaults.standard.string(forKey: "currency_symbol") ?? "¥",
            onceDate: recurrence == .once ? onceDate : nil,
            reminderTime: reminderTime
        )
        onSave(newBill)
        dismiss()
    }
}
