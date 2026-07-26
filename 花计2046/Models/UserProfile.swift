import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var email: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
    }
}
