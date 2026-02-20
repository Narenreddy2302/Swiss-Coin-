//
//  PersonDTO.swift
//  Swiss Coin
//
//  Codable DTO for the `persons` Supabase table.
//  Represents contacts owned by the user (not other Supabase users).
//

import CryptoKit
import Foundation

struct PersonDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let ownerId: UUID
    var name: String
    var phoneNumber: String?
    var phoneHash: String?
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
        case phoneHash = "phone_hash"
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
        // Compute phone hash for phantom sharing lookups
        if let phone = person.phoneNumber, !phone.isEmpty {
            let normalized = phone.components(
                separatedBy: CharacterSet.decimalDigits.inverted
                    .subtracting(CharacterSet(charactersIn: "+"))
            ).joined()
            let data = Data(normalized.utf8)
            let hash = SHA256.hash(data: data)
            self.phoneHash = hash.map { String(format: "%02x", $0) }.joined()
        } else {
            self.phoneHash = nil
        }
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
