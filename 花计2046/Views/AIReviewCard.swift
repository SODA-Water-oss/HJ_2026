import SwiftUI

/// 最近收支评价卡片：AI 生成评价，打字机逐字显示 + 闪烁光标
struct AIReviewCard: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @ObservedObject private var agentManager = AgentConfigManager.shared
    @State private var fullText = ""
    @State private var displayedText = ""
    @State private var isLoading = false
    @State private var isTyping = false
    @State private var cursorBlink = true
    @State private var showAgentFailureAlert = false
    @State private var agentFailureMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AnalyticsModuleHeader(icon: "sparkles", title: "最近收支评价")

            HStack(alignment: .top, spacing: 12) {
                ReviewPetView(mood: petMood) {
                    if !isLoading && !isTyping {
                        load()
                    }
                }

                // 内容区：无内容时一律显示闪烁光标（等待 AI 生成）
                if fullText.isEmpty {
                    HStack(spacing: 2) {
                        cursorView
                    }
                    .padding(.vertical, 18)
                } else {
                    // 打字机显示 + 打字中光标闪烁
                    Text(typingContent)
                        // 手写体：优先手札体，失败回退楷体
                        .font(reviewFont)
                        .lineSpacing(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .task {
            // 进入页面自动加载一版；失败也保持光标，点 cpu 按钮重新生成
            if fullText.isEmpty && !isLoading && !AppConfig.useMockServices {
                load()
            }
        }
        .alert("智能体异常", isPresented: $showAgentFailureAlert) {
            Button("知道了", role: .cancel) { }
        } message: { Text(agentFailureMessage) }
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

    private var petMood: ReviewPetMood {
        let now = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -30, to: now) else {
            return .neutral
        }
        let recent = supabaseService.allRecords.filter { $0.date >= start }
        let income = recent.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let expense = recent.filter(\.isExpense).reduce(0) { $0 + $1.amount }
        if expense > income * 1.15 {
            return .worried
        }
        if income > 0 && expense <= income {
            return .happy
        }
        return .neutral
    }

    private var typingContent: AttributedString {
        var text = AttributedString(displayedText)
        text.foregroundColor = AppTheme.brandStart
        if isTyping && cursorBlink {
            var cursor = AttributedString("▍")
            cursor.foregroundColor = AppTheme.brandEnd
            text.append(cursor)
        }
        return text
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
                let review: String
                if let config = agentManager.config, config.isValid {
                    do {
                        review = try await AgentConfigManager.shared.generateReview(config: config, records: supabaseService.allRecords)
                        Log.info("自定义智能体点评成功: \(config.displayName)")
                    } catch {
                        let reason = (error as? AgentConfigError)?.errorDescription ?? error.localizedDescription
                        agentManager.recordFailure(providerName: config.displayName, reason: reason)
                        Log.warn("自定义智能体点评失败，降级默认智能体: \(reason)")
                        let result: ReviewResponse = try await BackendAPI.shared.post(
                            path: "spending-review",
                            body: ReviewRequest()
                        )
                        review = result.review
                    }
                } else {
                    let result: ReviewResponse = try await BackendAPI.shared.post(
                        path: "spending-review",
                        body: ReviewRequest()
                    )
                    review = result.review
                }
                await MainActor.run {
                    if let failure = agentManager.lastFailure {
                        agentFailureMessage = failure.message
                        showAgentFailureAlert = true
                        agentManager.clearFailure()
                    }
                    fullText = review
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
        startCursorBlink()
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

    private func startCursorBlink() {
        cursorBlink = true
        Task {
            while isTyping && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 450_000_000)
                await MainActor.run { cursorBlink.toggle() }
            }
        }
    }
}

enum ReviewPetMood {
    case happy
    case neutral
    case worried
}

/// 收支评价小宠物：根据收支情况切换表情
struct ReviewPetView: View {
    let mood: ReviewPetMood
    var onTap: (() -> Void)? = nil
    @State private var bounce = false
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // 立耳
            Image(systemName: "triangle.fill")
                .font(.system(size: 21))
                .foregroundColor(Color(hex: "#6F6F6F"))
                .rotationEffect(.degrees(-18))
                .offset(x: -23, y: -27)
            Image(systemName: "triangle.fill")
                .font(.system(size: 21))
                .foregroundColor(Color(hex: "#6F6F6F"))
                .rotationEffect(.degrees(18))
                .offset(x: 23, y: -27)

            // 头部
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#C9CDD4"), Color(hex: "#8F969F")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color(hex: "#6F6F6F").opacity(0.4), lineWidth: 1)
                )

            // 眉毛
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: 13, height: 3)
                .rotationEffect(.degrees(-10))
                .offset(x: -9, y: -13)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: 13, height: 3)
                .rotationEffect(.degrees(10))
                .offset(x: 9, y: -13)

            // 眼睛
            HStack(spacing: 14) {
                eye(mood == .happy)
                eye(mood == .happy)
            }
            .offset(y: -4)

            // 围绕口鼻的一圈白色胡子
            Ellipse()
                .fill(Color.white)
                .frame(width: 46, height: 30)
                .offset(y: 10)

            // 口鼻
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(width: 30, height: 20)
                .offset(y: 8)
            Circle()
                .fill(Color(hex: "#2F2F2F"))
                .frame(width: 6, height: 6)
                .offset(y: 5)

            // 两侧胡须
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: 11, height: 22)
                .rotationEffect(.degrees(-12))
                .offset(x: -19, y: 8)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: 11, height: 22)
                .rotationEffect(.degrees(12))
                .offset(x: 19, y: 8)

            // 嘴
            mouth
                .offset(y: 9)

            // 下巴大胡子
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 12, height: 15)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 12, height: 15)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 12, height: 15)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(hex: "#E5E5E5"), lineWidth: 0.5)
            )
            .offset(y: 22)

            // 腮红
            Circle()
                .fill(AppTheme.brandEnd.opacity(0.16))
                .frame(width: 8, height: 8)
                .offset(x: -22, y: 5)
            Circle()
                .fill(AppTheme.brandEnd.opacity(0.16))
                .frame(width: 8, height: 8)
                .offset(x: 22, y: 5)
        }
        .frame(width: 64, height: 66)
        .scaleEffect(bounce ? 1.04 : 1)
        .offset(x: shakeOffset)
        .contentShape(Rectangle())
        .onTapGesture {
            shake()
            onTap?()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.45).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }

    private func shake() {
        var delay = 0.0
        for offset: CGFloat in [-6, 6, -4, 4, 0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.06)) {
                    shakeOffset = offset
                }
            }
            delay += 0.06
        }
    }

    private func eye(_ isHappy: Bool) -> some View {
        Group {
            if isHappy {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.black)
            } else if mood == .worried {
                VStack(spacing: 1) {
                    Rectangle()
                        .fill(Color(hex: "#565B63"))
                        .frame(width: 12, height: 2.5)
                        .rotationEffect(.degrees(16))
                    Circle()
                        .fill(.black)
                        .frame(width: 5, height: 5)
                }
            } else {
                Circle()
                    .fill(.black)
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var mouth: some View {
        Group {
            if mood == .happy {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addQuadCurve(
                        to: CGPoint(x: 16, y: 0),
                        control: CGPoint(x: 8, y: 9)
                    )
                }
                .stroke(Color(hex: "#2F2F2F"), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 16, height: 9)
            } else if mood == .worried {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 8))
                    path.addQuadCurve(
                        to: CGPoint(x: 16, y: 8),
                        control: CGPoint(x: 8, y: 1)
                    )
                }
                .stroke(Color(hex: "#2F2F2F"), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 16, height: 9)
            } else {
                Capsule()
                    .fill(Color(hex: "#2F2F2F"))
                    .frame(width: 11, height: 2.5)
            }
        }
    }
}

private struct ReviewRequest: Encodable {}

private struct ReviewResponse: Decodable {
    let review: String
}
