//
//  TransactionDTO.swift
//  Swiss Coin
//
//  Codable DTOs for `financial_transactions`, `transaction_splits`,
//  and `transaction_payers` Supabase tables.
//

import Foundation

struct TransactionDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let ownerId: UUID
    var title: String
    var amount: Double
    var currency: String?
    var date: Date
    var splitMethod: String?
    var note: String?
    var payerId: UUID?
    var createdById: UUID?
    var groupId: UUID?
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case amount
        case currency
        case date
        case splitMethod = "split_method"
        case note
        case payerId = "payer_id"
        case createdById = "created_by_id"
        case groupId = "group_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - Transaction Split

struct TransactionSplitDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let transactionId: UUID
    let owedById: UUID
    var amount: Double
    var rawAmount: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case owedById = "owed_by_id"
        case amount
        case rawAmount = "raw_amount"
    }
}

// MARK: - Transaction Payer

struct TransactionPayerDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let transactionId: UUID
    let paidById: UUID
    var amount: Double

    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case paidById = "paid_by_id"
        case amount
    }
}

// MARK: - CoreData Conversion

extension TransactionDTO {
    init(from transaction: FinancialTransaction, ownerId: UUID) {
        self.id = transaction.id ?? UUID()
        self.ownerId = ownerId
        self.title = transaction.title ?? ""
        self.amount = transaction.amount
        self.currency = transaction.currency
        self.date = transaction.date ?? Date()
        self.splitMethod = transaction.splitMethod
        self.note = transaction.note
        self.payerId = transaction.payer?.id
        self.createdById = transaction.createdBy?.id
        self.groupId = transaction.group?.id
        self.createdAt = Date()
        self.updatedAt = transaction.updatedAt ?? Date()
        self.deletedAt = transaction.deletedAt
    }

    func apply(to transaction: FinancialTransaction) {
        transaction.id = id
        transaction.title = title
        transaction.amount = amount
        transaction.currency = currency
        transaction.date = date
        transaction.splitMethod = splitMethod
        transaction.note = note
        transaction.updatedAt = updatedAt
        transaction.deletedAt = deletedAt
    }
}

extension TransactionSplitDTO {
    init(from split: TransactionSplit, transactionId: UUID) {
        self.id = split.id ?? UUID()
        self.transactionId = transactionId
        self.owedById = split.owedBy?.id ?? UUID()
        self.amount = split.amount
        self.rawAmount = split.rawAmount
    }

    func apply(to split: TransactionSplit) {
        split.id = id
        split.amount = amount
        split.rawAmount = rawAmount ?? 0
    }
}

extension TransactionPayerDTO {
    init(from payer: TransactionPayer, transactionId: UUID) {
        self.id = payer.id ?? UUID()
        self.transactionId = transactionId
        self.paidById = payer.paidBy?.id ?? UUID()
        self.amount = payer.amount
    }

    func apply(to payer: TransactionPayer) {
        payer.id = id
        payer.amount = amount
    }
}
