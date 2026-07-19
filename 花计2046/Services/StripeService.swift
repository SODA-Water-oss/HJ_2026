import Foundation
import Combine
#if !DEBUG
import StripePaymentSheet

class StripeService: ObservableObject {
    static let shared = StripeService()
    
    @Published var paymentSheet: PaymentSheet?
    @Published var paymentResult: PaymentSheetResult?
    @Published var errorMessage = ""
    
    func loadPaymentSheet() async {
        do {
            let response: PaymentSheetResponse = try await BackendAPI.shared.post(
                path: "create-payment-sheet",
                body: PaymentSheetRequest()
            )

            preparePaymentSheet(
                customerId: response.customerId,
                customerEphemeralKeySecret: response.customerEphemeralKeySecret,
                paymentIntentClientSecret: response.paymentIntentClientSecret
            )

            DispatchQueue.main.async {
                self.errorMessage = ""
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func preparePaymentSheet(customerId: String, customerEphemeralKeySecret: String, paymentIntentClientSecret: String) {
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Matrix Expense Tracker"
        configuration.customer = .init(id: customerId, ephemeralKeySecret: customerEphemeralKeySecret)
        
        configuration.allowsDelayedPaymentMethods = true
        
        DispatchQueue.main.async {
            self.paymentSheet = PaymentSheet(paymentIntentClientSecret: paymentIntentClientSecret, configuration: configuration)
        }
    }
    
    func unlockPremium() async {
        await SupabaseService.shared.fetchUserProfile()
    }
}

private struct PaymentSheetRequest: Encodable {}

private struct PaymentSheetResponse: Decodable {
    let customerId: String
    let customerEphemeralKeySecret: String
    let paymentIntentClientSecret: String
}
#endif
