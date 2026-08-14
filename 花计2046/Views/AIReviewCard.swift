import SwiftUI

/// AI 趣味点评卡片：根据用户近期收支，由后端 AI 生成一段幽默点评
struct AIReviewCard: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var review = ""
    @State private var isLoading = false
    @State private var loadFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AnalyticsModuleHeader(icon: "sparkles", title: "30天记录点评") {
                Button(action: { load() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.brandStart)
                }
                .disabled(isLoading)
            }

            Text("基于你最近 30 天的收支记录，生成一段轻松点评，博你一笑")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textTertiary)

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
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.brandStart)
                    .lineSpacing(5)
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
        .onAppear {
            if review.isEmpty && !isLoading && !AppConfig.useMockServices {
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
