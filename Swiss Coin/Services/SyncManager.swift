//
//  SyncManager.swift
//  Swiss Coin
//
//  Offline-first sync engine. CoreData remains the UI source of truth.
//  Pushes local changes to Supabase, pulls remote changes into CoreData.
//  Uses timestamp-based incremental sync with last-write-wins conflict resolution.
//
//  Auto-triggers sync on any CoreData save via didSaveNotification,
//  so individual Views/ViewModels don't need explicit sync calls.
//

import Combine
import CoreData
import Foundation
import Network
import os

private let logger = Logger(subsystem: "com.swisscoin", category: "sync")

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: String?

    private let dataService = SupabaseDataService.shared
    private let monitor = NWPathMonitor()
    private var isConnected = false
    private var debounceTask: Task<Void, Never>?
    private var saveObserver: NSObjectProtocol?
    private var realtimeObserver: NSObjectProtocol?
    /// Guards against re-entrant syncs (pull saves → triggers observer → infinite loop)
    private var isSyncSave = false

    private init() {
        // Monitor network connectivity
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.swisscoin.networkmonitor"))

        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncTimestamp") as? Date

        // Auto-sync on any CoreData save from the main view context
        saveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let context = notification.object as? NSManagedObjectContext else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.isSyncSave else { return }
                self.syncAll(context: context)
            }
        }

        // Trigger sync when realtime changes arrive from another device
        realtimeObserver = NotificationCenter.default.addObserver(
            forName: .supabaseRealtimeChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isSyncSave else { return }
                let context = PersistenceController.shared.container.viewContext
                self.syncAll(context: context)
            }
        }
    }

    deinit {
        if let observer = saveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = realtimeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Trigger a full sync cycle (push local changes, then pull remote changes).
    /// Debounced: collapses rapid saves into a single sync.
    func syncAll(context: NSManagedObjectContext) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            if Task.isCancelled { return }
            await performSync(context: context)
        }
    }

    /// Force immediate sync without debounce (e.g., on app launch)
    func syncNow(context: NSManagedObjectContext) async {
        await performSync(context: context)
    }

    // MARK: - Core Sync Logic

    private func performSync(context: NSManagedObjectContext) async {
        guard !isSyncing else { return }
        guard isConnected else {
            logger.info("Sync skipped — no network connection")
            return
        }
        guard AuthManager.shared.currentUserId != nil else {
            logger.info("Sync skipped — not authenticated")
            return
        }

        isSyncing = true
        syncError = nil

        do {
            let since = lastSyncTimestamp

            // Push local changes to Supabase
            try await pushChanges(context: context, since: since)

            // Pull remote changes into CoreData
            try await pullChanges(context: context, since: since)

            // Update sync timestamp
            let now = Date()
            updateLastSyncTimestamp(now)
            lastSyncDate = now
            syncError = nil

            logger.info("Sync completed successfully")
        } catch {
            syncError = error.localizedDescription
            logger.error("Sync failed: \(error.localizedDescription)")
        }

        isSyncing = false
    }

    // MARK: - Push (CoreData → Supabase)

    private func pushChanges(context: NSManagedObjectContext, since: Date?) async throws {
        guard let ownerId = AuthManager.shared.currentUserId else { return }

        // Push profile (current user → profiles table)
        let profileDTO: ProfileDTO? = await context.perform {
            let request: NSFetchRequest<Person> = Person.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", ownerId as CVarArg)
            request.fetchLimit = 1
            guard let person = (try? context.fetch(request))?.first else { return nil }
            return ProfileDTO(from: person, userId: ownerId)
        }
        if let profileDTO {
            try await dataService.updateProfile(profileDTO)
        }

        // Push persons
        let personDTOs: [PersonDTO] = await context.perform {
            let request: NSFetchRequest<Person> = Person.fetchRequest()
            let persons = (try? context.fetch(request)) ?? []
            return persons
                .filter { !CurrentUser.isCurrentUser($0.id) }
                .map { PersonDTO(from: $0, ownerId: ownerId) }
        }
        if !personDTOs.isEmpty {
            try await dataService.upsertPersons(personDTOs)
        }

        // Push groups
        let groupDTOs: [GroupDTO] = await context.perform {
            let request: NSFetchRequest<UserGroup> = UserGroup.fetchRequest()
            let groups = (try? context.fetch(request)) ?? []
            return groups.map { GroupDTO(from: $0, ownerId: ownerId) }
        }
        if !groupDTOs.isEmpty {
            try await dataService.upsertGroups(groupDTOs)
        }

        // Push group members
        let groupMemberData: [(groupId: UUID, memberIds: [UUID])] = await context.perform {
            let request: NSFetchRequest<UserGroup> = UserGroup.fetchRequest()
            let groups = (try? context.fetch(request)) ?? []
            return groups.compactMap { group in
                guard let gid = group.id else { return nil }
                let memberSet = group.members as? Set<Person> ?? []
                let ids = memberSet.compactMap { $0.id }
                return (groupId: gid, memberIds: ids)
            }
        }
        for entry in groupMemberData {
            try await dataService.setGroupMembers(groupId: entry.groupId, personIds: entry.memberIds)
        }

        // Push transactions
        let txnDTOs: [TransactionDTO] = await context.perform {
            let request: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
            let txns = (try? context.fetch(request)) ?? []
            return txns.map { TransactionDTO(from: $0, ownerId: ownerId) }
        }
        if !txnDTOs.isEmpty {
            try await dataService.upsertTransactions(txnDTOs)
        }

        // Push transaction splits & payers
        let (splitDTOs, payerDTOs): ([TransactionSplitDTO], [TransactionPayerDTO]) = await context.perform {
            let request: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
            let txns = (try? context.fetch(request)) ?? []
            var allSplits: [TransactionSplitDTO] = []
            var allPayers: [TransactionPayerDTO] = []
            for txn in txns {
                guard let txnId = txn.id else { continue }
                let splitSet = txn.splits as? Set<TransactionSplit> ?? []
                allSplits.append(contentsOf: splitSet.map { TransactionSplitDTO(from: $0, transactionId: txnId) })
                let payerSet = txn.payers as? Set<TransactionPayer> ?? []
                allPayers.append(contentsOf: payerSet.map { TransactionPayerDTO(from: $0, transactionId: txnId) })
            }
            return (allSplits, allPayers)
        }
        try await dataService.upsertSplits(splitDTOs)
        try await dataService.upsertPayers(payerDTOs)

        // Push settlements
        let settlementDTOs: [SettlementDTO] = await context.perform {
            let request: NSFetchRequest<Settlement> = Settlement.fetchRequest()
            let settlements = (try? context.fetch(request)) ?? []
            return settlements.map { SettlementDTO(from: $0, ownerId: ownerId) }
        }
        if !settlementDTOs.isEmpty {
            try await dataService.upsertSettlements(settlementDTOs)
        }

        // Push reminders
        let reminderDTOs: [ReminderDTO] = await context.perform {
            let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
            let reminders = (try? context.fetch(request)) ?? []
            return reminders.map { ReminderDTO(from: $0, ownerId: ownerId) }
        }
        if !reminderDTOs.isEmpty {
            try await dataService.upsertReminders(reminderDTOs)
        }

        // Push subscriptions
        let subDTOs: [SubscriptionDTO] = await context.perform {
            let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
            let subs = (try? context.fetch(request)) ?? []
            return subs.map { SubscriptionDTO(from: $0, ownerId: ownerId) }
        }
        if !subDTOs.isEmpty {
            try await dataService.upsertSubscriptions(subDTOs)
        }

        // Push subscription children (subscribers, payments, settlements, reminders)
        let (subSubscriberData, subPaymentDTOs, subSettlementDTOs, subReminderDTOs):
            ([(subId: UUID, personIds: [UUID])], [SubscriptionPaymentDTO], [SubscriptionSettlementDTO], [SubscriptionReminderDTO]) = await context.perform {
            let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
            let subs = (try? context.fetch(request)) ?? []
            var subscriberData: [(subId: UUID, personIds: [UUID])] = []
            var payments: [SubscriptionPaymentDTO] = []
            var settlements: [SubscriptionSettlementDTO] = []
            var reminders: [SubscriptionReminderDTO] = []
            for sub in subs {
                guard let subId = sub.id else { continue }
                let subscriberSet = sub.subscribers as? Set<Person> ?? []
                subscriberData.append((subId: subId, personIds: subscriberSet.compactMap { $0.id }))
                let paymentSet = sub.payments as? Set<SubscriptionPayment> ?? []
                payments.append(contentsOf: paymentSet.map { SubscriptionPaymentDTO(from: $0) })
                let settlementSet = sub.settlements as? Set<SubscriptionSettlement> ?? []
                settlements.append(contentsOf: settlementSet.map { SubscriptionSettlementDTO(from: $0) })
                let reminderSet = sub.reminders as? Set<SubscriptionReminder> ?? []
                reminders.append(contentsOf: reminderSet.map { SubscriptionReminderDTO(from: $0) })
            }
            return (subscriberData, payments, settlements, reminders)
        }
        for entry in subSubscriberData {
            try await dataService.setSubscriptionSubscribers(subscriptionId: entry.subId, personIds: entry.personIds)
        }
        try await dataService.upsertSubscriptionPayments(subPaymentDTOs)
        try await dataService.upsertSubscriptionSettlements(subSettlementDTOs)
        try await dataService.upsertSubscriptionReminders(subReminderDTOs)

        // Push chat messages
        let messageDTOs: [MessageDTO] = await context.perform {
            let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
            let messages = (try? context.fetch(request)) ?? []
            return messages.map { MessageDTO(from: $0, ownerId: ownerId) }
        }
        if !messageDTOs.isEmpty {
            try await dataService.upsertMessages(messageDTOs)
        }

        // Push unsynced direct messages (cross-user)
        try await ConversationService.shared.pushUnsyncedMessages(context: context)
    }

    // MARK: - Pull (Supabase → CoreData)

    private func pullChanges(context: NSManagedObjectContext, since: Date?) async throws {
        // Fetch all parent entity types from Supabase in parallel
        async let remotePersons = dataService.fetchPersons(since: since)
        async let remoteGroups = dataService.fetchGroups(since: since)
        async let remoteTransactions = dataService.fetchTransactions(since: since)
        async let remoteSettlements = dataService.fetchSettlements(since: since)
        async let remoteReminders = dataService.fetchReminders(since: since)
        async let remoteSubscriptions = dataService.fetchSubscriptions(since: since)
        async let remoteMessages = dataService.fetchMessages(since: since)

        let persons = try await remotePersons
        let groups = try await remoteGroups
        let transactions = try await remoteTransactions
        let settlements = try await remoteSettlements
        let reminders = try await remoteReminders
        let subscriptions = try await remoteSubscriptions
        let messages = try await remoteMessages

        // Fetch profile for current user
        let remoteProfile = try await dataService.fetchProfile()

        let hasRemoteChanges = remoteProfile != nil || !persons.isEmpty || !groups.isEmpty || !transactions.isEmpty
            || !settlements.isEmpty || !reminders.isEmpty || !subscriptions.isEmpty || !messages.isEmpty

        guard hasRemoteChanges else { return }

        // Fetch child entities for changed (non-deleted) parents
        let changedTxnIds = transactions.filter { $0.deletedAt == nil }.map(\.id)
        let changedGroupIds = groups.filter { $0.deletedAt == nil }.map(\.id)
        let changedSubIds = subscriptions.filter { $0.deletedAt == nil }.map(\.id)

        var remoteSplits: [UUID: [TransactionSplitDTO]] = [:]
        var remoteTxnPayers: [UUID: [TransactionPayerDTO]] = [:]
        for txnId in changedTxnIds {
            remoteSplits[txnId] = try await dataService.fetchSplits(transactionId: txnId)
            remoteTxnPayers[txnId] = try await dataService.fetchPayers(transactionId: txnId)
        }

        var remoteGroupMembers: [UUID: [GroupMemberDTO]] = [:]
        for groupId in changedGroupIds {
            remoteGroupMembers[groupId] = try await dataService.fetchGroupMembers(groupId: groupId)
        }

        var remoteSubSubscribers: [UUID: [SubscriptionSubscriberDTO]] = [:]
        var remoteSubPayments: [UUID: [SubscriptionPaymentDTO]] = [:]
        var remoteSubSettlements: [UUID: [SubscriptionSettlementDTO]] = [:]
        var remoteSubReminders: [UUID: [SubscriptionReminderDTO]] = [:]
        for subId in changedSubIds {
            remoteSubSubscribers[subId] = try await dataService.fetchSubscriptionSubscribers(subscriptionId: subId)
            remoteSubPayments[subId] = try await dataService.fetchSubscriptionPayments(subscriptionId: subId)
            remoteSubSettlements[subId] = try await dataService.fetchSubscriptionSettlements(subscriptionId: subId)
            remoteSubReminders[subId] = try await dataService.fetchSubscriptionReminders(subscriptionId: subId)
        }

        // Apply all changes to CoreData
        self.isSyncSave = true
        defer { self.isSyncSave = false }

        // Capture main-actor-isolated value before entering Sendable closure
        let currentUserId = AuthManager.shared.currentUserId

        try context.performAndWait {
            // Pull profile → current user's Person entity
            if let profileDTO = remoteProfile,
               let currentUserId {
                let currentUser = findOrCreate(Person.self, id: currentUserId, in: context)
                profileDTO.apply(to: currentUser)
            }

            // Pull persons
            for dto in persons {
                if CurrentUser.isCurrentUser(dto.id) { continue }
                if dto.deletedAt != nil {
                    deleteEntity(Person.self, id: dto.id, in: context)
                    continue
                }
                let person = findOrCreate(Person.self, id: dto.id, in: context)
                dto.apply(to: person)
            }

            // Pull groups + members
            for dto in groups {
                if dto.deletedAt != nil {
                    deleteEntity(UserGroup.self, id: dto.id, in: context)
                    continue
                }
                let group = findOrCreate(UserGroup.self, id: dto.id, in: context)
                dto.apply(to: group)

                // Replace group members
                if let memberDTOs = remoteGroupMembers[dto.id] {
                    // Remove existing members
                    if let existingMembers = group.members {
                        group.removeFromMembers(existingMembers)
                    }
                    // Add remote members
                    for memberDTO in memberDTOs {
                        if let person = findExisting(Person.self, id: memberDTO.personId, in: context) {
                            group.addToMembers(person)
                        }
                    }
                }
            }

            // Pull transactions + splits + payers
            for dto in transactions {
                if dto.deletedAt != nil {
                    deleteEntity(FinancialTransaction.self, id: dto.id, in: context)
                    continue
                }
                let txn = findOrCreate(FinancialTransaction.self, id: dto.id, in: context)
                dto.apply(to: txn)

                // Resolve relationships
                if let payerId = dto.payerId {
                    txn.payer = findExisting(Person.self, id: payerId, in: context)
                }
                if let createdById = dto.createdById {
                    txn.createdBy = findExisting(Person.self, id: createdById, in: context)
                }
                if let groupId = dto.groupId {
                    txn.group = findExisting(UserGroup.self, id: groupId, in: context)
                }

                // Replace splits
                if let splitDTOs = remoteSplits[dto.id] {
                    // Remove existing splits
                    if let existingSplits = txn.splits as? Set<TransactionSplit> {
                        for split in existingSplits { context.delete(split) }
                    }
                    // Create from remote
                    for splitDTO in splitDTOs {
                        let split = TransactionSplit(context: context)
                        splitDTO.apply(to: split)
                        split.transaction = txn
                        split.owedBy = findExisting(Person.self, id: splitDTO.owedById, in: context)
                    }
                }

                // Replace payers
                if let payerDTOs = remoteTxnPayers[dto.id] {
                    if let existingPayers = txn.payers as? Set<TransactionPayer> {
                        for payer in existingPayers { context.delete(payer) }
                    }
                    for payerDTO in payerDTOs {
                        let payer = TransactionPayer(context: context)
                        payerDTO.apply(to: payer)
                        payer.transaction = txn
                        payer.paidBy = findExisting(Person.self, id: payerDTO.paidById, in: context)
                    }
                }
            }

            // Pull settlements
            for dto in settlements {
                if dto.deletedAt != nil {
                    deleteEntity(Settlement.self, id: dto.id, in: context)
                    continue
                }
                let settlement = findOrCreate(Settlement.self, id: dto.id, in: context)
                dto.apply(to: settlement)

                settlement.fromPerson = findExisting(Person.self, id: dto.fromPersonId, in: context)
                settlement.toPerson = findExisting(Person.self, id: dto.toPersonId, in: context)
            }

            // Pull reminders
            for dto in reminders {
                let reminder = findOrCreate(Reminder.self, id: dto.id, in: context)
                dto.apply(to: reminder)
                reminder.toPerson = findExisting(Person.self, id: dto.toPersonId, in: context)
            }

            // Pull subscriptions + children
            for dto in subscriptions {
                if dto.deletedAt != nil {
                    deleteEntity(Subscription.self, id: dto.id, in: context)
                    continue
                }
                let sub = findOrCreate(Subscription.self, id: dto.id, in: context)
                dto.apply(to: sub)

                // Replace subscribers
                if let subscriberDTOs = remoteSubSubscribers[dto.id] {
                    if let existing = sub.subscribers {
                        sub.removeFromSubscribers(existing)
                    }
                    for subscriberDTO in subscriberDTOs {
                        if let person = findExisting(Person.self, id: subscriberDTO.personId, in: context) {
                            sub.addToSubscribers(person)
                        }
                    }
                }

                // Replace payments
                if let paymentDTOs = remoteSubPayments[dto.id] {
                    if let existing = sub.payments as? Set<SubscriptionPayment> {
                        for p in existing { context.delete(p) }
                    }
                    for paymentDTO in paymentDTOs {
                        let payment = SubscriptionPayment(context: context)
                        paymentDTO.apply(to: payment)
                        payment.subscription = sub
                        payment.payer = findExisting(Person.self, id: paymentDTO.payerId, in: context)
                    }
                }

                // Replace settlements
                if let settlementDTOs = remoteSubSettlements[dto.id] {
                    if let existing = sub.settlements as? Set<SubscriptionSettlement> {
                        for s in existing { context.delete(s) }
                    }
                    for settlementDTO in settlementDTOs {
                        let settlement = SubscriptionSettlement(context: context)
                        settlementDTO.apply(to: settlement)
                        settlement.subscription = sub
                        settlement.fromPerson = findExisting(Person.self, id: settlementDTO.fromPersonId, in: context)
                        settlement.toPerson = findExisting(Person.self, id: settlementDTO.toPersonId, in: context)
                    }
                }

                // Replace reminders
                if let reminderDTOs = remoteSubReminders[dto.id] {
                    if let existing = sub.reminders as? Set<SubscriptionReminder> {
                        for r in existing { context.delete(r) }
                    }
                    for reminderDTO in reminderDTOs {
                        let reminder = SubscriptionReminder(context: context)
                        reminderDTO.apply(to: reminder)
                        reminder.subscription = sub
                        reminder.toPerson = findExisting(Person.self, id: reminderDTO.toPersonId, in: context)
                    }
                }
            }

            // Pull messages
            for dto in messages {
                let msg = findOrCreate(ChatMessage.self, id: dto.id, in: context)
                dto.apply(to: msg)

                if let personId = dto.withPersonId {
                    msg.withPerson = findExisting(Person.self, id: personId, in: context)
                }
                if let groupId = dto.withGroupId {
                    msg.withGroup = findExisting(UserGroup.self, id: groupId, in: context)
                }
                if let subId = dto.withSubscriptionId {
                    msg.withSubscription = findExisting(Subscription.self, id: subId, in: context)
                }
                if let txnId = dto.onTransactionId {
                    msg.onTransaction = findExisting(FinancialTransaction.self, id: txnId, in: context)
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    // MARK: - CoreData Helpers

    private nonisolated func findOrCreate<T: NSManagedObject>(_ type: T.Type, id: UUID, in context: NSManagedObjectContext) -> T {
        let request = T.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        if let existing = (try? context.fetch(request))?.first as? T {
            return existing
        }
        return T(context: context)
    }

    private nonisolated func findExisting<T: NSManagedObject>(_ type: T.Type, id: UUID, in context: NSManagedObjectContext) -> T? {
        let request = T.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first as? T
    }

    private nonisolated func deleteEntity<T: NSManagedObject>(_ type: T.Type, id: UUID, in context: NSManagedObjectContext) {
        let request = T.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        if let existing = (try? context.fetch(request))?.first as? T {
            context.delete(existing)
        }
    }

    // MARK: - Timestamp Management

    private var lastSyncTimestamp: Date? {
        UserDefaults.standard.object(forKey: "lastSyncTimestamp") as? Date
    }

    private func updateLastSyncTimestamp(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "lastSyncTimestamp")
    }
}
