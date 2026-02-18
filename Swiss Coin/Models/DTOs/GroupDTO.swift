//
//  GroupDTO.swift
//  Swiss Coin
//
//  Codable DTOs for the `user_groups` and `group_members` Supabase tables.
//

import Foundation

struct GroupDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let ownerId: UUID
    var name: String
    var photoUrl: String?
    var colorHex: String?
    var createdDate: Date
    var lastViewedDate: Date?
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case photoUrl = "photo_url"
        case colorHex = "color_hex"
        case createdDate = "created_date"
        case lastViewedDate = "last_viewed_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - Group Members Junction

struct GroupMemberDTO: Codable, Sendable {
    let groupId: UUID
    let personId: UUID

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case personId = "person_id"
    }
}

// MARK: - CoreData Conversion

extension GroupDTO {
    init(from group: UserGroup, ownerId: UUID) {
        self.id = group.id ?? UUID()
        self.ownerId = ownerId
        self.name = group.name ?? ""
        self.photoUrl = group.photoURL
        self.colorHex = group.colorHex
        self.createdDate = group.createdDate ?? Date()
        self.lastViewedDate = group.lastViewedDate
        self.createdAt = Date()
        self.updatedAt = group.updatedAt ?? Date()
        self.deletedAt = group.deletedAt
    }

    func apply(to group: UserGroup) {
        group.id = id
        group.name = name
        group.photoURL = photoUrl
        group.colorHex = colorHex
        group.createdDate = createdDate
        group.lastViewedDate = lastViewedDate
        group.updatedAt = updatedAt
        group.deletedAt = deletedAt
    }
}
