//
//  SettlementDTO.swift
//  Swiss Coin
//
//  Codable DTO for the `settlements` Supabase table.
//

import Foundation

struct SettlementDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let ownerId: UUID
    var amount: Double
    var currency: String?
    var date: Date
    var note: String?
    var isFullSettlement: Bool
    let fromPersonId: UUID
    let toPersonId: UUID
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case amount
        case currency
        case date
        case note
        case isFullSettlement = "is_full_settlement"
        case fromPersonId = "from_person_id"
        case toPersonId = "to_person_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - CoreData Conversion

extension SettlementDTO {
    init(from settlement: Settlement, ownerId: UUID) {
        self.id = settlement.id ?? UUID()
        self.ownerId = ownerId
        self.amount = settlement.amount
        self.currency = settlement.currency
        self.date = settlement.date ?? Date()
        self.note = settlement.note
        self.isFullSettlement = settlement.isFullSettlement
        self.fromPersonId = settlement.fromPerson?.id ?? UUID()
        self.toPersonId = settlement.toPerson?.id ?? UUID()
        self.createdAt = Date()
        self.updatedAt = settlement.updatedAt ?? Date()
        self.deletedAt = settlement.deletedAt
    }

    func apply(to settlement: Settlement) {
        settlement.id = id
        settlement.amount = amount
        settlement.currency = currency
        settlement.date = date
        settlement.note = note
        settlement.isFullSettlement = isFullSettlement
        settlement.updatedAt = updatedAt
        settlement.deletedAt = deletedAt
    }
}
