//
//  ReminderDTO.swift
//  Swiss Coin
//
//  Codable DTO for the `reminders` Supabase table.
//

import Foundation

struct ReminderDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let ownerId: UUID
    var createdDate: Date
    let toPersonId: UUID
    var amount: Double
    var message: String?
    var isRead: Bool
    var isCleared: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case createdDate = "created_date"
        case toPersonId = "to_person_id"
        case amount
        case message
        case isRead = "is_read"
        case isCleared = "is_cleared"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - CoreData Conversion

extension ReminderDTO {
    init(from reminder: Reminder, ownerId: UUID) {
        self.id = reminder.id ?? UUID()
        self.ownerId = ownerId
        self.createdDate = reminder.createdDate ?? Date()
        self.toPersonId = reminder.toPerson?.id ?? UUID()
        self.amount = reminder.amount
        self.message = reminder.message
        self.isRead = reminder.isRead
        self.isCleared = reminder.isCleared
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func apply(to reminder: Reminder) {
        reminder.id = id
        reminder.createdDate = createdDate
        reminder.amount = amount
        reminder.message = message
        reminder.isRead = isRead
        reminder.isCleared = isCleared
    }
}
