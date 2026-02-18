//
//  MessageDTO.swift
//  Swiss Coin
//
//  Codable DTO for the `chat_messages` Supabase table.
//

import Foundation

struct MessageDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let ownerId: UUID
    var content: String
    var timestamp: Date
    var isFromUser: Bool
    var isEdited: Bool
    var withPersonId: UUID?
    var withGroupId: UUID?
    var withSubscriptionId: UUID?
    var onTransactionId: UUID?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case content
        case timestamp
        case isFromUser = "is_from_user"
        case isEdited = "is_edited"
        case withPersonId = "with_person_id"
        case withGroupId = "with_group_id"
        case withSubscriptionId = "with_subscription_id"
        case onTransactionId = "on_transaction_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - CoreData Conversion

extension MessageDTO {
    init(from message: ChatMessage, ownerId: UUID) {
        self.id = message.id ?? UUID()
        self.ownerId = ownerId
        self.content = message.content ?? ""
        self.timestamp = message.timestamp ?? Date()
        self.isFromUser = message.isFromUser
        self.isEdited = message.isEdited
        self.withPersonId = message.withPerson?.id
        self.withGroupId = message.withGroup?.id
        self.withSubscriptionId = message.withSubscription?.id
        self.onTransactionId = message.onTransaction?.id
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func apply(to message: ChatMessage) {
        message.id = id
        message.content = content
        message.timestamp = timestamp
        message.isFromUser = isFromUser
        message.isEdited = isEdited
    }
}
