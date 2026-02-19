//
//  TransactionParticipantDTO.swift
//  Swiss Coin
//
//  Codable DTO for the `transaction_participants` Supabase table.
//

import Foundation

struct TransactionParticipantDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let transactionId: UUID
    let profileId: UUID
    var status: String
    var role: String
    var localPersonId: UUID?
    var respondedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case profileId = "profile_id"
        case status, role
        case localPersonId = "local_person_id"
        case respondedAt = "responded_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
