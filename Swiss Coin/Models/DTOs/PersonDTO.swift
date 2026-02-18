//
//  PersonDTO.swift
//  Swiss Coin
//
//  Codable DTO for the `persons` Supabase table.
//  Represents contacts owned by the user (not other Supabase users).
//

import Foundation

struct PersonDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let ownerId: UUID
    var name: String
    var phoneNumber: String?
    var photoUrl: String?
    var colorHex: String?
    var isArchived: Bool
    var lastViewedDate: Date?
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case phoneNumber = "phone_number"
        case photoUrl = "photo_url"
        case colorHex = "color_hex"
        case isArchived = "is_archived"
        case lastViewedDate = "last_viewed_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - CoreData Conversion

extension PersonDTO {
    /// Create DTO from CoreData Person entity
    init(from person: Person, ownerId: UUID) {
        self.id = person.id ?? UUID()
        self.ownerId = ownerId
        self.name = person.name ?? ""
        self.phoneNumber = person.phoneNumber
        self.photoUrl = person.photoURL
        self.colorHex = person.colorHex
        self.isArchived = person.isArchived
        self.lastViewedDate = person.lastViewedDate
        self.createdAt = Date()
        self.updatedAt = person.updatedAt ?? Date()
        self.deletedAt = person.deletedAt
    }

    /// Apply DTO values to a CoreData Person entity
    func apply(to person: Person) {
        person.id = id
        person.name = name
        person.phoneNumber = phoneNumber
        person.photoURL = photoUrl
        person.colorHex = colorHex
        person.isArchived = isArchived
        person.lastViewedDate = lastViewedDate
        person.updatedAt = updatedAt
        person.deletedAt = deletedAt
    }
}
