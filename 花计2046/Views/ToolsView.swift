import SwiftUI
import UniformTypeIdentifiers


struct ToolItem: Identifiable, Equatable {
    let id: String  // 稳定 ID，不随视图重建变化（避免排序丢失）
    let icon: String
    let title: String
    let desc: String
    let isActive: Bool
    var status: String
}

struct ToolsView: View {
    @AppStorage("tool_order") private var toolOrderRaw: String = ""
    @State private var tools: [ToolItem] = []
    @State private var draggedItem: ToolItem?
    /// 用户本地刚改过的排序（防止云端旧数据回写覆盖）
    @State private var lastLocalOrder: String = ""
    
    private let allTools: [ToolItem] = [
        ToolItem(id: "interest_calculator", icon: "dollarsign.circle", title: "利息计算器", desc: "计算贷款利息、存款利息、年化收益率", isActive: true, status: "使用"),
        ToolItem(id: "bill_reminder", icon: "calendar.badge.clock", title: "定期账单提醒", desc: "房租、会员费、月供到期提醒，不再忘缴", isActive: true, status: "使用"),
        ToolItem(id: "exchange_rate", icon: "arrow.left.arrow.right", title: "汇率换算", desc: "多币种实时汇率换算，出差旅行好帮手", isActive: true, status: "使用"),
        ToolItem(id: "aa_split", icon: "person.2", title: "AA分账", desc: "平均或自定义分摊，自动计算每人应付与差额", isActive: true, status: "使用"),
        ToolItem(id: "expense_analysis", icon: "chart.pie", title: "支出占比分析", desc: "按类别查看各月支出分布与趋势", isActive: false, status: "即将上线"),
        ToolItem(id: "discount_calculator", icon: "percent", title: "折扣计算器", desc: "输入原价和折扣，自动算出折后价和节省金额", isActive: false, status: "即将上线"),
    ]
    
    private var orderedTools: [ToolItem] {
        if toolOrderRaw.isEmpty { return allTools }
        let ids = toolOrderRaw.components(separatedBy: ",")
        var result: [ToolItem] = []
        for idStr in ids {
            if let tool = allTools.first(where: { $0.id == idStr }) {
                result.append(tool)
            }
        }
        for tool in allTools where !result.contains(where: { $0.id == tool.id }) {
            result.append(tool)
        }
        return result
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 4)
                    
                    // MARK: - 待开发工具列表
                    // MARK: - 工具列表（拖拽排序）
                    ForEach(tools) { tool in
                        toolCardContent(tool: tool)
                    }
                    .animation(.easeInOut(duration: 0.2), value: tools)
                }
                .task {
                    // 先显示本地排序，避免等待云端；task 挂在外层 VStack 确保触发
                    if tools.isEmpty { tools = orderedTools }
                    // 后台从云端拉取排序（跨设备），拉取后刷新
                    await UserSettingsManager.shared.loadFromCloud()
                    // 拉取期间用户已改过排序 → 保持本地新顺序，不被云端旧数据覆盖
                    if !lastLocalOrder.isEmpty {
                        UserDefaults.standard.set(lastLocalOrder, forKey: "tool_order")
                    }
                    tools = orderedTools
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("工具")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }

            }
        }
    }
    
    
    @ViewBuilder
    private func toolCardContent(tool: ToolItem) -> some View {
        HStack(spacing: 0) {
            toolCard(icon: tool.icon, title: tool.title, desc: tool.desc, status: tool.status, isActive: tool.isActive)
                .overlay(
                    Group {
                        if tool.isActive {
                            if tool.title == "利息计算器" {
                                NavigationLink(destination: InterestCalculatorView()) { Color.clear }
                            } else if tool.title == "汇率换算" {
                                NavigationLink(destination: ExchangeRateCalculatorView()) { Color.clear }
                            } else if tool.title == "定期账单提醒" {
                                NavigationLink(destination: BillReminderView()) { Color.clear }
                            } else if tool.title == "AA分账" {
                                NavigationLink(destination: AASplitView()) { Color.clear }
                            }
                        }
                    }
                )
        }
        .onDrag {
            draggedItem = tool
            return NSItemProvider(object: tool.id as NSString)
        }
        .onDrop(of: [UTType.text], delegate: ToolDropDelegate(
            item: tool,
            items: $tools,
            draggedItem: $draggedItem,
            onReorder: { saveOrder($0) }
        ))
    }
    
    private func saveOrder(_ tools: [ToolItem]) {
        let order = tools.map { $0.id }.joined(separator: ",")
        toolOrderRaw = order
        lastLocalOrder = order
        // 云端同步（跨设备）
        Task { await UserSettingsManager.shared.saveToCloud() }
    }
    
    private func toolCard(icon: String, title: String, desc: String, status: String, isActive: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppTheme.brandStart)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Text(desc)
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
                    .frame(width: 28)
            } else {
                Text(status)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.background)
                    .cornerRadius(6)
                    .frame(width: 56)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
}

/// 工具卡片拖拽排序的 DropDelegate
struct ToolDropDelegate: DropDelegate {
    let item: ToolItem
    @Binding var items: [ToolItem]
    @Binding var draggedItem: ToolItem?
    var onReorder: ([ToolItem]) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedItem, draggedItem != item else { return }
        if let from = items.firstIndex(of: draggedItem),
           let to = items.firstIndex(of: item) {
            withAnimation {
                items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        onReorder(items)
        return true
    }
}
