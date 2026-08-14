import SwiftUI

/// 最近收支评价卡片：AI 生成评价，打字机逐字显示 + 闪烁光标
struct AIReviewCard: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var fullText = ""
    @State private var displayedText = ""
    @State private var isLoading = false
    @State private var isTyping = false
    @State private var cursorBlink = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AnalyticsModuleHeader(icon: "sparkles", title: "最近收支评价") {
                Button(action: { load() }) {
                    Image(systemName: "cpu")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.brandEnd)
                }
                .disabled(isLoading || isTyping)
            }

            // 内容区：无内容时一律显示闪烁光标（等待 AI 生成）
            if fullText.isEmpty {
                HStack(spacing: 2) {
                    cursorView
                }
                .padding(.vertical, 18)
            } else {
                // 打字机显示 + 打字中光标闪烁
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(displayedText)
                        // 手写体：优先手札体，失败回退楷体
                        .font(reviewFont)
                        .foregroundColor(AppTheme.brandStart)
                        .lineSpacing(7)
                    if isTyping {
                        cursorView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .task {
            // 进入页面自动加载一版
            if fullText.isEmpty && !isLoading && !loadFailed && !AppConfig.useMockServices {
                load()
            }
        }
    }

    /// 手写体：优先手札体 Hannotate SC，失败回退楷体 STKaiti，再回退系统字体
    private var reviewFont: Font {
        if let font = UIFont(name: "Hannotate SC", size: 16) {
            return Font(font)
        }
        if let font = UIFont(name: "STKaiti", size: 16) {
            return Font(font)
        }
        return .system(size: 16)
    }

    /// 闪烁光标（标准紫色）
    private var cursorView: some View {
        Text("▍")
            .font(reviewFont)
            .foregroundColor(AppTheme.brandEnd)
            .opacity(cursorBlink ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                    cursorBlink.toggle()
                }
            }
    }

    private func load() {
        guard !AppConfig.useMockServices else { return }
        isLoading = true
        Task {
            do {
                let result: ReviewResponse = try await BackendAPI.shared.post(
                    path: "spending-review",
                    body: ReviewRequest()
                )
                await MainActor.run {
                    fullText = result.review
                    displayedText = ""
                    isLoading = false
                    startTyping()
                }
            } catch {
                Log.error("最近收支评价生成失败: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    /// 打字机逐字显示：普通字快，标点稍停，模拟人类输入节奏
    private func startTyping() {
        isTyping = true
        Task {
            var current = ""
            for ch in fullText {
                current.append(ch)
                let snapshot = current
                await MainActor.run { displayedText = snapshot }

                let delay: UInt64
                if "。！？!?.".contains(ch) {
                    delay = 180_000_000      // 句末停顿
                } else if "，,、；;：:".contains(ch) {
                    delay = 110_000_000      // 逗号停顿
                } else {
                    delay = 35_000_000       // 普通字
                }
                try? await Task.sleep(nanoseconds: delay)
            }
            await MainActor.run { isTyping = false }
        }
    }
}

private struct ReviewRequest: Encodable {}

private struct ReviewResponse: Decodable {
    let review: String
}
