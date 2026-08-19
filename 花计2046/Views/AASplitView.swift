import SwiftUI

// MARK: - AA 分账账单列表
struct AASplitView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var bills: [AABill] = []
    @State private var isLoading = false
    @State private var showCreate = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    Color.clear.frame(height: 4)

                    if isLoading && bills.isEmpty {
                        ProgressView()
                            .padding(.top, 80)
                    } else if bills.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2")
                                .font(.system(size: 40))
                                .foregroundColor(AppTheme.textTertiary)
                            Text("暂无共享账单")
                                .font(.appBodyMedium)
                                .foregroundColor(AppTheme.textPrimary)
                            Text("创建一个账单，邀请好友一起记账")
                                .font(.appSmall)
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .padding(.top, 100)
                    } else {
                        ForEach(bills) { bill in
                            NavigationLink(destination: AASplitBillDetailView(bill: bill)
                                .environmentObject(supabaseService)) {
                                HStack(spacing: 14) {
                                    Image(systemName: "list.clipboard")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppTheme.brandStart)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(bill.name)
                                            .font(.appBodyMedium)
                                            .foregroundColor(AppTheme.textPrimary)
                                        if let date = bill.createdAt {
                                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.appSmall)
                                                .foregroundColor(AppTheme.textTertiary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("AA分账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                    }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showCreate) {
                AACreateBillSheet(onCreate: { name in
                    Task {
                        if let bill = try? await supabaseService.createAABill(name: name) {
                            bills.insert(bill, at: 0)
                        }
                        await load()
                    }
                })
                .environmentObject(supabaseService)
            }
        }
    }

    private func load() async {
        isLoading = true
        if let loaded = try? await supabaseService.fetchAABills() {
            bills = loaded
        }
        isLoading = false
    }
}

// MARK: - 新建账单
struct AACreateBillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseService: SupabaseService
    let onCreate: (String) -> Void
    @State private var name = ""

    var body: some View {
        NavigationView {
            Form {
                Section("账单名称") {
                    TextField("如：周末聚餐", text: $name)
                }
            }
            .navigationTitle("新建AA账单")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.brandStart)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed)
                        dismiss()
                    }
                    .foregroundColor(AppTheme.brandStart)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}

// MARK: - 共享账单详情
struct AASplitBillDetailView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    let bill: AABill
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

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Color.clear.frame(height: 4)
                summaryCard
                memberCard
                itemsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle(bill.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
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
                        Button {
                            showAddMember = true
                        } label: {
                            Label("添加成员", systemImage: "person.badge.plus")
                                .font(.appSmall)
                                .foregroundColor(AppTheme.brandStart)
                        }
                        if bill.creatorId == currentUserId {
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
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
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
                    Label("从账本添加", systemImage: "square.and.arrow.down")
                        .font(.appSmall)
                        .foregroundColor(AppTheme.brandStart)
                }
                Button {
                    showAddItem = true
                } label: {
                    Label("手动添加", systemImage: "plus")
                        .font(.appSmall)
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
                            Button(role: .destructive) {
                                pendingDeleteItem = item
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
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
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
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
        async let memberResult = try? supabaseService.fetchAABillMembers(billId: bill.id)
        async let itemResult = try? supabaseService.fetchAABillItems(billId: bill.id)
        let loadedMembers = await memberResult ?? []
        let loadedItems = await itemResult ?? []
        members = loadedMembers
        items = loadedItems
        isLoading = false
    }
}

// MARK: - 添加共享成员
struct AAMemberAddSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    let billId: UUID
    @State private var emailsText = ""
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section("用户账号") {
                    TextField("多个邮箱用逗号或换行分隔", text: $emailsText, axis: .vertical)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .lineLimit(3...6)
                }
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.appSmall)
                            .foregroundColor(Color(hex: "#EF4444"))
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.brandStart)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "添加中..." : "添加") {
                        save()
                    }
                    .foregroundColor(AppTheme.brandStart)
                    .disabled(isSaving || emailsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func save() {
        let emails = emailsText
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains("@") && $0.contains(".") }
        guard !emails.isEmpty else {
            errorMessage = "请输入至少一个有效的邮箱账号"
            return
        }
        isSaving = true
        errorMessage = ""
        Task {
            do {
                _ = try await supabaseService.addAABillMembers(billId: billId, emails: emails)
                await MainActor.run {
                    isSaving = false
                    successMessage = "已添加 \(emails.count) 位成员，对方登录后会看到此账单"
                    emailsText = ""
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.userFriendlyDescription
                }
            }
        }
    }
}

// MARK: - 手动添加/编辑条目
struct AAItemAddSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    let billId: UUID
    var editingItem: AABillItem? = nil
    @State private var name = ""
    @State private var amountText = ""
    @State private var note = ""
    @State private var initialized = false

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
            }
            .navigationTitle(editingItem == nil ? "添加条目" : "编辑条目")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.brandStart)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .foregroundColor(AppTheme.brandStart)
                }
            }
            .onAppear {
                guard let editingItem, !initialized else { return }
                name = editingItem.name
                amountText = String(format: "%.2f", editingItem.amount)
                note = editingItem.note ?? ""
                initialized = true
            }
            .preferredColorScheme(.light)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Double(amountText), amount > 0, !trimmedName.isEmpty else { return }
        guard let userId = supabaseService.currentUser?.id else { return }

        if let editingItem {
            var updated = editingItem
            updated.name = trimmedName
            updated.amount = amount
            updated.note = note.isEmpty ? nil : note
            Task {
                try? await supabaseService.updateAABillItem(updated)
                await MainActor.run { dismiss() }
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
                try? await supabaseService.addAABillItems([item])
                await MainActor.run { dismiss() }
            }
        }
    }
}

// MARK: - 从个人账本选择记录
struct AARecordPickerSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    let billId: UUID
    @State private var selectedIds: Set<UUID> = []

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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.brandStart)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加 \(selectedIds.count) 笔") { addSelected() }
                        .foregroundColor(AppTheme.brandStart)
                        .disabled(selectedIds.isEmpty)
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func addSelected() {
        guard let userId = supabaseService.currentUser?.id else { return }
        let records = supabaseService.allRecords.filter { selectedIds.contains($0.id) }
        let items = records.map { record in
            AABillItem(
                id: UUID(),
                billId: billId,
                userId: userId,
                recordId: record.id,
                name: record.merchant.isEmpty ? record.category : record.merchant,
                category: record.category,
                amount: record.amount,
                note: record.note,
                createdAt: Date()
            )
        }
        Task {
            try? await supabaseService.addAABillItems(items)
            await MainActor.run { dismiss() }
        }
    }
}
