import SwiftUI

/// AI 趣味点评卡片：根据用户近期收支，由后端 AI 生成一段幽默点评
struct AIReviewCard: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var review = ""
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var shakeTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AnalyticsModuleHeader(icon: "sparkles", title: "最近收支评价", titleFont: .custom("STKaiti", size: 17)) {
                Button(action: { load() }) {
                    Image(systemName: "cpu")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.brandEnd)
                }
                .disabled(isLoading)
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else if loadFailed || review.isEmpty {
                Button(action: { load() }) {
                    Text("生成失败，点此重试")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.brandStart)
                        .padding(.vertical, 16)
                }
            } else {
                Text(review)
                    // 手写体：使用系统楷体 STKaiti（iOS 内置，接近手写风格）；字体不存在时自动回退默认
                    .font(.custom("STKaiti", size: 16))
                    .foregroundColor(AppTheme.brandStart)
                    .lineSpacing(7)
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.white, AppTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
        // 点击更新时卡片左右抖动，形成动态交互效果
        .keyframeAnimator(initialValue: ShakeValue(), trigger: shakeTrigger) { content, value in
            content
                .rotationEffect(.degrees(value.rotation))
        } keyframes: { _ in
            KeyframeTrack(\.rotation) {
                CubicKeyframe(-3, duration: 0.08)
                CubicKeyframe(3, duration: 0.12)
                CubicKeyframe(-3, duration: 0.12)
                CubicKeyframe(3, duration: 0.12)
                CubicKeyframe(-2, duration: 0.12)
                CubicKeyframe(0, duration: 0.1)
            }
        }
        .task {
            // 进入页面自动加载一版点评；后续点机器人按钮每次重新生成（每次内容不同）
            if review.isEmpty && !isLoading && !loadFailed && !AppConfig.useMockServices {
                load()
            }
        }
    }

    private func load() {
        guard !AppConfig.useMockServices else { return }
        isLoading = true
        loadFailed = false
        Task {
            do {
                let result: ReviewResponse = try await BackendAPI.shared.post(
                    path: "spending-review",
                    body: ReviewRequest()
                )
                await MainActor.run {
                    review = result.review
                    isLoading = false
                    shakeTrigger += 1
                }
            } catch {
                Log.error("AI 趣味点评生成失败: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                    loadFailed = true
                }
            }
        }
    }
}

private struct ReviewRequest: Encodable {}

private struct ReviewResponse: Decodable {
    let review: String
}

/// 点评卡片抖动动画的插值状态
private struct ShakeValue {
    var rotation: Double = 0
}
