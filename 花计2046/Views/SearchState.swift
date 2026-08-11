import Foundation
import Combine

/// 账本搜索筛选状态
/// 从 SupabaseService 拆出，便于独立测试和维护；App 内共享单例，
/// 保证「账本」页与「分析」页的筛选条件联动。
@MainActor
final class SearchState: ObservableObject {
    static let shared = SearchState()

    @Published var text = ""
    @Published var note = ""
    @Published var category = ""
    @Published var month = ""
    @Published var year = ""
    @Published var type = "全部"

    private init() {}

    /// 是否有任意筛选条件生效
    var isActive: Bool {
        !text.isEmpty || !note.isEmpty || !category.isEmpty || !year.isEmpty || !month.isEmpty || type != "全部"
    }

    /// 清空所有筛选条件
    func reset() {
        text = ""
        note = ""
        category = ""
        month = ""
        year = ""
        type = "全部"
    }
}
