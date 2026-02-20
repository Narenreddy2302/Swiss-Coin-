//
//  SharedDataService.swift
//  Swiss Coin
//
//  Handles cross-user data sharing via phantom participants.
//  Creates participant records server-side, claims phantom shares,
//  and materializes shared transactions, settlements, subscriptions,
//  and reminders into CoreData.
//

import Combine
import CoreData
import Foundation
import Supabase
import os

private let logger = Logger(subsystem: "com.swisscoin", category: "shared-data")

@MainActor
final class SharedDataService: ObservableObject {
    static let shared = SharedDataService()

    private let dataService = SupabaseDataService.shared

    private init() {}

    // MARK: - Process Transaction Shares

    /// Creates participant records server-side for transactions that involve
    /// contacts with phone numbers. Called by SyncManager after push.
    func processShares(transactionIds: [UUID]) async {
        guard !transactionIds.isEmpty else { return }

        do {
            let ids = transactionIds.map(\.uuidString)
            let _: ProcessSharesResponse = try await SupabaseConfig.client.functions.invoke(
                "process-transaction-shares",
                options: .init(body: ["transaction_ids": ids])
            )
            logger.info("Processed shares for \(transactionIds.count) transactions")
        } catch {
            logger.error("Failed to process shares: \(error.localizedDescription)")
        }
    }

    // MARK: - Process Settlement Shares

    func processSettlementShares(settlementIds: [UUID]) async {
        guard !settlementIds.isEmpty else { return }
        do {
            let ids = settlementIds.map(\.uuidString)
            let _: ProcessSharesResponse = try await SupabaseConfig.client.functions.invoke(
                "process-settlement-shares",
                options: .init(body: ["settlement_ids": ids])
            )
            logger.info("Processed shares for \(settlementIds.count) settlements")
        } catch {
            logger.error("Failed to process settlement shares: \(error.localizedDescription)")
        }
    }

    // MARK: - Process Subscription Shares

    func processSubscriptionShares(subscriptionIds: [UUID]) async {
        guard !subscriptionIds.isEmpty else { return }
        do {
            let ids = subscriptionIds.map(\.uuidString)
            let _: ProcessSharesResponse = try await SupabaseConfig.client.functions.invoke(
                "process-subscription-shares",
                options: .init(body: ["subscription_ids": ids])
            )
            logger.info("Processed shares for \(subscriptionIds.count) subscriptions")
        } catch {
            logger.error("Failed to process subscription shares: \(error.localizedDescription)")
        }
    }

    // MARK: - Process Reminder Shares

    func processReminderShares(reminderIds: [UUID]) async {
        guard !reminderIds.isEmpty else { return }
        do {
            let ids = reminderIds.map(\.uuidString)
            let _: ProcessSharesResponse = try await SupabaseConfig.client.functions.invoke(
                "process-reminder-shares",
                options: .init(body: ["reminder_ids": ids])
            )
            logger.info("Processed shares for \(reminderIds.count) reminders")
        } catch {
            logger.error("Failed to process reminder shares: \(error.localizedDescription)")
        }
    }

    // MARK: - Claim Pending Shares

    /// Claims phantom participant records matching the caller's phone hash.
    /// Called after phone entry and on returning user login.
    func claimPendingShares() async -> ClaimResult? {
        do {
            let result: ClaimResult = try await SupabaseConfig.client.functions.invoke(
                "claim-pending-shares",
                options: .init(body: [:] as [String: String])
            )
            if result.claimedTransactions > 0 || result.claimedSettlements > 0 || result.claimedSubscriptions > 0 {
                logger.info("Claimed \(result.claimedTransactions) transactions, \(result.claimedSettlements) settlements, \(result.claimedSubscriptions) subscriptions")
            }
            return result
        } catch {
            logger.error("Failed to claim pending shares: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Pull Shared Transactions

    /// Fetches shared transactions from the server and materializes them into CoreData.
    /// Called during SyncManager pull phase.
    func pullSharedTransactions(context: NSManagedObjectContext, since: Date?) async throws {
        let body: [String: String]
        if let since {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body = ["since": formatter.string(from: since)]
        } else {
            body = [:]
        }

        let response: SharedTransactionsResponse
        do {
            response = try await SupabaseConfig.client.functions.invoke(
                "fetch-shared-transactions",
                options: .init(body: body)
            )
        } catch {
            logger.error("Failed to fetch shared transactions: \(error.localizedDescription)")
            return
        }

        guard !response.sharedTransactions.isEmpty else { return }

        let currentUserId = AuthManager.shared.currentUserId

        try context.performAndWait {
            for bundle in response.sharedTransactions {
                let txnData = bundle.transaction

                // Handle deleted shared transactions
                if txnData.deletedAt != nil {
                    self.deleteSharedTransaction(sourceId: txnData.id, in: context)
                    continue
                }

                // Map persons: find-or-create local Person entities by phone match
                var remoteToLocalPersonId: [String: UUID] = [:]
                for person in bundle.persons {
                    let localPerson = self.findOrCreatePersonByPhone(
                        remotePerson: person,
                        currentUserId: currentUserId,
                        in: context
                    )
                    if let localId = localPerson.value(forKey: "id") as? UUID {
                        remoteToLocalPersonId[person.id] = localId
                    }
                }

                // Find or create the shared transaction
                let txn = self.findOrCreateSharedTransaction(
                    sourceId: txnData.id,
                    in: context
                )

                // Apply transaction fields
                txn.title = txnData.title
                txn.amount = txnData.amount ?? 0
                txn.currency = txnData.currency
                txn.date = txnData.date
                txn.splitMethod = txnData.splitMethod
                txn.note = txnData.note
                txn.isShared = true
                txn.sharingStatus = bundle.participation.status
                txn.sharedByProfileId = txnData.ownerId

                // Resolve payer relationship
                if let payerId = txnData.payerId,
                   let localPayerId = remoteToLocalPersonId[payerId.uuidString] {
                    txn.payer = self.findExisting(Person.self, id: localPayerId, in: context)
                }

                // Replace splits
                if let existingSplits = txn.splits as? Set<TransactionSplit> {
                    for split in existingSplits { context.delete(split) }
                }
                for splitData in bundle.splits {
                    let split = TransactionSplit(context: context)
                    split.id = UUID()
                    split.amount = splitData.amount
                    split.rawAmount = splitData.rawAmount ?? splitData.amount
                    split.transaction = txn
                    if let localId = remoteToLocalPersonId[splitData.owedById.uuidString] {
                        split.owedBy = self.findExisting(Person.self, id: localId, in: context)
                    }
                }

                // Replace payers
                if let existingPayers = txn.payers as? Set<TransactionPayer> {
                    for payer in existingPayers { context.delete(payer) }
                }
                for payerData in bundle.payers {
                    let payer = TransactionPayer(context: context)
                    payer.id = UUID()
                    payer.amount = payerData.amount
                    payer.transaction = txn
                    if let localId = remoteToLocalPersonId[payerData.paidById.uuidString] {
                        payer.paidBy = self.findExisting(Person.self, id: localId, in: context)
                    }
                }

                // Auto-accept participation
                if bundle.participation.status == "pending" {
                    Task {
                        try? await self.dataService.updateParticipantStatus(
                            id: bundle.participation.id,
                            status: "accepted"
                        )
                    }
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }

        logger.info("Pulled \(response.sharedTransactions.count) shared transactions")
    }

    // MARK: - Pull Shared Settlements

    func pullSharedSettlements(context: NSManagedObjectContext, since: Date?) async throws {
        let body: [String: String]
        if let since {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body = ["since": formatter.string(from: since)]
        } else {
            body = [:]
        }

        let response: SharedSettlementsResponse
        do {
            response = try await SupabaseConfig.client.functions.invoke(
                "fetch-shared-settlements",
                options: .init(body: body)
            )
        } catch {
            logger.error("Failed to fetch shared settlements: \(error.localizedDescription)")
            return
        }

        guard !response.sharedSettlements.isEmpty else { return }

        let currentUserId = AuthManager.shared.currentUserId

        try context.performAndWait {
            for bundle in response.sharedSettlements {
                let settlementData = bundle.settlement

                // Handle deleted
                if settlementData.deletedAt != nil {
                    self.deleteSharedEntity(Settlement.self, sourceId: settlementData.id, in: context)
                    continue
                }

                // Map persons
                var remoteToLocalPersonId: [String: UUID] = [:]
                for person in bundle.persons {
                    let localPerson = self.findOrCreatePersonByPhone(
                        remotePerson: person,
                        currentUserId: currentUserId,
                        in: context
                    )
                    if let localId = localPerson.value(forKey: "id") as? UUID {
                        remoteToLocalPersonId[person.id] = localId
                    }
                }

                // Find or create settlement
                let settlement = self.findOrCreateSharedEntity(Settlement.self, sourceId: settlementData.id, in: context)
                settlement.amount = settlementData.amount ?? 0
                settlement.currency = settlementData.currency
                settlement.date = settlementData.date
                settlement.note = settlementData.note
                settlement.isFullSettlement = settlementData.isFullSettlement ?? false
                settlement.isShared = true
                settlement.sharingStatus = bundle.participation.status
                settlement.sharedByProfileId = settlementData.ownerId

                // Resolve from/to persons
                if let fromId = settlementData.fromPersonId,
                   let localId = remoteToLocalPersonId[fromId.uuidString] {
                    settlement.fromPerson = self.findExisting(Person.self, id: localId, in: context)
                }
                if let toId = settlementData.toPersonId,
                   let localId = remoteToLocalPersonId[toId.uuidString] {
                    settlement.toPerson = self.findExisting(Person.self, id: localId, in: context)
                }

                // Auto-accept
                if bundle.participation.status == "pending" {
                    Task {
                        try? await self.dataService.updateSettlementParticipantStatus(
                            id: bundle.participation.id,
                            status: "accepted"
                        )
                    }
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }

        logger.info("Pulled \(response.sharedSettlements.count) shared settlements")
    }

    // MARK: - Pull Shared Subscriptions

    func pullSharedSubscriptions(context: NSManagedObjectContext, since: Date?) async throws {
        let body: [String: String]
        if let since {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body = ["since": formatter.string(from: since)]
        } else {
            body = [:]
        }

        let response: SharedSubscriptionsResponse
        do {
            response = try await SupabaseConfig.client.functions.invoke(
                "fetch-shared-subscriptions",
                options: .init(body: body)
            )
        } catch {
            logger.error("Failed to fetch shared subscriptions: \(error.localizedDescription)")
            return
        }

        guard !response.sharedSubscriptions.isEmpty else { return }

        let currentUserId = AuthManager.shared.currentUserId

        try context.performAndWait {
            for bundle in response.sharedSubscriptions {
                let subData = bundle.subscription

                // Handle deleted
                if subData.deletedAt != nil {
                    self.deleteSharedEntity(Subscription.self, sourceId: subData.id, in: context)
                    continue
                }

                // Map persons
                var remoteToLocalPersonId: [String: UUID] = [:]
                for person in bundle.persons {
                    let localPerson = self.findOrCreatePersonByPhone(
                        remotePerson: person,
                        currentUserId: currentUserId,
                        in: context
                    )
                    if let localId = localPerson.value(forKey: "id") as? UUID {
                        remoteToLocalPersonId[person.id] = localId
                    }
                }

                // Find or create subscription
                let subscription = self.findOrCreateSharedEntity(Subscription.self, sourceId: subData.id, in: context)
                subscription.name = subData.name
                subscription.amount = subData.amount ?? 0
                subscription.cycle = subData.frequency
                subscription.startDate = subData.startDate
                subscription.notes = subData.note
                subscription.isShared = true
                subscription.sharingStatus = bundle.participation.status
                subscription.sharedByProfileId = subData.ownerId

                // Replace subscribers
                if let existingSubscribers = subscription.subscribers as? Set<Person> {
                    subscription.removeFromSubscribers(existingSubscribers as NSSet)
                }
                for subscriberData in bundle.subscribers {
                    if let localId = remoteToLocalPersonId[subscriberData.personId.uuidString],
                       let person = self.findExisting(Person.self, id: localId, in: context) {
                        subscription.addToSubscribers(person)
                    }
                }

                // Replace payments
                if let existingPayments = subscription.payments as? Set<SubscriptionPayment> {
                    for payment in existingPayments { context.delete(payment) }
                }
                for paymentData in bundle.payments {
                    let payment = SubscriptionPayment(context: context)
                    payment.id = paymentData.id
                    payment.amount = paymentData.amount
                    payment.date = paymentData.date
                    payment.note = paymentData.note
                    payment.subscription = subscription
                    if let payerId = paymentData.payerId,
                       let localId = remoteToLocalPersonId[payerId.uuidString] {
                        payment.payer = self.findExisting(Person.self, id: localId, in: context)
                    }
                }

                // Replace subscription settlements
                if let existingSettlements = subscription.settlements as? Set<SubscriptionSettlement> {
                    for s in existingSettlements { context.delete(s) }
                }
                for settlementData in bundle.settlements {
                    let settlement = SubscriptionSettlement(context: context)
                    settlement.id = settlementData.id
                    settlement.amount = settlementData.amount
                    settlement.date = settlementData.date
                    settlement.note = settlementData.note
                    settlement.subscription = subscription
                    if let fromId = settlementData.fromPersonId,
                       let localId = remoteToLocalPersonId[fromId.uuidString] {
                        settlement.fromPerson = self.findExisting(Person.self, id: localId, in: context)
                    }
                    if let toId = settlementData.toPersonId,
                       let localId = remoteToLocalPersonId[toId.uuidString] {
                        settlement.toPerson = self.findExisting(Person.self, id: localId, in: context)
                    }
                }

                // Replace subscription reminders
                if let existingReminders = subscription.reminders as? Set<SubscriptionReminder> {
                    for r in existingReminders { context.delete(r) }
                }
                for reminderData in bundle.reminders {
                    let reminder = SubscriptionReminder(context: context)
                    reminder.id = reminderData.id
                    reminder.amount = reminderData.amount
                    reminder.createdDate = reminderData.dueDate
                    reminder.message = reminderData.note
                    reminder.subscription = subscription
                    if let toId = reminderData.toPersonId,
                       let localId = remoteToLocalPersonId[toId.uuidString] {
                        reminder.toPerson = self.findExisting(Person.self, id: localId, in: context)
                    }
                }

                // Auto-accept participation
                if bundle.participation.status == "pending" {
                    Task {
                        try? await self.dataService.updateSubscriptionParticipantStatus(
                            id: bundle.participation.id,
                            status: "accepted"
                        )
                    }
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }

        logger.info("Pulled \(response.sharedSubscriptions.count) shared subscriptions")
    }

    // MARK: - Pull Shared Reminders

    func pullSharedReminders(context: NSManagedObjectContext, since: Date?) async throws {
        let sharedReminders: [SharedReminderDTO]
        do {
            sharedReminders = try await dataService.fetchSharedReminders()
        } catch {
            logger.error("Failed to fetch shared reminders: \(error.localizedDescription)")
            return
        }

        guard !sharedReminders.isEmpty else { return }

        try context.performAndWait {
            for dto in sharedReminders {
                let reminder = self.findOrCreateSharedEntity(Reminder.self, sourceId: dto.id, in: context)
                reminder.amount = dto.amount
                reminder.message = dto.message
                // Mark as read on server
                Task {
                    var updated = dto
                    updated.isRead = true
                    try? await self.dataService.upsertSharedReminder(updated)
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }

        logger.info("Pulled \(sharedReminders.count) shared reminders")
    }

    // MARK: - CoreData Helpers

    private nonisolated func findOrCreateSharedTransaction(
        sourceId: UUID,
        in context: NSManagedObjectContext
    ) -> FinancialTransaction {
        let request = NSFetchRequest<FinancialTransaction>(entityName: "FinancialTransaction")
        request.predicate = NSPredicate(
            format: "isShared == YES AND sharedByProfileId != nil AND id == %@",
            sourceId as CVarArg
        )
        request.fetchLimit = 1
        if let existing = (try? context.fetch(request))?.first {
            return existing
        }

        let txn = FinancialTransaction(context: context)
        txn.setValue(sourceId, forKey: "id")
        return txn
    }

    private nonisolated func deleteSharedTransaction(
        sourceId: UUID,
        in context: NSManagedObjectContext
    ) {
        let request = NSFetchRequest<FinancialTransaction>(entityName: "FinancialTransaction")
        request.predicate = NSPredicate(
            format: "isShared == YES AND id == %@",
            sourceId as CVarArg
        )
        request.fetchLimit = 1
        if let existing = (try? context.fetch(request))?.first {
            context.delete(existing)
        }
    }

    private nonisolated func findOrCreateSharedEntity<T: NSManagedObject>(
        _ type: T.Type,
        sourceId: UUID,
        in context: NSManagedObjectContext
    ) -> T {
        let request = T.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", sourceId as CVarArg)
        request.fetchLimit = 1
        if let existing = (try? context.fetch(request))?.first as? T {
            return existing
        }
        let entity = T(context: context)
        entity.setValue(sourceId, forKey: "id")
        return entity
    }

    private nonisolated func deleteSharedEntity<T: NSManagedObject>(
        _ type: T.Type,
        sourceId: UUID,
        in context: NSManagedObjectContext
    ) {
        let request = T.fetchRequest()
        request.predicate = NSPredicate(format: "isShared == YES AND id == %@", sourceId as CVarArg)
        request.fetchLimit = 1
        if let existing = (try? context.fetch(request))?.first as? T {
            context.delete(existing)
        }
    }

    private nonisolated func findOrCreatePersonByPhone(
        remotePerson: SharedPersonData,
        currentUserId: UUID?,
        in context: NSManagedObjectContext
    ) -> Person {
        // If this person's linked_profile_id matches current user, return current user's Person
        if let linkedId = remotePerson.linkedProfileId,
           let currentUserId,
           UUID(uuidString: linkedId) == currentUserId {
            let request = NSFetchRequest<Person>(entityName: "Person")
            request.predicate = NSPredicate(format: "id == %@", currentUserId as CVarArg)
            request.fetchLimit = 1
            if let currentUser = (try? context.fetch(request))?.first {
                return currentUser
            }
        }

        // Try to find by phone number match
        if let phone = remotePerson.phoneNumber, !phone.isEmpty {
            let request = NSFetchRequest<Person>(entityName: "Person")
            request.predicate = NSPredicate(format: "phoneNumber == %@", phone)
            request.fetchLimit = 1
            if let existing = (try? context.fetch(request))?.first {
                if (existing.value(forKey: "name") as? String) == nil || (existing.value(forKey: "name") as? String)?.isEmpty == true {
                    existing.setValue(remotePerson.name, forKey: "name")
                }
                return existing
            }
        }

        // Create a new Person for this contact
        let person = Person(context: context)
        person.setValue(UUID(), forKey: "id")
        person.setValue(remotePerson.name, forKey: "name")
        person.setValue(remotePerson.phoneNumber, forKey: "phoneNumber")
        person.setValue(remotePerson.colorHex, forKey: "colorHex")
        if let photoUrl = remotePerson.photoUrl {
            person.setValue(photoUrl, forKey: "photoURL")
        }
        return person
    }

    private nonisolated func findExisting<T: NSManagedObject>(
        _ type: T.Type, id: UUID, in context: NSManagedObjectContext
    ) -> T? {
        let request = T.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first as? T
    }
}

// MARK: - Response Types

struct ClaimResult: Decodable {
    let claimedTransactions: Int
    let claimedSettlements: Int
    let claimedSubscriptions: Int
    let claimedReminders: Int
    let transactionIds: [String]
    let settlementIds: [String]
    let subscriptionIds: [String]

    enum CodingKeys: String, CodingKey {
        case claimedTransactions = "claimed_transactions"
        case claimedSettlements = "claimed_settlements"
        case claimedSubscriptions = "claimed_subscriptions"
        case claimedReminders = "claimed_reminders"
        case transactionIds = "transaction_ids"
        case settlementIds = "settlement_ids"
        case subscriptionIds = "subscription_ids"
    }
}

private struct ProcessSharesResponse: Decodable {
    let processed: Int
    let participantsCreated: Int

    enum CodingKeys: String, CodingKey {
        case processed
        case participantsCreated = "participants_created"
    }
}

// MARK: - Transaction Response Types

private struct SharedTransactionsResponse: Decodable {
    let sharedTransactions: [SharedTransactionBundle]

    enum CodingKeys: String, CodingKey {
        case sharedTransactions = "shared_transactions"
    }
}

private struct SharedTransactionBundle: Decodable {
    let participation: SharedParticipation
    let transaction: SharedTransactionData
    let splits: [SharedSplitData]
    let payers: [SharedPayerData]
    let persons: [SharedPersonData]
    let creator: SharedCreatorData?
}

private struct SharedParticipation: Decodable {
    let id: UUID
    let status: String
    let role: String
}

private struct SharedTransactionData: Decodable {
    let id: UUID
    let title: String?
    let amount: Double?
    let currency: String?
    let date: Date?
    let splitMethod: String?
    let note: String?
    let ownerId: UUID?
    let payerId: UUID?
    let createdById: UUID?
    let groupId: UUID?
    let isShared: Bool?
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, amount, currency, date, note
        case splitMethod = "split_method"
        case ownerId = "owner_id"
        case payerId = "payer_id"
        case createdById = "created_by_id"
        case groupId = "group_id"
        case isShared = "is_shared"
        case deletedAt = "deleted_at"
    }
}

private struct SharedSplitData: Decodable {
    let id: UUID
    let owedById: UUID
    let amount: Double
    let rawAmount: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case owedById = "owed_by_id"
        case amount
        case rawAmount = "raw_amount"
    }
}

private struct SharedPayerData: Decodable {
    let id: UUID
    let paidById: UUID
    let amount: Double

    enum CodingKeys: String, CodingKey {
        case id
        case paidById = "paid_by_id"
        case amount
    }
}

struct SharedPersonData: Decodable {
    let id: String
    let name: String?
    let phoneNumber: String?
    let photoUrl: String?
    let colorHex: String?
    let linkedProfileId: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case phoneNumber = "phone_number"
        case photoUrl = "photo_url"
        case colorHex = "color_hex"
        case linkedProfileId = "linked_profile_id"
    }
}

private struct SharedCreatorData: Decodable {
    let id: String
    let displayName: String?
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case photoUrl = "photo_url"
    }
}

// MARK: - Settlement Response Types

private struct SharedSettlementsResponse: Decodable {
    let sharedSettlements: [SharedSettlementBundle]
    enum CodingKeys: String, CodingKey {
        case sharedSettlements = "shared_settlements"
    }
}

private struct SharedSettlementBundle: Decodable {
    let participation: SharedParticipation
    let settlement: SharedSettlementData
    let persons: [SharedPersonData]
    let creator: SharedCreatorData?
}

private struct SharedSettlementData: Decodable {
    let id: UUID
    let amount: Double?
    let currency: String?
    let date: Date?
    let note: String?
    let isFullSettlement: Bool?
    let ownerId: UUID?
    let fromPersonId: UUID?
    let toPersonId: UUID?
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, currency, date, note
        case isFullSettlement = "is_full_settlement"
        case ownerId = "owner_id"
        case fromPersonId = "from_person_id"
        case toPersonId = "to_person_id"
        case deletedAt = "deleted_at"
    }
}

// MARK: - Subscription Response Types

private struct SharedSubscriptionsResponse: Decodable {
    let sharedSubscriptions: [SharedSubscriptionBundle]
    enum CodingKeys: String, CodingKey {
        case sharedSubscriptions = "shared_subscriptions"
    }
}

private struct SharedSubscriptionBundle: Decodable {
    let participation: SharedParticipation
    let subscription: SharedSubscriptionData
    let subscribers: [SharedSubscriberData]
    let payments: [SharedSubPaymentData]
    let settlements: [SharedSubSettlementData]
    let reminders: [SharedSubReminderData]
    let persons: [SharedPersonData]
    let creator: SharedCreatorData?
}

private struct SharedSubscriptionData: Decodable {
    let id: UUID
    let name: String?
    let amount: Double?
    let currency: String?
    let frequency: String?
    let startDate: Date?
    let endDate: Date?
    let note: String?
    let ownerId: UUID?
    let isShared: Bool?
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, amount, currency, frequency, note
        case startDate = "start_date"
        case endDate = "end_date"
        case ownerId = "owner_id"
        case isShared = "is_shared"
        case deletedAt = "deleted_at"
    }
}

private struct SharedSubscriberData: Decodable {
    let personId: UUID
    enum CodingKeys: String, CodingKey {
        case personId = "person_id"
    }
}

private struct SharedSubPaymentData: Decodable {
    let id: UUID
    let amount: Double
    let date: Date?
    let payerId: UUID?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, date, note
        case payerId = "payer_id"
    }
}

private struct SharedSubSettlementData: Decodable {
    let id: UUID
    let amount: Double
    let date: Date?
    let fromPersonId: UUID?
    let toPersonId: UUID?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, date, note
        case fromPersonId = "from_person_id"
        case toPersonId = "to_person_id"
    }
}

private struct SharedSubReminderData: Decodable {
    let id: UUID
    let amount: Double
    let dueDate: Date?
    let toPersonId: UUID?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, note
        case dueDate = "due_date"
        case toPersonId = "to_person_id"
    }
}
