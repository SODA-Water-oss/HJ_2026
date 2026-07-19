import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var email: String
    var isPremium: Bool
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case isPremium = "is_premium"
        case createdAt = "created_at"
    }
}
