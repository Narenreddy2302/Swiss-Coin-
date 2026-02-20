//
//  ProfileDTO.swift
//  Swiss Coin
//
//  Codable DTO for the `profiles` Supabase table.
//  Maps 1:1 with auth.users — auto-created by handle_new_user() trigger.
//

import Foundation

struct ProfileDTO: Codable, Identifiable, Sendable {
    let id: UUID
    var displayName: String
    var fullName: String?
    var phone: String?
    var phoneHash: String?
    var email: String?
    var photoUrl: String?
    var colorHex: String?
    var isArchived: Bool
    var lastViewedDate: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case fullName = "full_name"
        case phone = "phone_number"
        case phoneHash = "phone_hash"
        case email
        case photoUrl = "photo_url"
        case colorHex = "color_hex"
        case isArchived = "is_archived"
        case lastViewedDate = "last_viewed_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - CoreData Conversion

extension ProfileDTO {
    /// Create DTO from the current user's Person entity
    init(from person: Person, userId: UUID) {
        self.id = userId
        self.displayName = person.name ?? "Me"
        self.fullName = UserDefaults.standard.string(forKey: "apple_full_name")
        self.phone = person.phoneNumber
        if let phone = person.phoneNumber, !phone.isEmpty {
            self.phoneHash = ContactDiscoveryService.hashPhoneNumber(phone)
        } else {
            self.phoneHash = nil
        }
        self.email = KeychainHelper.read(key: "apple_email")
        self.photoUrl = nil
        self.colorHex = person.colorHex
        self.isArchived = person.isArchived
        self.lastViewedDate = person.lastViewedDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Apply DTO values back to a Person entity (current user)
    func apply(to person: Person) {
        person.name = displayName
        // Don't clear phone locally if remote is nil — offline-first principle
        if let phone, !phone.isEmpty {
            person.phoneNumber = phone
        }
        person.colorHex = colorHex
        person.isArchived = isArchived
        person.lastViewedDate = lastViewedDate
    }
}
