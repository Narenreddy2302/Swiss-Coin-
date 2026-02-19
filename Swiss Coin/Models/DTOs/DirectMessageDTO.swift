//
//  DirectMessageDTO.swift
//  Swiss Coin
//
//  Codable DTO for the `direct_messages` Supabase table.
//

import Foundation

struct DirectMessageDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    var content: String
    var status: String
    var isEdited: Bool
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case status
        case isEdited = "is_edited"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - CoreData Conversion

extension DirectMessageDTO {
    /// Apply DTO values to a DirectMessage CoreData entity
    func apply(to dm: DirectMessage) {
        dm.id = id
        dm.content = content
        dm.senderId = senderId
        dm.status = status
        dm.isEdited = isEdited
        dm.isSynced = true
        dm.createdAt = createdAt
        dm.updatedAt = updatedAt
        dm.deletedAt = deletedAt
    }
}
