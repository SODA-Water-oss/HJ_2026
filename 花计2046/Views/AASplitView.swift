import SwiftUI
import UIKit
import Supabase

fileprivate enum AABillSplitCountStorage {
    private static func key(for billId: UUID) -> String {
        "aa_bill_split_count_\(billId.uuidString)"
    }

    static func load(billId: UUID) -> Int? {
        UserDefaults.standard.object(forKey: key(for: billId)) as? Int
    }

    static func save(billId: UUID, splitCount: Int) {
        UserDefaults.standard.set(splitCount, forKey: key(for: billId))
    }
}

struct AAToolbarButtonLabel: View {
    let title: String
    var color: Color = AppTheme.brandStart

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }
}

struct AAToolbarIconButtonLabel: View {
    let icon: String
    var color: Color = AppTheme.brandStart

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(color)
            .frame(width: 30, height: 30)
    }
}

// MARK: - AA 分账账单列表
struct AASplitView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var bills: [AABill] = AASplitView.initialCachedBills()
    @State private var billSummaries: [UUID: (count: Int, amount: Double)] = [:]
    @State private var activeSheet: AASplitActiveSheet?
    @State private var isPreparingShare = false
    @State private var hasLoadedOnce = false
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var realtimeRefreshTask: Task<Void, Never>?

    private enum AASplitActiveSheet: Identifiable {
        case detail(AABill)
        case share(UIImage)
        case create

        var id: String {
            switch self {
            case .detail(let bill):
                return "detail-\(bill.id.uuidString)"
            case .share:
                return "share"
            case .create:
                return "create"
            }
        }
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 12) {
                    Color.clear.frame(height: 4)

                    if bills.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2")
                                .font(.system(size: 40))
                                .foregroundColor(AppTheme.textTertiary)
                            Text("暂无AA账单")
                                .font(.appTitle)
                                .foregroundColor(AppTheme.textPrimary)
                            Text("点击下方新建AA账单开始")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(40)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
                    } else {
                        ForEach(bills) { bill in
                            ZStack {
                                Button {
                                    activeSheet = .detail(bill)
                                } label: {
                                    Color.clear.contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())

                                HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppTheme.brandStart.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "list.clipboard")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(AppTheme.brandStart)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top) {
                                        Text(bill.name)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(AppTheme.textPrimary)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Button {
                                            Task { await prepareShare(for: bill) }
                                        } label: {
                                            HStack(spacing: 3) {
                                                Image(systemName: "square.and.arrow.up")
                                                    .font(.system(size: 12, weight: .semibold))
                                                Text("分享")
                                                    .font(.system(size: 13, weight: .medium))
                                            }
                                            .foregroundColor(AppTheme.brandStart)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .zIndex(1)
                                    }

                                    billInfoRow(
                                        "均分数",
                                        bill.splitCount.map { "\($0) 份" } ?? "--"
                                    )

                                    if let summary = billSummaries[bill.id] {
                                        billInfoRow("条目数", "\(summary.count) 笔")
                                        HStack {
                                            Text("合计金额")
                                                .font(.system(size: 13))
                                                .foregroundColor(AppTheme.textSecondary)
                                            Spacer()
                                            Text("¥\(String(format: "%.2f", summary.amount))")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(AppTheme.brandStart)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                        HStack {
                                            Text("每份均摊")
                                                .font(.system(size: 13))
                                                .foregroundColor(AppTheme.textSecondary)
                                            Spacer()
                                            Text("¥\(String(format: "%.2f", summary.amount / Double(max(1, bill.splitCount ?? 1))))")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(AppTheme.brandStart)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                    } else {
                                        billInfoRow("条目数", "--")
                                        billInfoRow("合计金额", "--")
                                        billInfoRow("每份均摊", "--")
                                    }

                                    billInfoRow(
                                        "创建日期",
                                        bill.createdAt.map(aaBillDateText) ?? "--"
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                        }
                    }

                    addBillButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("AA分账")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
            .onAppear {
                if !hasLoadedOnce {
                    hasLoadedOnce = true
                    Task { await load() }
                }
            }
            .task {
                await setupRealtime()
            }
            .onDisappear {
                realtimeRefreshTask?.cancel()
                realtimeRefreshTask = nil
                if let realtimeChannel {
                    Task {
                        await supabaseService.client.removeChannel(realtimeChannel)
                    }
                }
                realtimeChannel = nil
            }
            .sheet(item: $activeSheet, onDismiss: {
                Task { await loadSummaries() }
            }) { sheet in
                switch sheet {
                case .detail(let bill):
                    NavigationView {
                        AASplitBillDetailView(bill: bill, onDelete: {
                            bills.removeAll { $0.id == bill.id }
                            saveAACache()
                        }, onLeave: {
                            bills.removeAll { $0.id == bill.id }
                            saveAACache()
                        }, onUpdated: { updatedBill in
                            if let idx = bills.firstIndex(where: { $0.id == updatedBill.id }) {
                                bills[idx] = updatedBill
                                saveAACache()
                            }
                        })
                        .environmentObject(supabaseService)
                    }
                    .preferredColorScheme(.light)
                case .share(let image):
                    ActivityView(activityItems: [image])
                case .create:
                    AACreateBillSheet { bill, splitCount in
                        AABillSplitCountStorage.save(billId: bill.id, splitCount: splitCount)
                        bills.insert(bill, at: 0)
                        saveAACache()
                        Task { await loadSummaries() }
                    }
                    .environmentObject(supabaseService)
                }
            }
    }

    private var addBillButton: some View {
        Button(action: { activeSheet = .create }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("新建AA账单")
                    .font(.appBodyMedium)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .padding(.horizontal, 4)
    }

    private func billInfoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func load() async {
        if bills.isEmpty {
            bills = cachedAABills()
        }
        if let loaded = try? await supabaseService.fetchAABills() {
            bills = loaded
            saveAACache()
        }
        await loadSummaries()
    }

    private func setupRealtime() async {
        guard realtimeChannel == nil else { return }
        let channel = supabaseService.client.channel("aa-bills-realtime")
        let billChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "aa_bills"
        )
        let memberChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "aa_bill_members"
        )
        let itemChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "aa_bill_items"
        )
        do {
            try await channel.subscribeWithError()
            realtimeChannel = channel
            for stream in [billChanges, memberChanges, itemChanges] {
                Task {
                    for await _ in stream {
                        scheduleRealtimeRefresh()
                    }
                }
            }
        } catch {
            Log.warn("AA 实时同步订阅失败: \(error.localizedDescription)")
        }
    }

    private func scheduleRealtimeRefresh() {
        realtimeRefreshTask?.cancel()
        realtimeRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private var billsCacheKey: String {
        guard let userId = supabaseService.currentUser?.id else {
            return "aa_bills_cache_guest"
        }
        return "aa_bills_cache_\(userId.uuidString)"
    }

    private static func initialCachedBills() -> [AABill] {
        let userId = SupabaseService.shared.currentUser?.id
        let key = userId.map { "aa_bills_cache_\($0.uuidString)" } ?? "aa_bills_cache_guest"
        guard let data = UserDefaults.standard.data(forKey: key),
              let bills = try? JSONDecoder().decode([AABill].self, from: data) else {
            return []
        }
        return bills
    }

    private func cachedAABills() -> [AABill] {
        guard let data = UserDefaults.standard.data(forKey: billsCacheKey),
              let bills = try? JSONDecoder().decode([AABill].self, from: data) else {
            return []
        }
        return bills
    }

    private func saveAACache() {
        if let data = try? JSONEncoder().encode(bills) {
            UserDefaults.standard.set(data, forKey: billsCacheKey)
        }
    }

    private func loadSummaries() async {
        billSummaries = (try? await supabaseService.fetchAABillItemSummaries(billIds: bills.map(\.id))) ?? [:]
    }

    @MainActor
    private func prepareShare(for bill: AABill) async {
        isPreparingShare = true
        defer { isPreparingShare = false }

        let items = (try? await supabaseService.fetchAABillItems(billId: bill.id)) ?? []
        let members = (try? await supabaseService.fetchAABillMembers(billId: bill.id)) ?? []
        var ownerNames: [UUID: String] = [:]
        if let user = supabaseService.currentUser {
            ownerNames[user.id] = user.email
        }
        for member in members {
            ownerNames[member.userId] = member.email
        }

        let card = AABillShareCardView(
            bill: bill,
            items: items,
            ownerNames: ownerNames
        )
        .fixedSize()
        .preferredColorScheme(.light)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: nil)
        _ = renderer.uiImage
        guard let rawImage = renderer.uiImage,
              let pngData = rawImage.pngData(),
              let image = UIImage(data: pngData) else { return }
        activeSheet = .share(image)
    }
}

// MARK: - 新建账单
struct AACreateBillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseService: SupabaseService
    let onCreated: (AABill, Int) -> Void
    @State private var name = ""
    @State private var draftItems: [AABillItem] = []
    @State private var memberEmails: [String] = []
    @State private var splitCountText = "1"
    @State private var showItemAdd = false
    @State private var showRecordPicker = false
    @State private var showMemberManage = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var validationMessage = ""
    @State private var showValidationAlert = false
    @FocusState private var isNameFocused: Bool
    @FocusState private var isSplitCountFocused: Bool

    private var totalAmount: Double {
        draftItems.reduce(0) { $0 + $1.amount }
    }

    private var splitCount: Int {
        max(1, Int(splitCountText) ?? 1)
    }

    private var splitAmountText: String {
        "¥\(String(format: "%.2f", totalAmount / Double(splitCount)))"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("账单名称")
                            .font(.appBodyMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        TextField("如：周末聚餐", text: $name)
                            .textFieldStyle(AppTextFieldStyle())
                            .focused($isNameFocused)
                            .onChange(of: name) { _, newValue in
                                if newValue.count > 20 {
                                    name = String(newValue.prefix(20))
                                }
                            }
                        HStack(spacing: 12) {
                            Text("均分数")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            TextField("1", text: $splitCountText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.black)
                                .focused($isSplitCountFocused)
                                .frame(width: 90)
                                .padding(8)
                                .background(AppTheme.background)
                                .cornerRadius(8)
                        }
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.appSmall)
                                .foregroundColor(AppTheme.brandStart)
                        }
                    }
                    .whiteCardContainer()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("账单汇总")
                            .font(.appBodyMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        HStack {
                            Text("条目数")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("\(draftItems.count) 笔")
                                .font(.appBodyMedium)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        HStack {
                            Text("合计")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("¥\(String(format: "%.2f", totalAmount))")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(AppTheme.brandStart)
                        }
                        HStack {
                            Text("每份均摊")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text(splitAmountText)
                                .font(.appBodyMedium)
                                .foregroundColor(AppTheme.brandStart)
                        }
                    }
                    .whiteCardContainer()

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("账单条目")
                                .font(.appBodyMedium)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Button {
                                showRecordPicker = true
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 11))
                                    Text("从账本添加")
                                        .font(.appSmall)
                                }
                                .foregroundColor(AppTheme.brandStart)
                            }
                            Button {
                                showItemAdd = true
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("手动添加")
                                        .font(.appSmall)
                                }
                                .foregroundColor(AppTheme.brandStart)
                            }
                        }

                        if draftItems.isEmpty {
                            Text("暂无账单条目")
                                .font(.appSmall)
                                .foregroundColor(AppTheme.textTertiary)
                                .padding(.vertical, 16)
                        } else {
                            ForEach(draftItems) { item in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name)
                                            .font(.appBodyMedium)
                                            .foregroundColor(AppTheme.textPrimary)
                                        if let category = item.category {
                                            Text(category)
                                                .font(.appSmall)
                                                .foregroundColor(AppTheme.textTertiary)
                                        }
                                    }
                                    Spacer()
                                    Text("¥\(String(format: "%.2f", item.amount))")
                                        .font(.appBodyMedium)
                                        .foregroundColor(AppTheme.textSecondary)
                                    Button {
                                        draftItems.removeAll { $0.id == item.id }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppTheme.brandEnd)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .whiteCardContainer()

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("共享成员")
                                .font(.appBodyMedium)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Button {
                                showMemberManage = true
                            } label: {
                                Label("添加成员", systemImage: "person.badge.plus")
                                    .font(.appSmall)
                                    .foregroundColor(AppTheme.brandStart)
                            }
                        }

                        if memberEmails.isEmpty {
                            Text("暂无共享成员")
                                .font(.appSmall)
                                .foregroundColor(AppTheme.textTertiary)
                                .padding(.vertical, 16)
                        } else {
                            ForEach(memberEmails, id: \.self) { email in
                                HStack(spacing: 10) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 17))
                                        .foregroundColor(AppTheme.brandStart)
                                    Text(email)
                                        .font(.appBody)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Button {
                                        memberEmails.removeAll { $0 == email }
                                    } label: {
                                        Image(systemName: "xmark.circle")
                                            .font(.system(size: 15))
                                            .foregroundColor(AppTheme.textTertiary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(12)
                                .background(AppTheme.background)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .whiteCardContainer()

                    VStack(spacing: 12) {
                        Button(action: save) {
                            Text(isSaving ? "保存中..." : "保存")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(isSaving)

                        Button(action: { dismiss() }) {
                            Text("取消")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("新建AA账单")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        isNameFocused = false
                        isSplitCountFocused = false
                    }
                    .foregroundColor(AppTheme.brandStart)
                }
            }
            .sheet(isPresented: $showItemAdd) {
                AAItemAddSheet(onSaveDraft: { item in
                    if let index = draftItems.firstIndex(where: { $0.id == item.id }) {
                        draftItems[index] = item
                    } else {
                        draftItems.append(item)
                    }
                })
            }
            .sheet(isPresented: $showRecordPicker) {
                AARecordPickerSheet(onAddDraft: { newItems in
                    let existingRecordIds = Set(draftItems.compactMap { $0.recordId })
                    draftItems.append(contentsOf: newItems.filter {
                        guard let recordId = $0.recordId else { return true }
                        return !existingRecordIds.contains(recordId)
                    })
                })
            }
            .sheet(isPresented: $showMemberManage) {
                AAMemberAddSheet { emails in
                    let existing = Set(memberEmails)
                    memberEmails.append(contentsOf: emails.filter { !existing.contains($0) })
                }
            }
            .alert("提示", isPresented: $showValidationAlert) {
                Button("好", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .preferredColorScheme(.light)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "需录入账单名称"
            validationMessage = "需录入账单名称"
            showValidationAlert = true
            return
        }
        guard let splitCount = Int(splitCountText), splitCount > 0 else {
            errorMessage = "请输入有效的均分数"
            validationMessage = "请输入有效的均分数"
            showValidationAlert = true
            return
        }
        isSaving = true
        errorMessage = ""
        Task {
            do {
                let bill = try await supabaseService.createAABill(
                    name: trimmed,
                    items: draftItems,
                    memberEmails: memberEmails,
                    splitCount: splitCount
                )
                await MainActor.run {
                    onCreated(bill, splitCount)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    let detail = error.localizedDescription.lowercased()
                    if detail.contains("duplicate") || detail.contains("already exists") {
                        errorMessage = "账单名称已存在，请更换名称"
                    } else {
                        errorMessage = error.userFriendlyDescription
                    }
                }
            }
        }
    }
}

// MARK: - 共享账单详情
struct AASplitBillDetailView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    let bill: AABill
    var onDelete: (() -> Void)? = nil
    var onLeave: (() -> Void)? = nil
    var onUpdated: ((AABill) -> Void)? = nil
    @State private var members: [AABillMember] = []
    @State private var items: [AABillItem] = []
    @State private var showAddMember = false
    @State private var showAddItem = false
    @State private var showAddFromRecords = false
    @State private var editingItem: AABillItem?
    @State private var pendingDeleteItem: AABillItem?
    @State private var isLoading = false
    @State private var isManagingMembers = false
    @State private var selectedMemberIds: Set<UUID> = []
    @State private var showDeleteConfirm = false
    @State private var showLeaveConfirm = false
    @State private var showSaveConfirm = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var splitCountText = "1"
    @State private var billName = ""
    @State private var loadErrorMessage: String?
    @State private var loadRetryCount = 0
    @FocusState private var isNameFocused: Bool
    @FocusState private var isSplitCountFocused: Bool

    private var currentUserId: UUID? {
        supabaseService.currentUser?.id
    }

    private var memberEmails: [UUID: String] {
        var result: [UUID: String] = [:]
        for member in members {
            result[member.userId] = member.email
        }
        if let user = supabaseService.currentUser {
            result[user.id] = user.email
        }
        return result
    }

    private var totalAmount: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    private var splitCount: Int {
        max(1, Int(splitCountText) ?? 1)
    }

    private var splitAmountText: String {
        "¥\(String(format: "%.2f", totalAmount / Double(splitCount)))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Color.clear.frame(height: 4)
                if let loadErrorMessage {
                    HStack(spacing: 10) {
                        Text("加载失败：\(loadErrorMessage)")
                            .font(.appSmall)
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            Task { await load() }
                        } label: {
                            Text("重试")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.brandStart)
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                }
                if isLoading && items.isEmpty && members.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(AppTheme.brandStart)
                        Text("正在加载账单数据...")
                            .font(.appSmall)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    nameCard
                    summaryCard
                    itemsCard
                    memberCard
                    VStack(spacing: 12) {
                    Button {
                        showSaveConfirm = true
                    } label: {
                        Text(isSaving ? "保存中..." : "保存")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(isSaving)

                    Button {
                        dismiss()
                    } label: {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSecondaryButtonStyle())

                    if bill.creatorId == currentUserId {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Text("删除账单")
                                .font(.appBody)
                                .foregroundColor(AppTheme.brandStart)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                    } else {
                        Button {
                            showLeaveConfirm = true
                        } label: {
                            Text("退出AA分账")
                                .font(.appBody)
                                .foregroundColor(AppTheme.brandStart)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                    }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable {
            await load()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("编辑AA账单")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    isNameFocused = false
                    isSplitCountFocused = false
                }
                .foregroundColor(AppTheme.brandStart)
            }
        }
        .onAppear {
            billName = bill.name
            if let count = bill.splitCount, count > 0 {
                splitCountText = String(count)
            } else if let saved = AABillSplitCountStorage.load(billId: bill.id) {
                splitCountText = String(saved)
            }
        }
        .onChange(of: billName) { _, newValue in
            let limited = String(newValue.prefix(20))
            if limited != newValue {
                billName = limited
            }
        }
        .onChange(of: splitCountText) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            if filtered != newValue {
                splitCountText = filtered
            }
            if let count = Int(filtered), count > 0 {
                AABillSplitCountStorage.save(billId: bill.id, splitCount: count)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAddMember) {
            AAMemberAddSheet(billId: bill.id)
                .environmentObject(supabaseService)
                .onDisappear { Task { await load() } }
        }
        .sheet(isPresented: $showAddItem) {
            AAItemAddSheet(billId: bill.id)
                .environmentObject(supabaseService)
                .onDisappear { Task { await load() } }
        }
        .sheet(isPresented: $showAddFromRecords) {
            AARecordPickerSheet(billId: bill.id)
                .environmentObject(supabaseService)
                .onDisappear { Task { await load() } }
        }
        .sheet(item: $editingItem) { item in
            AAItemAddSheet(billId: bill.id, editingItem: item)
                .environmentObject(supabaseService)
                .onDisappear { Task { await load() } }
        }
        .alert("确认保存", isPresented: $showSaveConfirm) {
            Button("取消", role: .cancel) { }
            Button("保存") {
                saveChanges()
            }
        } message: {
            Text("确认保存本次修改吗？")
        }
        .alert("保存失败", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .alert("删除账单条目", isPresented: Binding(
            get: { pendingDeleteItem != nil },
            set: { if !$0 { pendingDeleteItem = nil } }
        )) {
            Button("取消", role: .cancel) { pendingDeleteItem = nil }
            Button("删除", role: .destructive) {
                if let item = pendingDeleteItem {
                    Task {
                        try? await supabaseService.deleteAABillItem(id: item.id)
                        await load()
                    }
                }
                pendingDeleteItem = nil
            }
        } message: {
            Text("确定删除「\(pendingDeleteItem?.name ?? "")」吗？")
        }
        .alert("删除账单", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                Task {
                    try? await supabaseService.deleteAABill(id: bill.id)
                    await MainActor.run {
                        onDelete?()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("确定删除该账单吗？删除后不可恢复。")
        }
        .alert("退出AA分账", isPresented: $showLeaveConfirm) {
            Button("取消", role: .cancel) { }
            Button("退出", role: .destructive) {
                leaveBill()
            }
        } message: {
            Text("退出后你将不再看到该AA分账，创建人之后仍可重新添加你。")
        }
    }

    private func leaveBill() {
        Task {
            do {
                try await supabaseService.leaveAABill(billId: bill.id)
                await MainActor.run {
                    onLeave?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    saveErrorMessage = error.userFriendlyDescription
                }
            }
        }
    }

    private func saveChanges() {
        let cleanName = billName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            saveErrorMessage = "请输入账单名称"
            return
        }
        guard let splitCount = Int(splitCountText), splitCount > 0 else {
            saveErrorMessage = "请输入有效的均分数"
            return
        }
        isSaving = true
        Task {
            do {
                if cleanName != bill.name || splitCount != (bill.splitCount ?? 1) {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        if cleanName != bill.name {
                            group.addTask {
                                try await self.supabaseService.updateAABillName(id: self.bill.id, name: cleanName)
                            }
                        }
                        if splitCount != (self.bill.splitCount ?? 1) {
                            group.addTask {
                                try await self.supabaseService.updateAABillSplitCount(id: self.bill.id, splitCount: splitCount)
                            }
                        }
                    }
                }
                await MainActor.run {
                    isSaving = false
                    var updatedBill = bill
                    updatedBill.name = cleanName
                    updatedBill.splitCount = splitCount
                    onUpdated?(updatedBill)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveErrorMessage = error.userFriendlyDescription
                }
            }
        }
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("账单名称")
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                TextField(bill.name, text: $billName)
                    .font(.appBodyMedium)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.black)
                    .focused($isNameFocused)
                    .frame(width: 200)
            }
            HStack {
                Text("均分数")
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                TextField("1", text: $splitCountText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.black)
                    .focused($isSplitCountFocused)
                    .frame(width: 90)
                    .padding(8)
                    .background(AppTheme.background)
                    .cornerRadius(8)
            }
        }
        .whiteCardContainer()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("账单汇总")
                .font(.appBodyMedium)
                .foregroundColor(AppTheme.textPrimary)
            HStack {
                Text("条目数")
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("\(items.count) 笔")
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
            }
                        HStack {
                            Text("合计")
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("¥\(String(format: "%.2f", totalAmount))")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(AppTheme.brandStart)
                        }
                        HStack {
                            Text("每份均摊")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text(splitAmountText)
                                .font(.appBodyMedium)
                                .foregroundColor(AppTheme.brandStart)
                        }
                    }
        .whiteCardContainer()
    }

    private var memberCard: some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("共享成员")
                        .font(.appBodyMedium)
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    if isManagingMembers {
                        Button {
                            deleteSelectedMembers()
                        } label: {
                            Text("删除选中 \(selectedMemberIds.count)")
                                .font(.appSmall)
                                .foregroundColor(Color(hex: "#EF4444"))
                        }
                        Button("完成") {
                            isManagingMembers = false
                            selectedMemberIds = []
                        }
                        .font(.appSmall)
                        .foregroundColor(AppTheme.brandStart)
                    } else {
                        if bill.creatorId == currentUserId {
                            Button {
                                showAddMember = true
                            } label: {
                                Label("添加成员", systemImage: "person.badge.plus")
                                    .font(.appSmall)
                                    .foregroundColor(AppTheme.brandStart)
                            }
                            Button {
                                isManagingMembers = true
                                selectedMemberIds = []
                            } label: {
                                Text("管理")
                                    .font(.appSmall)
                                    .foregroundColor(AppTheme.brandStart)
                            }
                        }
                    }
                }

            if members.isEmpty {
                Text("暂无其他成员，添加账号后共享此账单")
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textTertiary)
            } else {
                ForEach(members) { member in
                    HStack(spacing: 10) {
                        if isManagingMembers {
                            Button {
                                if selectedMemberIds.contains(member.id) {
                                    selectedMemberIds.remove(member.id)
                                } else {
                                    selectedMemberIds.insert(member.id)
                                }
                            } label: {
                                Image(systemName: selectedMemberIds.contains(member.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17))
                                    .foregroundColor(selectedMemberIds.contains(member.id) ? AppTheme.brandStart : AppTheme.textTertiary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 17))
                            .foregroundColor(AppTheme.brandStart)
                        Text(member.email)
                            .font(.appBody)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        if bill.creatorId == currentUserId && !isManagingMembers {
                            Button(role: .destructive) {
                                Task {
                                    try? await supabaseService.deleteAABillMember(billId: bill.id, memberId: member.id)
                                    await load()
                                }
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }
                    }
                    .padding(12)
                    .background(AppTheme.background)
                    .cornerRadius(10)
                }
            }
        }
        .whiteCardContainer()
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("账单条目")
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button {
                    showAddFromRecords = true
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 11))
                        Text("从账本添加")
                            .font(.appSmall)
                    }
                    .foregroundColor(AppTheme.brandStart)
                }
                Button {
                    showAddItem = true
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("手动添加")
                            .font(.appSmall)
                    }
                    .foregroundColor(AppTheme.brandStart)
                }
            }

            if items.isEmpty {
                Text("暂无账单条目，可以从个人账本选择记录或手动添加")
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.vertical, 16)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.appBodyMedium)
                                .foregroundColor(AppTheme.textPrimary)
                            Text(ownerLabel(for: item))
                                .font(.appSmall)
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        Spacer()
                        Text("¥\(String(format: "%.2f", item.amount))")
                            .font(.appBodyMedium)
                            .foregroundColor(AppTheme.textSecondary)
                        if canManage(item) {
                            Button {
                                editingItem = item
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.brandStart)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Button {
                                pendingDeleteItem = item
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.brandEnd)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(12)
                    .background(AppTheme.background)
                    .cornerRadius(10)
                }
            }
        }
        .whiteCardContainer()
    }

    private func ownerLabel(for item: AABillItem) -> String {
        if item.userId == currentUserId { return "我添加" }
        return memberEmails[item.userId].map { "\($0) 添加" } ?? "成员添加"
    }

    private func canManage(_ item: AABillItem) -> Bool {
        item.userId == currentUserId || bill.creatorId == currentUserId
    }

    private func deleteSelectedMembers() {
        let ids = Array(selectedMemberIds)
        guard !ids.isEmpty else { return }
        Task {
            for id in ids {
                try? await supabaseService.deleteAABillMember(billId: bill.id, memberId: id)
            }
            await load()
            await MainActor.run {
                isManagingMembers = false
                selectedMemberIds = []
            }
        }
    }

    private func load() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            members = try await supabaseService.fetchAABillMembers(billId: bill.id)
        } catch {
            loadErrorMessage = "成员数据获取失败"
        }
        do {
            items = try await supabaseService.fetchAABillItems(billId: bill.id)
        } catch {
            loadErrorMessage = loadErrorMessage ?? "条目数据获取失败"
        }
        if members.isEmpty && items.isEmpty && loadErrorMessage == nil && loadRetryCount < 2 {
            loadRetryCount += 1
            try? await Task.sleep(nanoseconds: 400_000_000)
            await load()
            return
        }
        loadRetryCount = 0
        isLoading = false
    }
}

fileprivate func aaBillDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy年M月d日"
    return formatter.string(from: date)
}

fileprivate func aaShareTimeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.string(from: date)
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

struct AABillShareCardView: View {
    let bill: AABill
    let items: [AABillItem]
    let ownerNames: [UUID: String]

    private var splitCount: Int {
        max(1, bill.splitCount ?? 1)
    }

    private var totalAmount: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AA 分账")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.brandStart)

            Text(bill.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)

            Text("均分数：\(splitCount) 份")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)

            Text("条目数：\(items.count) 笔")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)

            if let updated = bill.updatedAt {
                Text("更新时间：\(aaShareTimeText(updated))")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textTertiary)
            }

            HStack(spacing: 0) {
                shareStat("总金额", "¥\(String(format: "%.2f", totalAmount))")
                shareStat("每份均摊", "¥\(String(format: "%.2f", totalAmount / Double(splitCount)))")
            }
            .padding(.vertical, 16)
            .background(AppTheme.background)
            .cornerRadius(10)

            Divider()

            if items.isEmpty {
                Text("暂无条目")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(items.prefix(20)) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)
                            Text(ownerLabel(for: item.userId))
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        Spacer()
                        Text("¥\(String(format: "%.2f", item.amount))")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.vertical, 2)
                }

                if items.count > 20 {
                    Text("仅显示前 20 笔 / 共 \(items.count) 笔")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }

            Divider()

            Text("由「花计2046」生成")
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(24)
        .frame(width: 360)
        .background(Color.white)
    }

    private func shareStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.brandStart)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func ownerLabel(for userId: UUID) -> String {
        guard let email = ownerNames[userId] else { return "成员添加" }
        let prefix = email.split(separator: "@").first.map(String.init) ?? email
        if prefix.count > 8 {
            return String(prefix.prefix(6)) + "***"
        }
        return prefix
    }
}

// MARK: - 添加共享成员
struct AAMemberAddSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    var billId: UUID? = nil
    var onSaveEmails: (([String]) -> Void)? = nil
    @State private var accounts: [String] = [""]
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isSaving = false
    @FocusState private var focusedAccountIndex: Int?

    var body: some View {
        NavigationView {
            Form {
                Section("用户账号") {
                    ForEach(Array(accounts.enumerated()), id: \.offset) { index, _ in
                        HStack(spacing: 8) {
                            TextField("输入对方账号邮箱", text: Binding(
                                get: { accounts[index] },
                                set: { accounts[index] = $0 }
                            ))
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedAccountIndex, equals: index)

                            Button {
                                accounts.remove(at: index)
                                if accounts.isEmpty { accounts = [""] }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.brandEnd)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        accounts.append("")
                    } label: {
                        Label("添加一行", systemImage: "plus.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.brandStart)
                    }
                }
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.appSmall)
                            .foregroundColor(AppTheme.brandStart)
                    }
                }
                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .font(.appSmall)
                            .foregroundColor(Color(hex: "#10B981"))
                    }
                }
            }
            .navigationTitle("添加共享成员")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        AAToolbarButtonLabel(title: "取消")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        AAToolbarButtonLabel(title: isSaving ? "添加中..." : "添加")
                    }
                    .disabled(isSaving || accounts.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedAccountIndex = nil
                    }
                    .foregroundColor(AppTheme.brandStart)
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func save() {
        let accounts = accounts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !accounts.isEmpty else {
            errorMessage = "请输入至少一个有效的账号"
            return
        }
        isSaving = true
        errorMessage = ""
        if let onSaveEmails {
            Task {
                do {
                    let missing = try await supabaseService.validateAABillAccounts(accounts)
                    await MainActor.run {
                        isSaving = false
                        if !missing.isEmpty {
                            self.accounts = missing
                            errorMessage = "以上账号暂未注册：\(missing.joined(separator: "、"))"
                            return
                        }
                        onSaveEmails(accounts)
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isSaving = false
                        errorMessage = error.userFriendlyDescription
                    }
                }
            }
            return
        }
        guard let billId else { return }
        Task {
            do {
                let result = try await supabaseService.addAABillMembers(billId: billId, emails: accounts)
                let missing = result.missing ?? []
                await MainActor.run {
                    isSaving = false
                    if !missing.isEmpty {
                        self.accounts = missing
                        errorMessage = "以上账号暂未注册：\(missing.joined(separator: "、"))"
                        if !result.members.isEmpty {
                            successMessage = "已添加 \(result.members.count) 位成员，未注册账号已保留在下方"
                        }
                        return
                    }
                    successMessage = "已添加 \(result.members.count) 位成员，对方登录后会看到此账单"
                    self.accounts = [""]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    let detail = error.localizedDescription
                    if detail.contains("No user") || detail.contains("No users") {
                        errorMessage = "未找到对应账号，请确认对方已注册后再添加"
                    } else {
                        errorMessage = error.userFriendlyDescription
                    }
                }
            }
        }
    }
}

// MARK: - 手动添加/编辑条目
struct AAItemAddSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    var billId: UUID? = nil
    var editingItem: AABillItem? = nil
    var onSaveDraft: ((AABillItem) -> Void)? = nil
    var onDeleteDraft: (() -> Void)? = nil
    @State private var name = ""
    @State private var amountText = ""
    @State private var note = ""
    @State private var initialized = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationView {
            Form {
                Section("名称") {
                    TextField("如：聚餐、打车", text: $name)
                }
                Section("金额") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                }
                Section("备注（可选）") {
                    TextField("备注", text: $note)
                }
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.appSmall)
                            .foregroundColor(Color(hex: "#EF4444"))
                    }
                }
                if editingItem != nil {
                    Section {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Text("删除条目")
                                .foregroundColor(AppTheme.brandEnd)
                        }
                    }
                }
            }
            .navigationTitle(editingItem == nil ? "添加条目" : "编辑条目")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        AAToolbarButtonLabel(title: "取消")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: {
                        AAToolbarButtonLabel(title: "保存")
                    }
                }
            }
            .onAppear {
                guard let editingItem, !initialized else { return }
                name = editingItem.name
                amountText = String(format: "%.2f", editingItem.amount)
                note = editingItem.note ?? ""
                initialized = true
            }
            .alert("删除条目", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text("确定删除「\(editingItem?.name ?? "")」吗？删除后不可恢复。")
            }
            .preferredColorScheme(.light)
        }
    }

    private func deleteItem() {
        if let onDeleteDraft {
            onDeleteDraft()
            dismiss()
            return
        }
        guard let editingItem else { return }
        Task {
            do {
                try await supabaseService.deleteAABillItem(id: editingItem.id)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run { errorMessage = error.userFriendlyDescription }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Double(amountText), amount > 0, !trimmedName.isEmpty else { return }
        guard let userId = supabaseService.currentUser?.id else { return }

        if let onSaveDraft {
            let item = AABillItem(
                id: editingItem?.id ?? UUID(),
                billId: editingItem?.billId ?? UUID(),
                userId: userId,
                recordId: editingItem?.recordId,
                name: trimmedName,
                category: editingItem?.category,
                amount: amount,
                note: note.isEmpty ? nil : note,
                createdAt: editingItem?.createdAt ?? Date()
            )
            onSaveDraft(item)
            dismiss()
            return
        }
        guard let billId else { return }

        if let editingItem {
            var updated = editingItem
            updated.name = trimmedName
            updated.amount = amount
            updated.note = note.isEmpty ? nil : note
            Task {
                do {
                    try await supabaseService.updateAABillItem(updated)
                    await MainActor.run { dismiss() }
                } catch {
                    await MainActor.run { errorMessage = error.userFriendlyDescription }
                }
            }
        } else {
            let item = AABillItem(
                id: UUID(),
                billId: billId,
                userId: userId,
                recordId: nil,
                name: trimmedName,
                category: nil,
                amount: amount,
                note: note.isEmpty ? nil : note,
                createdAt: Date()
            )
            Task {
                do {
                    try await supabaseService.addAABillItems([item])
                    await MainActor.run { dismiss() }
                } catch {
                    await MainActor.run { errorMessage = error.userFriendlyDescription }
                }
            }
        }
    }
}

// MARK: - 从个人账本选择记录
struct AARecordPickerSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    var billId: UUID? = nil
    var onAddDraft: (([AABillItem]) -> Void)? = nil
    @State private var selectedIds: Set<UUID> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            List(supabaseService.allRecords) { record in
                Button {
                    if selectedIds.contains(record.id) {
                        selectedIds.remove(record.id)
                    } else {
                        selectedIds.insert(record.id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.merchant.isEmpty ? "未命名" : record.merchant)
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Text("\(record.category) · \(record.monthDisplay)")
                                .font(.appSmall)
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        Spacer()
                        Text(record.formattedAmount)
                            .font(.appBodyMedium)
                            .foregroundColor(record.isIncome ? Color.green : AppTheme.textSecondary)
                        Image(systemName: selectedIds.contains(record.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(selectedIds.contains(record.id) ? AppTheme.brandStart : AppTheme.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("选择账本记录")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        AAToolbarButtonLabel(title: "取消")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { addSelected() } label: {
                        AAToolbarButtonLabel(title: "添加 \(selectedIds.count) 笔")
                    }
                        .disabled(selectedIds.isEmpty)
                }
            }
            .preferredColorScheme(.light)
            .alert("添加失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func addSelected() {
        guard let userId = supabaseService.currentUser?.id else { return }
        let records = supabaseService.allRecords.filter { selectedIds.contains($0.id) }
        let items = records.map { record in
            AABillItem(
                id: UUID(),
                billId: billId ?? UUID(),
                userId: userId,
                recordId: record.id,
                name: record.merchant.isEmpty ? record.category : record.merchant,
                category: record.category,
                amount: record.amount,
                note: record.note,
                createdAt: Date()
            )
        }
        if let onAddDraft {
            onAddDraft(items)
            dismiss()
            return
        }
        guard let billId else { return }
        Task {
            do {
                try await supabaseService.addAABillItems(items.map { item in
                    var copy = item
                    copy.billId = billId
                    return copy
                })
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run { errorMessage = error.userFriendlyDescription }
            }
        }
    }
}
