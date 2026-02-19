//
//  ConversationDTO.swift
//  Swiss Coin
//
//  Codable DTO for the `conversations` Supabase table.
//

import Foundation

struct ConversationDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let participantA: UUID
    let participantB: UUID
    let createdAt: Date
    let updatedAt: Date
    var lastMessageAt: Date?
    var lastMessagePreview: String?

    enum CodingKeys: String, CodingKey {
        case id
        case participantA = "participant_a"
        case participantB = "participant_b"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastMessageAt = "last_message_at"
        case lastMessagePreview = "last_message_preview"
    }
}
