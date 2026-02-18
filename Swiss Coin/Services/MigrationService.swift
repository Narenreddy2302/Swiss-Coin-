//
//  MigrationService.swift
//  Swiss Coin
//
//  Migrates existing local CoreData data to Supabase for users who had
//  offline data before signing in. Uploads entities in FK-dependency order.
//  Uses upsert so re-running after a partial failure is safe.
//

import Combine
import CoreData
import Foundation
import os

private let logger = Logger(subsystem: "com.swisscoin", category: "migration")

@MainActor
final class MigrationService: ObservableObject {
    static let shared = MigrationService()

    @Published var progress: MigrationProgress = .idle
    @Published var currentEntity: String = ""
    @Published var migratedCount: Int = 0
    @Published var totalCount: Int = 0

    private let dataService = SupabaseDataService.shared
    private let storageService = StorageService.shared

    private init() {}

    enum MigrationProgress: Equatable {
        case idle
        case inProgress
        case completed
        case failed(String)
    }

    /// Check if migration is needed
    var needsMigration: Bool {
        let hasLocalData = UserDefaults.standard.string(forKey: "currentUserId") != nil
        let migrationDone = UserDefaults.standard.bool(forKey: "supabase_migration_completed")
        return hasLocalData && !migrationDone
    }

    /// Perform the full migration: local CoreData → Supabase
    /// Uploads entities in FK-dependency order.
    func migrate(context: NSManagedObjectContext) async {
        guard let ownerId = AuthManager.shared.currentUserId else {
            progress = .failed("Not authenticated")
            return
        }

        progress = .inProgress
        migratedCount = 0

        do {
            // 1. Profile (auto-created by auth trigger — just update it)
            currentEntity = "Profile"
            try await migrateProfile(context: context, ownerId: ownerId)
            migratedCount += 1

            // 2. Persons (+ create self-referential person for current user)
            currentEntity = "Persons"
            try await migratePersons(context: context, ownerId: ownerId)
            migratedCount += 1

            // 3. User Groups
            currentEntity = "Groups"
            try await migrateGroups(context: context, ownerId: ownerId)
            migratedCount += 1

            // 4. Group Members
            currentEntity = "Group Members"
            try await migrateGroupMembers(context: context, ownerId: ownerId)
            migratedCount += 1

            // 5. Subscriptions
            currentEntity = "Subscriptions"
            try await migrateSubscriptions(context: context, ownerId: ownerId)
            migratedCount += 1

            // 6. Subscription Subscribers
            currentEntity = "Subscription Subscribers"
            try await migrateSubscriptionSubscribers(context: context, ownerId: ownerId)
            migratedCount += 1

            // 7. Financial Transactions
            currentEntity = "Transactions"
            try await migrateTransactions(context: context, ownerId: ownerId)
            migratedCount += 1

            // 8. Transaction Splits
            currentEntity = "Transaction Splits"
            try await migrateTransactionSplits(context: context, ownerId: ownerId)
            migratedCount += 1

            // 9. Transaction Payers
            currentEntity = "Transaction Payers"
            try await migrateTransactionPayers(context: context, ownerId: ownerId)
            migratedCount += 1

            // 10. Settlements
            currentEntity = "Settlements"
            try await migrateSettlements(context: context, ownerId: ownerId)
            migratedCount += 1

            // 11. Reminders
            currentEntity = "Reminders"
            try await migrateReminders(context: context, ownerId: ownerId)
            migratedCount += 1

            // 12. Chat Messages
            currentEntity = "Messages"
            try await migrateMessages(context: context, ownerId: ownerId)
            migratedCount += 1

            // 13. Subscription Payments
            currentEntity = "Subscription Payments"
            try await migrateSubscriptionPayments(context: context)
            migratedCount += 1

            // 14. Subscription Settlements
            currentEntity = "Subscription Settlements"
            try await migrateSubscriptionSettlements(context: context)
            migratedCount += 1

            // 15. Subscription Reminders
            currentEntity = "Subscription Reminders"
            try await migrateSubscriptionReminders(context: context)
            migratedCount += 1

            // Mark migration complete
            UserDefaults.standard.set(true, forKey: "supabase_migration_completed")
            progress = .completed
            totalCount = migratedCount
            logger.info("Migration completed: \(self.migratedCount) entity types migrated")

        } catch {
            progress = .failed(error.localizedDescription)
            logger.error("Migration failed at '\(self.currentEntity)': \(error.localizedDescription)")
        }
    }

    // MARK: - Individual Entity Migrations

    private func migrateProfile(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let profile = await context.perform {
            let user = CurrentUser.getOrCreate(in: context)
            return ProfileDTO(from: user, userId: ownerId)
        }
        try await dataService.updateProfile(profile)
    }

    private func migratePersons(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let dtos: [PersonDTO] = await context.perform {
            let request: NSFetchRequest<Person> = Person.fetchRequest()
            let persons = (try? context.fetch(request)) ?? []
            return persons.map { PersonDTO(from: $0, ownerId: ownerId) }
        }
        try await dataService.upsertPersons(dtos)
    }

    private func migrateGroups(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let dtos: [GroupDTO] = await context.perform {
            let request: NSFetchRequest<UserGroup> = UserGroup.fetchRequest()
            let groups = (try? context.fetch(request)) ?? []
            return groups.map { GroupDTO(from: $0, ownerId: ownerId) }
        }
        try await dataService.upsertGroups(dtos)
    }

    private func migrateGroupMembers(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let groupData: [(UUID, [UUID])] = await context.perform {
            let request: NSFetchRequest<UserGroup> = UserGroup.fetchRequest()
            let groups = (try? context.fetch(request)) ?? []
            return groups.compactMap { group in
                guard let groupId = group.id else { return nil }
                let memberIds = (group.members as? Set<Person>)?.compactMap(\.id) ?? []
                return (groupId, memberIds)
            }
        }
        for (groupId, memberIds) in groupData {
            try await dataService.setGroupMembers(groupId: groupId, personIds: memberIds)
        }
    }

    private func migrateSubscriptions(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let dtos: [SubscriptionDTO] = await context.perform {
            let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
            let subs = (try? context.fetch(request)) ?? []
            return subs.map { SubscriptionDTO(from: $0, ownerId: ownerId) }
        }
        try await dataService.upsertSubscriptions(dtos)
    }

    private func migrateSubscriptionSubscribers(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let subData: [(UUID, [UUID])] = await context.perform {
            let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
            let subs = (try? context.fetch(request)) ?? []
            return subs.compactMap { sub in
                guard let subId = sub.id else { return nil }
                let subscriberIds = (sub.subscribers as? Set<Person>)?.compactMap(\.id) ?? []
                return (subId, subscriberIds)
            }
        }
        for (subId, subscriberIds) in subData {
            try await dataService.setSubscriptionSubscribers(subscriptionId: subId, personIds: subscriberIds)
        }
    }

    private func migrateTransactions(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let dtos: [TransactionDTO] = await context.perform {
            let request: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
            let txns = (try? context.fetch(request)) ?? []
            return txns.map { TransactionDTO(from: $0, ownerId: ownerId) }
        }
        try await dataService.upsertTransactions(dtos)
    }

    private func migrateTransactionSplits(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let splitData: [(UUID, [TransactionSplitDTO])] = await context.perform {
            let request: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
            let txns = (try? context.fetch(request)) ?? []
            return txns.compactMap { txn in
                guard let txnId = txn.id else { return nil }
                let splits = (txn.splits as? Set<TransactionSplit>)?.map {
                    TransactionSplitDTO(from: $0, transactionId: txnId)
                } ?? []
                return (txnId, splits)
            }
        }
        for (txnId, splits) in splitData {
            try await dataService.replaceSplits(transactionId: txnId, splits: splits)
        }
    }

    private func migrateTransactionPayers(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let payerData: [(UUID, [TransactionPayerDTO])] = await context.perform {
            let request: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
            let txns = (try? context.fetch(request)) ?? []
            return txns.compactMap { txn in
                guard let txnId = txn.id else { return nil }
                let payers = (txn.payers as? Set<TransactionPayer>)?.map {
                    TransactionPayerDTO(from: $0, transactionId: txnId)
                } ?? []
                return (txnId, payers)
            }
        }
        for (txnId, payers) in payerData {
            try await dataService.replacePayers(transactionId: txnId, payers: payers)
        }
    }

    private func migrateSettlements(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let dtos: [SettlementDTO] = await context.perform {
            let request: NSFetchRequest<Settlement> = Settlement.fetchRequest()
            let settlements = (try? context.fetch(request)) ?? []
            return settlements.map { SettlementDTO(from: $0, ownerId: ownerId) }
        }
        try await dataService.upsertSettlements(dtos)
    }

    private func migrateReminders(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let dtos: [ReminderDTO] = await context.perform {
            let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
            let reminders = (try? context.fetch(request)) ?? []
            return reminders.map { ReminderDTO(from: $0, ownerId: ownerId) }
        }
        try await dataService.upsertReminders(dtos)
    }

    private func migrateMessages(context: NSManagedObjectContext, ownerId: UUID) async throws {
        let dtos: [MessageDTO] = await context.perform {
            let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
            let messages = (try? context.fetch(request)) ?? []
            return messages.map { MessageDTO(from: $0, ownerId: ownerId) }
        }
        try await dataService.upsertMessages(dtos)
    }

    private func migrateSubscriptionPayments(context: NSManagedObjectContext) async throws {
        let dtos: [SubscriptionPaymentDTO] = await context.perform {
            let request: NSFetchRequest<SubscriptionPayment> = SubscriptionPayment.fetchRequest()
            let payments = (try? context.fetch(request)) ?? []
            return payments.map { SubscriptionPaymentDTO(from: $0) }
        }
        try await dataService.upsertSubscriptionPayments(dtos)
    }

    private func migrateSubscriptionSettlements(context: NSManagedObjectContext) async throws {
        let dtos: [SubscriptionSettlementDTO] = await context.perform {
            let request: NSFetchRequest<SubscriptionSettlement> = SubscriptionSettlement.fetchRequest()
            let settlements = (try? context.fetch(request)) ?? []
            return settlements.map { SubscriptionSettlementDTO(from: $0) }
        }
        try await dataService.upsertSubscriptionSettlements(dtos)
    }

    private func migrateSubscriptionReminders(context: NSManagedObjectContext) async throws {
        let dtos: [SubscriptionReminderDTO] = await context.perform {
            let request: NSFetchRequest<SubscriptionReminder> = SubscriptionReminder.fetchRequest()
            let reminders = (try? context.fetch(request)) ?? []
            return reminders.map { SubscriptionReminderDTO(from: $0) }
        }
        try await dataService.upsertSubscriptionReminders(dtos)
    }
}
