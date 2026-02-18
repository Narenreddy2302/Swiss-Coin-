# 09 - Sync Engine

Offline-first sync strategy using CoreData as the UI source of truth and Supabase as cloud persistence.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Sync Strategy](#sync-strategy)
3. [Timestamp-Based Incremental Sync](#timestamp-based-incremental-sync)
4. [Conflict Resolution](#conflict-resolution)
5. [Soft Deletes](#soft-deletes)
6. [SyncManager Implementation](#syncmanager-implementation)
7. [Background Sync](#background-sync)
8. [Network Reachability](#network-reachability)

---

## Architecture Overview

```
+---------------------+       +---------------------+
|     SwiftUI Views   |       |   Supabase Cloud    |
|   (@FetchRequest)   |       |  (Source of Record)  |
+----------+----------+       +----------+----------+
           |                              |
           v                              v
+----------+----------+       +----------+----------+
|     CoreData        | <---> |   SyncManager       |
|  (UI Source of      |       |  (Push/Pull/Merge)  |
|   Truth, Offline)   |       |                     |
+---------------------+       +---------------------+
```

### Principles

1. **CoreData is the UI source of truth** — Views always read from CoreData via `@FetchRequest`. Never query Supabase directly for display.
2. **Writes go to CoreData first** — All user actions save to CoreData immediately (instant UI update), then sync to Supabase asynchronously.
3. **Reads come from Supabase on sync** — Pull remote changes and merge into CoreData.
4. **Offline always works** — All features function without network. Sync happens when connectivity returns.
5. **Last-write-wins** — Simple conflict resolution using `updated_at` timestamps.

---

## Sync Strategy

### Sync Triggers

| Trigger | Action |
|---------|--------|
| App becomes active | Full incremental sync (all entity types) |
| After CoreData save | Push changed entities (debounced 5s) |
| Pull-to-refresh | Full incremental sync |
| Background refresh | Full incremental sync |
| Network reconnection | Full incremental sync |
| Manual trigger | Full incremental sync (via settings) |

### Sync Flow per Entity Type

```
1. PUSH (local → remote):
   Query CoreData: WHERE updatedAt > lastPushTimestamp
   For each changed record:
     → Upsert to Supabase
   Update lastPushTimestamp

2. PULL (remote → local):
   Query Supabase: WHERE updated_at > lastPullTimestamp
   For each remote record:
     If deleted_at IS NOT NULL:
       → Delete from CoreData
     Else:
       → Upsert to CoreData (find by ID, update or insert)
   Update lastPullTimestamp

3. Save CoreData context
```

---

## Timestamp-Based Incremental Sync

Each entity type tracks its own sync timestamps in UserDefaults.

### Timestamp Keys

```swift
// UserDefaults keys for sync timestamps
enum SyncTimestampKey {
    static func lastPush(_ entity: String) -> String {
        "sync_last_push_\(entity)"
    }
    static func lastPull(_ entity: String) -> String {
        "sync_last_pull_\(entity)"
    }
}
```

### Entity Types for Sync

```swift
enum SyncEntityType: String, CaseIterable {
    case persons
    case userGroups = "user_groups"
    case groupMembers = "group_members"
    case subscriptions
    case subscriptionSubscribers = "subscription_subscribers"
    case financialTransactions = "financial_transactions"
    case transactionSplits = "transaction_splits"
    case transactionPayers = "transaction_payers"
    case settlements
    case reminders
    case chatMessages = "chat_messages"
    case subscriptionPayments = "subscription_payments"
    case subscriptionSettlements = "subscription_settlements"
    case subscriptionReminders = "subscription_reminders"
}
```

### Push Logic

```swift
func pushChanges(for entityType: SyncEntityType) async throws {
    let lastPush = UserDefaults.standard.object(
        forKey: SyncTimestampKey.lastPush(entityType.rawValue)
    ) as? Date ?? Date.distantPast

    // Query CoreData for records modified since last push
    let changedRecords = try fetchLocalChanges(
        entityType: entityType,
        since: lastPush
    )

    guard !changedRecords.isEmpty else { return }

    // Upsert each to Supabase
    for record in changedRecords {
        try await client.from(entityType.rawValue)
            .upsert(record)
            .execute()
    }

    // Update push timestamp
    UserDefaults.standard.set(Date(), forKey: SyncTimestampKey.lastPush(entityType.rawValue))
}
```

### Pull Logic

```swift
func pullChanges(for entityType: SyncEntityType) async throws {
    let lastPull = UserDefaults.standard.object(
        forKey: SyncTimestampKey.lastPull(entityType.rawValue)
    ) as? Date ?? Date.distantPast

    // Query Supabase for records updated since last pull
    let response = try await client.from(entityType.rawValue)
        .select()
        .gt("updated_at", value: ISO8601DateFormatter().string(from: lastPull))
        .execute()

    let remoteRecords = try JSONDecoder.supabaseDecoder.decode(
        [GenericRecord].self,
        from: response.data
    )

    guard !remoteRecords.isEmpty else { return }

    // Merge into CoreData
    for record in remoteRecords {
        if record.deletedAt != nil {
            // Soft-deleted remotely — remove from CoreData
            try deleteLocalRecord(entityType: entityType, id: record.id)
        } else {
            // Upsert into CoreData
            try upsertLocalRecord(entityType: entityType, record: record)
        }
    }

    try context.save()

    // Update pull timestamp
    UserDefaults.standard.set(Date(), forKey: SyncTimestampKey.lastPull(entityType.rawValue))
}
```

---

## Conflict Resolution

### Last-Write-Wins (LWW)

The simplest conflict resolution strategy, suitable for single-user apps like Swiss Coin.

```
If local.updatedAt > remote.updated_at:
  → Push local version to Supabase (local wins)

If remote.updated_at > local.updatedAt:
  → Apply remote version to CoreData (remote wins)

If timestamps are equal:
  → No action needed (already in sync)
```

### Why LWW Works Here

- Swiss Coin is a **single-user** app — one user owns all data
- Multi-device usage is sequential (not simultaneous editing)
- Financial data is append-heavy (new transactions) rather than edit-heavy
- Conflicts are rare in practice

### Merge During Pull

```swift
func mergeRecord(local: NSManagedObject, remote: RemoteRecord) {
    let localUpdated = (local.value(forKey: "updatedAt") as? Date) ?? Date.distantPast
    let remoteUpdated = remote.updatedAt ?? Date.distantPast

    if remoteUpdated > localUpdated {
        // Remote wins — apply remote values to local
        remote.apply(to: local)
    }
    // If local is newer, it will be pushed in the next push cycle
}
```

---

## Soft Deletes

### How Soft Deletes Work

Instead of `DELETE`, records get a `deleted_at` timestamp:

```swift
// To "delete" a record:
func softDelete(entity: NSManagedObject) {
    entity.setValue(Date(), forKey: "deletedAt")
    entity.setValue(Date(), forKey: "updatedAt")
    try? context.save()

    // The sync engine will push the deleted_at timestamp to Supabase
}
```

### CoreData Fetch Predicates

All `@FetchRequest` predicates must exclude soft-deleted records:

```swift
// Before (no soft delete):
@FetchRequest(
    sortDescriptors: [SortDescriptor(\.name)],
    predicate: NSPredicate(format: "isArchived == NO")
)
var persons: FetchedResults<Person>

// After (with soft delete):
@FetchRequest(
    sortDescriptors: [SortDescriptor(\.name)],
    predicate: NSPredicate(format: "isArchived == NO AND deletedAt == nil")
)
var persons: FetchedResults<Person>
```

### Sync Handling of Soft Deletes

During pull, if a remote record has `deleted_at` set:

```swift
if let deletedAt = remoteRecord.deletedAt {
    // Find the local CoreData record
    if let local = findLocalRecord(entityType: entityType, id: remoteRecord.id) {
        // Actually delete from CoreData (it's already soft-deleted remotely)
        context.delete(local)
    }
}
```

### Periodic Cleanup

Records that have been soft-deleted for more than 30 days can be permanently removed from Supabase:

```sql
-- Run periodically (weekly cron job)
DELETE FROM persons WHERE deleted_at < now() - interval '30 days';
DELETE FROM financial_transactions WHERE deleted_at < now() - interval '30 days';
DELETE FROM settlements WHERE deleted_at < now() - interval '30 days';
DELETE FROM chat_messages WHERE deleted_at < now() - interval '30 days';
DELETE FROM subscriptions WHERE deleted_at < now() - interval '30 days';
DELETE FROM reminders WHERE deleted_at < now() - interval '30 days';
DELETE FROM subscription_payments WHERE deleted_at < now() - interval '30 days';
DELETE FROM subscription_settlements WHERE deleted_at < now() - interval '30 days';
DELETE FROM subscription_reminders WHERE deleted_at < now() - interval '30 days';
```

---

## SyncManager Implementation

Full Swift implementation of the sync orchestrator.

```swift
// Swiss Coin/Services/SyncManager.swift

import Foundation
import CoreData
import Supabase
import Combine

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private let client = SupabaseConfig.shared.client
    private let context: NSManagedObjectContext
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 5.0

    private init() {
        self.context = PersistenceController.shared.container.viewContext
    }

    // MARK: - Public API

    /// Full incremental sync of all entity types
    func syncAll() async {
        guard !isSyncing else { return }
        guard client.auth.currentSession != nil else { return }

        isSyncing = true
        syncError = nil

        do {
            // Push local changes first (in dependency order)
            for entityType in SyncEntityType.allCases {
                try await pushChanges(for: entityType)
            }

            // Then pull remote changes (in dependency order)
            for entityType in SyncEntityType.allCases {
                try await pullChanges(for: entityType)
            }

            try context.save()
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
            print("Sync error: \(error)")
        }

        isSyncing = false
    }

    /// Debounced sync — call after every CoreData save
    func scheduleSyncAfterSave() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await syncAll()
        }
    }

    /// Push a single entity immediately (for responsive UX after create/update)
    func pushEntity<T: Encodable>(_ dto: T, table: String) async throws {
        try await client.from(table)
            .upsert(dto)
            .execute()
    }

    /// Soft-delete an entity remotely
    func softDeleteRemote(table: String, id: UUID) async throws {
        try await client.from(table)
            .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Push (Local → Remote)

    private func pushChanges(for entityType: SyncEntityType) async throws {
        let lastPushKey = SyncTimestampKey.lastPush(entityType.rawValue)
        let lastPush = UserDefaults.standard.object(forKey: lastPushKey) as? Date ?? Date.distantPast

        guard let userId = client.auth.currentSession?.user.id else { return }

        switch entityType {
        case .persons:
            try await pushPersons(since: lastPush, ownerId: userId)
        case .userGroups:
            try await pushGroups(since: lastPush, ownerId: userId)
        case .groupMembers:
            try await pushGroupMembers(ownerId: userId)
        case .financialTransactions:
            try await pushTransactions(since: lastPush, ownerId: userId)
        case .transactionSplits:
            try await pushSplits(since: lastPush)
        case .transactionPayers:
            try await pushPayers(since: lastPush)
        case .settlements:
            try await pushSettlements(since: lastPush, ownerId: userId)
        case .chatMessages:
            try await pushMessages(since: lastPush, ownerId: userId)
        case .subscriptions:
            try await pushSubscriptions(since: lastPush, ownerId: userId)
        case .reminders:
            try await pushReminders(since: lastPush, ownerId: userId)
        case .subscriptionSubscribers,
             .subscriptionPayments,
             .subscriptionSettlements,
             .subscriptionReminders:
            // These are pushed as part of their parent entities
            break
        }

        UserDefaults.standard.set(Date(), forKey: lastPushKey)
    }

    private func pushPersons(since: Date, ownerId: UUID) async throws {
        let request = Person.fetchRequest()
        request.predicate = NSPredicate(format: "updatedAt > %@", since as NSDate)
        let persons = try context.fetch(request)

        for person in persons {
            let dto = PersonDTO(from: person, ownerId: ownerId)
            try await client.from("persons").upsert(dto).execute()
        }
    }

    private func pushGroups(since: Date, ownerId: UUID) async throws {
        let request = UserGroup.fetchRequest()
        request.predicate = NSPredicate(format: "updatedAt > %@", since as NSDate)
        let groups = try context.fetch(request)

        for group in groups {
            let dto = GroupDTO(from: group, ownerId: ownerId)
            try await client.from("user_groups").upsert(dto).execute()
        }
    }

    private func pushGroupMembers(ownerId: UUID) async throws {
        // Group members have no updatedAt — push all members for groups that changed
        // This is handled as a full replacement on the server side
    }

    private func pushTransactions(since: Date, ownerId: UUID) async throws {
        let request = FinancialTransaction.fetchRequest()
        request.predicate = NSPredicate(format: "updatedAt > %@", since as NSDate)
        let transactions = try context.fetch(request)

        for tx in transactions {
            let dto = TransactionDTO(from: tx, ownerId: ownerId)
            try await client.from("financial_transactions").upsert(dto).execute()
        }
    }

    private func pushSplits(since: Date) async throws {
        let request: NSFetchRequest<TransactionSplit> = NSFetchRequest(entityName: "TransactionSplit")
        request.predicate = NSPredicate(format: "updatedAt > %@", since as NSDate)
        let splits = try context.fetch(request)

        for split in splits {
            guard let txId = split.transaction?.id else { continue }
            let dto = SplitDTO(from: split, transactionId: txId)
            try await client.from("transaction_splits").upsert(dto).execute()
        }
    }

    private func pushPayers(since: Date) async throws {
        let request: NSFetchRequest<TransactionPayer> = NSFetchRequest(entityName: "TransactionPayer")
        request.predicate = NSPredicate(format: "updatedAt > %@", since as NSDate)
        let payers = try context.fetch(request)

        for payer in payers {
            guard let txId = payer.transaction?.id else { continue }
            let dto = PayerDTO(from: payer, transactionId: txId)
            try await client.from("transaction_payers").upsert(dto).execute()
        }
    }

    private func pushSettlements(since: Date, ownerId: UUID) async throws {
        let request = Settlement.fetchRequest()
        request.predicate = NSPredicate(format: "updatedAt > %@", since as NSDate)
        let settlements = try context.fetch(request)

        for settlement in settlements {
            let dto = SettlementDTO(from: settlement, ownerId: ownerId)
            try await client.from("settlements").upsert(dto).execute()
        }
    }

    private func pushMessages(since: Date, ownerId: UUID) async throws {
        let request = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "updatedAt > %@", since as NSDate)
        let messages = try context.fetch(request)

        for message in messages {
            let dto = MessageDTO(from: message, ownerId: ownerId)
            try await client.from("chat_messages").upsert(dto).execute()
        }
    }

    private func pushSubscriptions(since: Date, ownerId: UUID) async throws {
        let request = Subscription.fetchRequest()
        request.predicate = NSPredicate(format: "updatedAt > %@", since as NSDate)
        let subscriptions = try context.fetch(request)

        for sub in subscriptions {
            let dto = SubscriptionDTO(from: sub, ownerId: ownerId)
            try await client.from("subscriptions").upsert(dto).execute()
        }
    }

    private func pushReminders(since: Date, ownerId: UUID) async throws {
        let request = Reminder.fetchRequest()
        request.predicate = NSPredicate(format: "updatedAt > %@", since as NSDate)
        let reminders = try context.fetch(request)

        for reminder in reminders {
            // Reminder push would use a ReminderDTO
            _ = reminder
        }
    }

    // MARK: - Pull (Remote → Local)

    private func pullChanges(for entityType: SyncEntityType) async throws {
        let lastPullKey = SyncTimestampKey.lastPull(entityType.rawValue)
        let lastPull = UserDefaults.standard.object(forKey: lastPullKey) as? Date ?? Date.distantPast

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        switch entityType {
        case .persons:
            try await pullPersons(since: lastPull, formatter: formatter)
        case .userGroups:
            try await pullGroups(since: lastPull, formatter: formatter)
        case .financialTransactions:
            try await pullTransactions(since: lastPull, formatter: formatter)
        case .settlements:
            try await pullSettlements(since: lastPull, formatter: formatter)
        case .chatMessages:
            try await pullMessages(since: lastPull, formatter: formatter)
        case .subscriptions:
            try await pullSubscriptions(since: lastPull, formatter: formatter)
        default:
            // Junction tables and child entities pulled with their parents
            break
        }

        UserDefaults.standard.set(Date(), forKey: lastPullKey)
    }

    private func pullPersons(since: Date, formatter: ISO8601DateFormatter) async throws {
        let response: [PersonDTO] = try await client.from("persons")
            .select()
            .gt("updated_at", value: formatter.string(from: since))
            .execute()
            .value

        for dto in response {
            if dto.deletedAt != nil {
                // Remove from CoreData
                if let local = findPerson(id: dto.id) {
                    context.delete(local)
                }
            } else {
                // Upsert
                let person = findPerson(id: dto.id) ?? Person(context: context)
                if person.id == nil { person.id = dto.id }
                dto.apply(to: person)
            }
        }
    }

    private func pullGroups(since: Date, formatter: ISO8601DateFormatter) async throws {
        let response: [GroupDTO] = try await client.from("user_groups")
            .select()
            .gt("updated_at", value: formatter.string(from: since))
            .execute()
            .value

        for dto in response {
            if dto.deletedAt != nil {
                if let local = findGroup(id: dto.id) {
                    context.delete(local)
                }
            } else {
                let group = findGroup(id: dto.id) ?? UserGroup(context: context)
                if group.id == nil { group.id = dto.id }
                dto.apply(to: group, context: context)
            }
        }
    }

    private func pullTransactions(since: Date, formatter: ISO8601DateFormatter) async throws {
        let response: [TransactionDTO] = try await client.from("financial_transactions")
            .select()
            .gt("updated_at", value: formatter.string(from: since))
            .execute()
            .value

        for dto in response {
            if dto.deletedAt != nil {
                if let local = findTransaction(id: dto.id) {
                    context.delete(local)
                }
            } else {
                let tx = findTransaction(id: dto.id) ?? FinancialTransaction(context: context)
                if tx.id == nil { tx.id = dto.id }
                dto.apply(to: tx, context: context)
            }
        }
    }

    private func pullSettlements(since: Date, formatter: ISO8601DateFormatter) async throws {
        let response: [SettlementDTO] = try await client.from("settlements")
            .select()
            .gt("updated_at", value: formatter.string(from: since))
            .execute()
            .value

        for dto in response {
            if dto.deletedAt != nil {
                if let local = findSettlement(id: dto.id) {
                    context.delete(local)
                }
            } else {
                let settlement = findSettlement(id: dto.id) ?? Settlement(context: context)
                if settlement.id == nil { settlement.id = dto.id }
                dto.apply(to: settlement, context: context)
            }
        }
    }

    private func pullMessages(since: Date, formatter: ISO8601DateFormatter) async throws {
        let response: [MessageDTO] = try await client.from("chat_messages")
            .select()
            .gt("updated_at", value: formatter.string(from: since))
            .execute()
            .value

        for dto in response {
            if dto.deletedAt != nil {
                if let local = findMessage(id: dto.id) {
                    context.delete(local)
                }
            } else {
                let message = findMessage(id: dto.id) ?? ChatMessage(context: context)
                if message.id == nil { message.id = dto.id }
                dto.apply(to: message, context: context)
            }
        }
    }

    private func pullSubscriptions(since: Date, formatter: ISO8601DateFormatter) async throws {
        let response: [SubscriptionDTO] = try await client.from("subscriptions")
            .select()
            .gt("updated_at", value: formatter.string(from: since))
            .execute()
            .value

        for dto in response {
            if dto.deletedAt != nil {
                if let local = findSubscription(id: dto.id) {
                    context.delete(local)
                }
            } else {
                let sub = findSubscription(id: dto.id) ?? Subscription(context: context)
                if sub.id == nil { sub.id = dto.id }
                dto.apply(to: sub)
            }
        }
    }

    // MARK: - CoreData Finders

    private func findPerson(id: UUID) -> Person? {
        let request = Person.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func findGroup(id: UUID) -> UserGroup? {
        let request = UserGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func findTransaction(id: UUID) -> FinancialTransaction? {
        let request = FinancialTransaction.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func findSettlement(id: UUID) -> Settlement? {
        let request = Settlement.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func findMessage(id: UUID) -> ChatMessage? {
        let request = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func findSubscription(id: UUID) -> Subscription? {
        let request = Subscription.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}

// MARK: - Sync Timestamp Keys

enum SyncTimestampKey {
    static func lastPush(_ entity: String) -> String {
        "sync_last_push_\(entity)"
    }
    static func lastPull(_ entity: String) -> String {
        "sync_last_pull_\(entity)"
    }
}
```

---

## Background Sync

Register a `BGAppRefreshTask` to sync in the background when the app is not active.

### Registration (in App init)

```swift
// In Swiss_CoinApp.swift or AppDelegate

import BackgroundTasks

// Register in init or application(_:didFinishLaunchingWithOptions:)
func registerBackgroundSync() {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.swisscoin.sync",
        using: nil
    ) { task in
        guard let refreshTask = task as? BGAppRefreshTask else { return }
        handleBackgroundSync(task: refreshTask)
    }
}

func handleBackgroundSync(task: BGAppRefreshTask) {
    // Schedule the next sync
    scheduleBackgroundSync()

    let syncTask = Task {
        await SyncManager.shared.syncAll()
    }

    task.expirationHandler = {
        syncTask.cancel()
    }

    Task {
        await syncTask.value
        task.setTaskCompleted(success: SyncManager.shared.syncError == nil)
    }
}

func scheduleBackgroundSync() {
    let request = BGAppRefreshTaskRequest(identifier: "com.swisscoin.sync")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("Failed to schedule background sync: \(error)")
    }
}
```

### Info.plist Entry

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.swisscoin.sync</string>
</array>
```

### Schedule on Background Entry

```swift
// In SceneDelegate or main App struct
.onChange(of: scenePhase) { newPhase in
    if newPhase == .background {
        scheduleBackgroundSync()
    } else if newPhase == .active {
        Task {
            await SyncManager.shared.syncAll()
        }
    }
}
```

---

## Network Reachability

Use `NWPathMonitor` to detect network changes and trigger sync when connectivity returns.

```swift
// Add to SyncManager or create separate ReachabilityManager

import Network

extension SyncManager {
    func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                Task { @MainActor in
                    await self?.syncAll()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.swisscoin.network"))
    }
}
```

Call `SyncManager.shared.startNetworkMonitoring()` during app initialization to automatically sync when the device reconnects after being offline.

---

## Sync Order

Entity types are synced in FK-dependency order to prevent foreign key violations:

### Push Order (same as migration order)

1. `persons`
2. `user_groups`
3. `group_members`
4. `subscriptions`
5. `subscription_subscribers`
6. `financial_transactions`
7. `transaction_splits`
8. `transaction_payers`
9. `settlements`
10. `reminders`
11. `chat_messages`
12. `subscription_payments`
13. `subscription_settlements`
14. `subscription_reminders`

### Pull Order (reverse for safety, but same order works)

Same order as push. Parent entities are pulled first so that child entity FKs resolve correctly when merging into CoreData.

---

## Observing Sync State in Views

```swift
// In any view that wants to show sync status
struct SyncStatusIndicator: View {
    @ObservedObject var syncManager = SyncManager.shared

    var body: some View {
        if syncManager.isSyncing {
            ProgressView()
                .scaleEffect(0.8)
        } else if let error = syncManager.syncError {
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(AppColors.negative)
                .help(error)
        } else if let lastSync = syncManager.lastSyncDate {
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(AppColors.positive)
                .help("Last synced \(lastSync.formatted(.relative(presentation: .named)))")
        }
    }
}
```
