//
//  SubscriptionParticipantDTO.swift
//  Swiss Coin
//
//  Codable DTO for the `subscription_participants` Supabase table.
//

import Foundation

struct SubscriptionParticipantDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let subscriptionId: UUID
    let profileId: UUID?
    var status: String
    var role: String
    var localPersonId: UUID?
    var phoneHash: String?
    var sourceOwnerId: UUID?
    var respondedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case subscriptionId = "subscription_id"
        case profileId = "profile_id"
        case status, role
        case localPersonId = "local_person_id"
        case phoneHash = "phone_hash"
        case sourceOwnerId = "source_owner_id"
        case respondedAt = "responded_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
