//
//  SharedReminderDTO.swift
//  Swiss Coin
//
//  Codable DTO for the `shared_reminders` Supabase table.
//

import Foundation

struct SharedReminderDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let fromProfileId: UUID
    let toProfileId: UUID
    var amount: Double
    var currency: String?
    var message: String?
    var isRead: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fromProfileId = "from_profile_id"
        case toProfileId = "to_profile_id"
        case amount, currency, message
        case isRead = "is_read"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
