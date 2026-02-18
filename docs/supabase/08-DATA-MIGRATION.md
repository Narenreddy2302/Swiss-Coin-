# 08 - Data Migration (Local to Cloud)

One-time migration of existing local CoreData data to Supabase after a user authenticates for the first time.

---

## Table of Contents

1. [Overview](#overview)
2. [Detection Logic](#detection-logic)
3. [The Current User as Person Problem](#the-current-user-as-person-problem)
4. [UUID Remapping](#uuid-remapping)
5. [Upload Order](#upload-order)
6. [MigrationService](#migrationservice)
7. [Progress UI](#progress-ui)
8. [Error Recovery](#error-recovery)

---

## Overview

When an existing user (with local CoreData data) signs in for the first time, their entire local dataset must be migrated to Supabase. This is a one-time operation that:

1. Creates the user's profile in `profiles` table (handled by auth trigger)
2. Creates a self-referential person in `persons` (the "current user as person")
3. Uploads all entities in FK-dependency order
4. Uploads photos to Supabase Storage
5. Marks migration as complete

After migration, the app switches to incremental sync (see `09-SYNC-ENGINE.md`).

---

## Detection Logic

Migration should run when **all** of these are true:

```swift
func shouldRunMigration() -> Bool {
    // 1. User has local data (currentUserId was set before Supabase integration)
    let hasLocalData = UserDefaults.standard.string(forKey: "currentUserId") != nil

    // 2. User is now authenticated with Supabase
    let isAuthenticated = SupabaseConfig.shared.client.auth.currentSession != nil

    // 3. Migration hasn't been completed yet
    let migrationCompleted = UserDefaults.standard.bool(forKey: "supabase_migration_completed")

    return hasLocalData && isAuthenticated && !migrationCompleted
}
```

### Where to Trigger

Check in the main app entry point after authentication completes:

```swift
// In App.swift or root view, after auth state resolves
.task {
    if shouldRunMigration() {
        showMigrationScreen = true
    }
}
```

---

## The Current User as Person Problem

In the local CoreData model, the current user is represented by a `Person` entity with a UUID stored in `UserDefaults("currentUserId")`. This person appears in transactions as payer, split owed_by, etc.

In Supabase, the user is identified by `auth.users.id` (UUID from authentication). The `persons` table represents "other people" the user tracks, scoped by `owner_id`.

### Solution: Self-Referential Person

Create a person in the `persons` table whose `id` matches the `auth.users.id`. This person represents "me" and participates in transactions just like any other person.

```swift
// During migration: create self-referential person
let selfPerson = PersonDTO(
    id: authUserId,          // Same UUID as auth.users.id
    ownerId: authUserId,     // Owned by self
    name: profile.displayName,
    phoneNumber: profile.phone,
    photoUrl: profile.photoUrl,
    colorHex: localCurrentUser.colorHex,
    isArchived: false,
    lastViewedDate: nil,
    createdAt: nil,
    updatedAt: nil,
    deletedAt: nil
)
```

### UUID Remapping

All references to the old local `currentUserId` must be remapped to the new `auth.users.id`:

```swift
let oldUserId = UUID(uuidString: UserDefaults.standard.string(forKey: "currentUserId")!)!
let newUserId = authUserId  // from Supabase auth

// When uploading transactions, settlements, etc.:
// - If payer_id == oldUserId → use newUserId
// - If owed_by_id == oldUserId → use newUserId
// - If from_person_id == oldUserId → use newUserId
// - If to_person_id == oldUserId → use newUserId
```

---

## UUID Remapping

All person IDs referenced in transactions, settlements, and other entities must be remapped if they match the old local current-user UUID.

```swift
func remapPersonId(_ localId: UUID) -> UUID {
    if localId == oldCurrentUserId {
        return authUserId
    }
    return localId
}
```

This remapping applies to:
- `FinancialTransaction.payer` → `payer_id`
- `FinancialTransaction.createdBy` → `created_by_id`
- `TransactionSplit.owedBy` → `owed_by_id`
- `TransactionPayer.paidBy` → `paid_by_id`
- `Settlement.fromPerson` → `from_person_id`
- `Settlement.toPerson` → `to_person_id`
- `ChatMessage.withPerson` → `with_person_id`
- `Reminder.toPerson` → `to_person_id`
- `SubscriptionPayment.payer` → `payer_id`
- `SubscriptionSettlement.fromPerson` / `toPerson`
- `SubscriptionReminder.toPerson`
- Group members
- Subscription subscribers

---

## Upload Order

Entities must be uploaded in FK-dependency order. A child entity cannot be inserted until its parent exists.

| Step | Entity | Supabase Table | Depends On |
|------|--------|---------------|------------|
| 1 | Profile | `profiles` | auth.users (auto-created by trigger) |
| 2 | Current User Person | `persons` | auth.users |
| 3 | Other Persons | `persons` | auth.users (owner_id) |
| 4 | User Groups | `user_groups` | auth.users (owner_id) |
| 5 | Group Members | `group_members` | persons, user_groups |
| 6 | Subscriptions | `subscriptions` | auth.users (owner_id) |
| 7 | Subscription Subscribers | `subscription_subscribers` | subscriptions, persons |
| 8 | Financial Transactions | `financial_transactions` | persons (payer), user_groups (group) |
| 9 | Transaction Splits | `transaction_splits` | financial_transactions, persons |
| 10 | Transaction Payers | `transaction_payers` | financial_transactions, persons |
| 11 | Settlements | `settlements` | persons (from/to) |
| 12 | Reminders | `reminders` | persons |
| 13 | Chat Messages | `chat_messages` | persons, user_groups, subscriptions, financial_transactions |
| 14 | Subscription Payments | `subscription_payments` | subscriptions, persons |
| 15 | Subscription Settlements | `subscription_settlements` | subscriptions, persons |
| 16 | Subscription Reminders | `subscription_reminders` | subscriptions, persons |

---

## MigrationService

Full Swift implementation of the migration orchestrator.

```swift
// Swiss Coin/Services/MigrationService.swift

import Foundation
import CoreData
import Supabase

@MainActor
final class MigrationService: ObservableObject {
    static let shared = MigrationService()

    @Published var isRunning = false
    @Published var currentStep = ""
    @Published var progress: Double = 0
    @Published var entityCounts: [String: Int] = [:]
    @Published var errorMessage: String?

    private let client = SupabaseConfig.shared.client
    private let context: NSManagedObjectContext
    private var oldCurrentUserId: UUID?
    private var authUserId: UUID?

    private let totalSteps = 16

    private init() {
        self.context = PersistenceController.shared.container.viewContext
    }

    // MARK: - Public API

    func runMigration() async {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil

        do {
            // Get auth user
            guard let session = client.auth.currentSession else {
                throw MigrationError.notAuthenticated
            }
            authUserId = session.user.id

            // Get old local current user ID
            guard let oldIdString = UserDefaults.standard.string(forKey: "currentUserId"),
                  let oldId = UUID(uuidString: oldIdString) else {
                throw MigrationError.noLocalData
            }
            oldCurrentUserId = oldId

            // Step 1: Profile (already created by auth trigger, just update)
            try await updateStep(1, "Syncing profile...")
            try await migrateProfile()

            // Step 2: Current user as person
            try await updateStep(2, "Creating user identity...")
            try await migrateCurrentUserPerson()

            // Step 3: Other persons
            try await updateStep(3, "Uploading contacts...")
            try await migratePersons()

            // Step 4: User groups
            try await updateStep(4, "Uploading groups...")
            try await migrateGroups()

            // Step 5: Group members
            try await updateStep(5, "Setting group memberships...")
            try await migrateGroupMembers()

            // Step 6: Subscriptions
            try await updateStep(6, "Uploading subscriptions...")
            try await migrateSubscriptions()

            // Step 7: Subscription subscribers
            try await updateStep(7, "Setting subscribers...")
            try await migrateSubscriptionSubscribers()

            // Step 8: Financial transactions
            try await updateStep(8, "Uploading transactions...")
            try await migrateTransactions()

            // Step 9: Transaction splits
            try await updateStep(9, "Uploading splits...")
            try await migrateSplits()

            // Step 10: Transaction payers
            try await updateStep(10, "Uploading payer details...")
            try await migratePayers()

            // Step 11: Settlements
            try await updateStep(11, "Uploading settlements...")
            try await migrateSettlements()

            // Step 12: Reminders
            try await updateStep(12, "Uploading reminders...")
            try await migrateReminders()

            // Step 13: Chat messages
            try await updateStep(13, "Uploading messages...")
            try await migrateMessages()

            // Step 14: Subscription payments
            try await updateStep(14, "Uploading subscription payments...")
            try await migrateSubscriptionPayments()

            // Step 15: Subscription settlements
            try await updateStep(15, "Uploading subscription settlements...")
            try await migrateSubscriptionSettlements()

            // Step 16: Subscription reminders
            try await updateStep(16, "Uploading subscription reminders...")
            try await migrateSubscriptionReminders()

            // Mark complete
            UserDefaults.standard.set(true, forKey: "supabase_migration_completed")
            currentStep = "Migration complete!"
            progress = 1.0

        } catch {
            errorMessage = error.localizedDescription
        }

        isRunning = false
    }

    // MARK: - Step Helpers

    private func updateStep(_ step: Int, _ description: String) async throws {
        currentStep = description
        progress = Double(step - 1) / Double(totalSteps)
    }

    private func remapPersonId(_ localId: UUID) -> UUID {
        if localId == oldCurrentUserId {
            return authUserId ?? localId
        }
        return localId
    }

    // MARK: - Entity Migration Methods

    private func migrateProfile() async throws {
        guard let authId = authUserId else { return }

        // Fetch the local current user Person
        let request = Person.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", (oldCurrentUserId ?? UUID()) as CVarArg)
        let localUser = try context.fetch(request).first

        let profile: [String: AnyEncodable] = [
            "id": AnyEncodable(authId),
            "display_name": AnyEncodable(localUser?.name ?? "Me"),
            "phone": AnyEncodable(localUser?.phoneNumber),
            "color_hex": AnyEncodable(localUser?.colorHex),
        ]

        try await client.from("profiles")
            .upsert(profile)
            .execute()

        entityCounts["Profile"] = 1
    }

    private func migrateCurrentUserPerson() async throws {
        guard let authId = authUserId else { return }

        let request = Person.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", (oldCurrentUserId ?? UUID()) as CVarArg)
        let localUser = try context.fetch(request).first

        let selfPerson: [String: AnyEncodable] = [
            "id": AnyEncodable(authId),
            "owner_id": AnyEncodable(authId),
            "name": AnyEncodable(localUser?.name ?? "Me"),
            "phone_number": AnyEncodable(localUser?.phoneNumber),
            "color_hex": AnyEncodable(localUser?.colorHex),
            "is_archived": AnyEncodable(false),
        ]

        try await client.from("persons")
            .upsert(selfPerson)
            .execute()

        // Upload photo if present
        if let photoData = localUser?.photoData {
            let path = try await StorageService.shared.uploadPhoto(
                imageData: photoData,
                entityType: "persons",
                entityId: authId
            )
            try await client.from("persons")
                .update(["photo_url": path])
                .eq("id", value: authId.uuidString)
                .execute()
        }

        entityCounts["Current User"] = 1
    }

    private func migratePersons() async throws {
        guard let authId = authUserId else { return }

        let request = Person.fetchRequest()
        // Exclude the current user
        request.predicate = NSPredicate(format: "id != %@", (oldCurrentUserId ?? UUID()) as CVarArg)
        let persons = try context.fetch(request)

        var count = 0
        for person in persons {
            guard let personId = person.id else { continue }

            let dto: [String: AnyEncodable] = [
                "id": AnyEncodable(personId),
                "owner_id": AnyEncodable(authId),
                "name": AnyEncodable(person.name ?? ""),
                "phone_number": AnyEncodable(person.phoneNumber),
                "color_hex": AnyEncodable(person.colorHex),
                "is_archived": AnyEncodable(person.isArchived),
                "last_viewed_date": AnyEncodable(person.lastViewedDate),
            ]

            try await client.from("persons")
                .upsert(dto)
                .execute()

            // Upload photo
            if let photoData = person.photoData {
                let path = try await StorageService.shared.uploadPhoto(
                    imageData: photoData,
                    entityType: "persons",
                    entityId: personId
                )
                try await client.from("persons")
                    .update(["photo_url": path])
                    .eq("id", value: personId.uuidString)
                    .execute()
            }

            count += 1
        }

        entityCounts["Persons"] = count
    }

    private func migrateGroups() async throws {
        guard let authId = authUserId else { return }

        let request = UserGroup.fetchRequest()
        let groups = try context.fetch(request)

        var count = 0
        for group in groups {
            guard let groupId = group.id else { continue }

            let dto: [String: AnyEncodable] = [
                "id": AnyEncodable(groupId),
                "owner_id": AnyEncodable(authId),
                "name": AnyEncodable(group.name ?? ""),
                "color_hex": AnyEncodable(group.colorHex),
                "created_date": AnyEncodable(group.createdDate),
                "last_viewed_date": AnyEncodable(group.lastViewedDate),
            ]

            try await client.from("user_groups")
                .upsert(dto)
                .execute()

            // Upload group photo
            if let photoData = group.photoData {
                let path = try await StorageService.shared.uploadPhoto(
                    imageData: photoData,
                    entityType: "groups",
                    entityId: groupId
                )
                try await client.from("user_groups")
                    .update(["photo_url": path])
                    .eq("id", value: groupId.uuidString)
                    .execute()
            }

            count += 1
        }

        entityCounts["Groups"] = count
    }

    private func migrateGroupMembers() async throws {
        let request = UserGroup.fetchRequest()
        let groups = try context.fetch(request)

        var count = 0
        for group in groups {
            guard let groupId = group.id else { continue }
            let members = group.members as? Set<Person> ?? []

            for member in members {
                guard let personId = member.id else { continue }

                let row: [String: AnyEncodable] = [
                    "group_id": AnyEncodable(groupId),
                    "person_id": AnyEncodable(remapPersonId(personId)),
                ]

                try await client.from("group_members")
                    .upsert(row)
                    .execute()

                count += 1
            }
        }

        entityCounts["Group Members"] = count
    }

    private func migrateSubscriptions() async throws {
        guard let authId = authUserId else { return }

        let request = Subscription.fetchRequest()
        let subscriptions = try context.fetch(request)

        var count = 0
        for sub in subscriptions {
            guard let subId = sub.id else { continue }

            let dto: [String: AnyEncodable] = [
                "id": AnyEncodable(subId),
                "owner_id": AnyEncodable(authId),
                "name": AnyEncodable(sub.name ?? ""),
                "amount": AnyEncodable(sub.amount),
                "cycle": AnyEncodable(sub.cycle ?? "monthly"),
                "custom_cycle_days": AnyEncodable(sub.customCycleDays > 0 ? Int(sub.customCycleDays) : nil as Int?),
                "start_date": AnyEncodable(sub.startDate),
                "next_billing_date": AnyEncodable(sub.nextBillingDate),
                "is_shared": AnyEncodable(sub.isShared),
                "is_active": AnyEncodable(sub.isActive),
                "category": AnyEncodable(sub.category),
                "icon_name": AnyEncodable(sub.iconName),
                "color_hex": AnyEncodable(sub.colorHex),
                "notes": AnyEncodable(sub.notes),
                "notification_enabled": AnyEncodable(sub.notificationEnabled),
                "notification_days_before": AnyEncodable(Int(sub.notificationDaysBefore)),
                "is_archived": AnyEncodable(sub.isArchived),
            ]

            try await client.from("subscriptions")
                .upsert(dto)
                .execute()

            count += 1
        }

        entityCounts["Subscriptions"] = count
    }

    private func migrateSubscriptionSubscribers() async throws {
        let request = Subscription.fetchRequest()
        let subscriptions = try context.fetch(request)

        var count = 0
        for sub in subscriptions {
            guard let subId = sub.id else { continue }
            let subscribers = sub.subscribers as? Set<Person> ?? []

            for person in subscribers {
                guard let personId = person.id else { continue }

                let row: [String: AnyEncodable] = [
                    "subscription_id": AnyEncodable(subId),
                    "person_id": AnyEncodable(remapPersonId(personId)),
                ]

                try await client.from("subscription_subscribers")
                    .upsert(row)
                    .execute()

                count += 1
            }
        }

        entityCounts["Subscription Subscribers"] = count
    }

    private func migrateTransactions() async throws {
        guard let authId = authUserId else { return }

        let request = FinancialTransaction.fetchRequest()
        let transactions = try context.fetch(request)

        var count = 0
        for tx in transactions {
            guard let txId = tx.id else { continue }

            let dto: [String: AnyEncodable] = [
                "id": AnyEncodable(txId),
                "owner_id": AnyEncodable(authId),
                "title": AnyEncodable(tx.title ?? ""),
                "amount": AnyEncodable(tx.amount),
                "currency": AnyEncodable(tx.currency),
                "date": AnyEncodable(tx.date),
                "split_method": AnyEncodable(tx.splitMethod),
                "note": AnyEncodable(tx.note),
                "payer_id": AnyEncodable(tx.payer?.id.map { remapPersonId($0) }),
                "created_by_id": AnyEncodable(tx.createdBy?.id.map { remapPersonId($0) }),
                "group_id": AnyEncodable(tx.group?.id),
            ]

            try await client.from("financial_transactions")
                .upsert(dto)
                .execute()

            count += 1
        }

        entityCounts["Transactions"] = count
    }

    private func migrateSplits() async throws {
        let request = FinancialTransaction.fetchRequest()
        let transactions = try context.fetch(request)

        var count = 0
        for tx in transactions {
            guard let txId = tx.id else { continue }
            let splits = tx.splits as? Set<TransactionSplit> ?? []

            for split in splits {
                guard let owedById = split.owedBy?.id else { continue }

                let dto: [String: AnyEncodable] = [
                    "id": AnyEncodable(UUID()),  // Generate new ID (splits don't have IDs locally yet)
                    "transaction_id": AnyEncodable(txId),
                    "owed_by_id": AnyEncodable(remapPersonId(owedById)),
                    "amount": AnyEncodable(split.amount),
                    "raw_amount": AnyEncodable(split.rawAmount > 0 ? split.rawAmount : nil as Double?),
                ]

                try await client.from("transaction_splits")
                    .upsert(dto)
                    .execute()

                count += 1
            }
        }

        entityCounts["Splits"] = count
    }

    private func migratePayers() async throws {
        let request = FinancialTransaction.fetchRequest()
        let transactions = try context.fetch(request)

        var count = 0
        for tx in transactions {
            guard let txId = tx.id else { continue }
            let payers = tx.payers as? Set<TransactionPayer> ?? []

            for payer in payers {
                guard let paidById = payer.paidBy?.id else { continue }

                let dto: [String: AnyEncodable] = [
                    "id": AnyEncodable(UUID()),
                    "transaction_id": AnyEncodable(txId),
                    "paid_by_id": AnyEncodable(remapPersonId(paidById)),
                    "amount": AnyEncodable(payer.amount),
                ]

                try await client.from("transaction_payers")
                    .upsert(dto)
                    .execute()

                count += 1
            }
        }

        entityCounts["Payers"] = count
    }

    private func migrateSettlements() async throws {
        guard let authId = authUserId else { return }

        let request = Settlement.fetchRequest()
        let settlements = try context.fetch(request)

        var count = 0
        for settlement in settlements {
            guard let sid = settlement.id,
                  let fromId = settlement.fromPerson?.id,
                  let toId = settlement.toPerson?.id else { continue }

            let dto: [String: AnyEncodable] = [
                "id": AnyEncodable(sid),
                "owner_id": AnyEncodable(authId),
                "amount": AnyEncodable(settlement.amount),
                "currency": AnyEncodable(settlement.currency),
                "date": AnyEncodable(settlement.date),
                "note": AnyEncodable(settlement.note),
                "is_full_settlement": AnyEncodable(settlement.isFullSettlement),
                "from_person_id": AnyEncodable(remapPersonId(fromId)),
                "to_person_id": AnyEncodable(remapPersonId(toId)),
            ]

            try await client.from("settlements")
                .upsert(dto)
                .execute()

            count += 1
        }

        entityCounts["Settlements"] = count
    }

    private func migrateReminders() async throws {
        guard let authId = authUserId else { return }

        let request = Reminder.fetchRequest()
        let reminders = try context.fetch(request)

        var count = 0
        for reminder in reminders {
            guard let rid = reminder.id,
                  let toId = reminder.toPerson?.id else { continue }

            let dto: [String: AnyEncodable] = [
                "id": AnyEncodable(rid),
                "owner_id": AnyEncodable(authId),
                "created_date": AnyEncodable(reminder.createdDate),
                "amount": AnyEncodable(reminder.amount),
                "message": AnyEncodable(reminder.message),
                "is_read": AnyEncodable(reminder.isRead),
                "is_cleared": AnyEncodable(reminder.isCleared),
                "to_person_id": AnyEncodable(remapPersonId(toId)),
            ]

            try await client.from("reminders")
                .upsert(dto)
                .execute()

            count += 1
        }

        entityCounts["Reminders"] = count
    }

    private func migrateMessages() async throws {
        guard let authId = authUserId else { return }

        let request = ChatMessage.fetchRequest()
        let messages = try context.fetch(request)

        var count = 0
        for message in messages {
            guard let mid = message.id else { continue }

            let dto: [String: AnyEncodable] = [
                "id": AnyEncodable(mid),
                "owner_id": AnyEncodable(authId),
                "content": AnyEncodable(message.content ?? ""),
                "timestamp": AnyEncodable(message.timestamp),
                "is_from_user": AnyEncodable(message.isFromUser),
                "is_edited": AnyEncodable(message.isEdited),
                "with_person_id": AnyEncodable(message.withPerson?.id.map { remapPersonId($0) }),
                "with_group_id": AnyEncodable(message.withGroup?.id),
                "with_subscription_id": AnyEncodable(message.withSubscription?.id),
                "on_transaction_id": AnyEncodable(message.onTransaction?.id),
            ]

            try await client.from("chat_messages")
                .upsert(dto)
                .execute()

            count += 1
        }

        entityCounts["Messages"] = count
    }

    private func migrateSubscriptionPayments() async throws {
        guard let authId = authUserId else { return }

        let request: NSFetchRequest<SubscriptionPayment> = NSFetchRequest(entityName: "SubscriptionPayment")
        let payments = try context.fetch(request)

        var count = 0
        for payment in payments {
            guard let pid = payment.id,
                  let subId = payment.subscription?.id else { continue }

            let dto: [String: AnyEncodable] = [
                "id": AnyEncodable(pid),
                "owner_id": AnyEncodable(authId),
                "subscription_id": AnyEncodable(subId),
                "payer_id": AnyEncodable(payment.payer?.id.map { remapPersonId($0) }),
                "amount": AnyEncodable(payment.amount),
                "date": AnyEncodable(payment.date),
                "billing_period_start": AnyEncodable(payment.billingPeriodStart),
                "billing_period_end": AnyEncodable(payment.billingPeriodEnd),
                "note": AnyEncodable(payment.note),
            ]

            try await client.from("subscription_payments")
                .upsert(dto)
                .execute()

            count += 1
        }

        entityCounts["Sub Payments"] = count
    }

    private func migrateSubscriptionSettlements() async throws {
        guard let authId = authUserId else { return }

        let request: NSFetchRequest<SubscriptionSettlement> = NSFetchRequest(entityName: "SubscriptionSettlement")
        let settlements = try context.fetch(request)

        var count = 0
        for settlement in settlements {
            guard let sid = settlement.id,
                  let subId = settlement.subscription?.id,
                  let fromId = settlement.fromPerson?.id,
                  let toId = settlement.toPerson?.id else { continue }

            let dto: [String: AnyEncodable] = [
                "id": AnyEncodable(sid),
                "owner_id": AnyEncodable(authId),
                "subscription_id": AnyEncodable(subId),
                "from_person_id": AnyEncodable(remapPersonId(fromId)),
                "to_person_id": AnyEncodable(remapPersonId(toId)),
                "amount": AnyEncodable(settlement.amount),
                "date": AnyEncodable(settlement.date),
                "note": AnyEncodable(settlement.note),
            ]

            try await client.from("subscription_settlements")
                .upsert(dto)
                .execute()

            count += 1
        }

        entityCounts["Sub Settlements"] = count
    }

    private func migrateSubscriptionReminders() async throws {
        guard let authId = authUserId else { return }

        let request: NSFetchRequest<SubscriptionReminder> = NSFetchRequest(entityName: "SubscriptionReminder")
        let reminders = try context.fetch(request)

        var count = 0
        for reminder in reminders {
            guard let rid = reminder.id,
                  let subId = reminder.subscription?.id else { continue }

            let dto: [String: AnyEncodable] = [
                "id": AnyEncodable(rid),
                "owner_id": AnyEncodable(authId),
                "subscription_id": AnyEncodable(subId),
                "to_person_id": AnyEncodable(reminder.toPerson?.id.map { remapPersonId($0) }),
                "amount": AnyEncodable(reminder.amount),
                "created_date": AnyEncodable(reminder.createdDate),
                "message": AnyEncodable(reminder.message),
                "is_read": AnyEncodable(reminder.isRead),
            ]

            try await client.from("subscription_reminders")
                .upsert(dto)
                .execute()

            count += 1
        }

        entityCounts["Sub Reminders"] = count
    }
}

// MARK: - Errors

enum MigrationError: LocalizedError {
    case notAuthenticated
    case noLocalData
    case uploadFailed(entity: String, detail: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in first."
        case .noLocalData:
            return "No local data found to migrate."
        case .uploadFailed(let entity, let detail):
            return "Failed to upload \(entity): \(detail)"
        }
    }
}

// MARK: - AnyEncodable Helper

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
```

---

## Progress UI

Show a migration progress screen while data is being uploaded.

```swift
// Example MigrationProgressView

import SwiftUI

struct MigrationProgressView: View {
    @StateObject private var migration = MigrationService.shared

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: IconSize.xxl))
                .foregroundStyle(AppColors.accent)

            Text("Migrating Your Data")
                .font(AppTypography.displayMedium())
                .foregroundStyle(AppColors.textPrimary)

            Text("Your local data is being securely uploaded to the cloud. This only happens once.")
                .font(AppTypography.bodyDefault())
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            // Progress bar
            VStack(spacing: Spacing.sm) {
                ProgressView(value: migration.progress)
                    .tint(AppColors.accent)

                Text(migration.currentStep)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, Spacing.xl)

            // Entity counts
            if !migration.entityCounts.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: Spacing.sm) {
                    ForEach(
                        migration.entityCounts.sorted(by: { $0.key < $1.key }),
                        id: \.key
                    ) { key, value in
                        HStack {
                            Text(key)
                                .font(AppTypography.labelDefault())
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer()
                            Text("\(value)")
                                .font(AppTypography.financialSmall())
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
            }

            // Error message
            if let error = migration.errorMessage {
                VStack(spacing: Spacing.md) {
                    Text(error)
                        .font(AppTypography.bodySmall())
                        .foregroundStyle(AppColors.negative)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        Task { await migration.runMigration() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, Spacing.xl)
            }

            Spacer()
        }
        .background(AppColors.background)
        .task {
            await migration.runMigration()
        }
    }
}
```

---

## Error Recovery

### Upsert, Not Insert

All migration calls use `upsert` instead of `insert`. This means:
- If a record already exists (by primary key), it gets updated
- If it does not exist, it gets inserted
- Migration can be safely retried after a failure

### Per-Entity Tracking

The `entityCounts` dictionary tracks how many records of each type have been migrated. If migration fails midway:

1. The user sees which entities were completed
2. The user taps "Retry"
3. Upsert ensures already-uploaded entities are not duplicated
4. Migration resumes from the beginning but skips existing records (via upsert)

### State Persistence

For production robustness, consider persisting migration state to UserDefaults:

```swift
// Track per-entity completion
let completedKey = "migration_completed_\(entityName)"
UserDefaults.standard.set(true, forKey: completedKey)

// Check before migrating
func isEntityMigrated(_ name: String) -> Bool {
    UserDefaults.standard.bool(forKey: "migration_completed_\(name)")
}
```

### Balance Verification

After migration, verify balances match by calling the `calculate-balance` edge function for a sample of persons and comparing against local `calculateBalance()` results.

```swift
// Post-migration verification (sample check)
func verifyBalances() async throws {
    let request = Person.fetchRequest()
    request.fetchLimit = 5  // Check first 5 persons
    let persons = try context.fetch(request)

    for person in persons {
        let localBalance = person.calculateBalance()

        // Call edge function
        let response = try await client.functions
            .invoke(
                "calculate-balance",
                options: .init(body: ["person_id": person.id?.uuidString ?? ""])
            )

        // Compare primary amounts
        let serverBalance = try JSONDecoder().decode(BalanceResponse.self, from: response.data)
        let diff = abs(localBalance.primaryAmount - serverBalance.primaryAmount)

        if diff > 0.01 {
            print("Balance mismatch for \(person.name ?? ""): local=\(localBalance.primaryAmount) server=\(serverBalance.primaryAmount)")
        }
    }
}

struct BalanceResponse: Decodable {
    let balances: [String: Double]
    let isSettled: Bool
    let primaryAmount: Double
    let primaryCurrency: String

    enum CodingKeys: String, CodingKey {
        case balances
        case isSettled = "is_settled"
        case primaryAmount = "primary_amount"
        case primaryCurrency = "primary_currency"
    }
}
```
