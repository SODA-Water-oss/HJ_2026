import SwiftUI
#if !DEBUG
import StripePaymentSheet
#endif

struct SubscriptionView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    #if !DEBUG
    @ObservedObject var stripeService = StripeService.shared
    #endif
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 20) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(AppTheme.brandStart)
                        
                        Text("高级权限")
                            .font(.appLargeTitle)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("解锁语音录入功能，让系统倾听并自动记录。")
                            .font(.appBody)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    
                    if supabaseService.userProfile?.isPremium == true {
                        HStack {
                            Circle().fill(Color.green).frame(width: 10, height: 10)
                            Text("高级版已激活")
                                .font(.appTitle)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                    } else {
                        #if !DEBUG
                        VStack(spacing: 16) {
                            if let paymentSheet = stripeService.paymentSheet {
                                PaymentSheet.PaymentButton(
                                    paymentSheet: paymentSheet,
                                    onCompletion: stripeService.onPaymentCompletion
                                ) {
                                    Text("立即升级（¥9.99/月）")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(AppPrimaryButtonStyle())
                            } else {
                                Button(action: loadPaymentSheet) {
                                    Text("申请升级权限")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(AppPrimaryButtonStyle())
                            }
                            
                            if !stripeService.errorMessage.isEmpty {
                                Text(stripeService.errorMessage)
                                    .font(.appSmall)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(24)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        #endif
                    }
                    
                    // Test button - free upgrade for testing
                    VStack(spacing: 8) {
                        Button(action: {
                            Task { await supabaseService.upgradeToPremium() }
                        }) {
                            Text("免费激活高级版（测试用）")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        
                        Text("测试环境使用，直接升级无需付款")
                            .font(.appSmall)
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.vertical, 32)
            }
            .offset(y: -11)
            .background(AppTheme.background)
            .navigationTitle("升级")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.brandGradient)
                        Text("升级")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
        }
    }
    
    #if !DEBUG
    func loadPaymentSheet() {
        Task { await stripeService.loadPaymentSheet() }
    }
    #endif
}

#if !DEBUG
extension StripeService {
    func onPaymentCompletion(result: PaymentSheetResult) {
        self.paymentResult = result
        switch result {
        case .completed:
            print("Payment completed!")
            Task { await self.unlockPremium() }
        case .canceled:
            print("Payment canceled.")
        case .failed(let error):
            print("Payment failed: \(error.localizedDescription)")
        }
    }
}
#endif
