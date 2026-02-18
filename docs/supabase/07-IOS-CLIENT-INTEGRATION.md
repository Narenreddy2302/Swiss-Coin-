# 07 - iOS Client Integration

Supabase SDK setup, service layer, DTOs, and CoreData model changes for offline-first cloud sync.

---

## Table of Contents

1. [SDK Installation](#sdk-installation)
2. [New Files Overview](#new-files-overview)
3. [SupabaseConfig](#supabaseconfig)
4. [RemoteDataService Protocol](#remotedataservice-protocol)
5. [DTOs (Data Transfer Objects)](#dtos)
6. [StorageService](#storageservice)
7. [ViewModel Changes](#viewmodel-changes)
8. [CoreData Model v7 Changes](#coredata-model-v7-changes)

---

## SDK Installation

### Swift Package Manager

1. In Xcode: **File > Add Package Dependencies...**
2. URL: `https://github.com/supabase/supabase-swift`
3. Version: **2.x** (Up to Next Major)
4. Select product: **Supabase** (the umbrella framework)

This includes: `Auth`, `PostgREST`, `Realtime`, `Storage`, `Functions`.

### Target Configuration

Add `Supabase` to the Swiss Coin target's **Frameworks, Libraries, and Embedded Content**.

---

## New Files Overview

14 new Swift files to add to the project:

| File | Directory | Purpose |
|------|-----------|---------|
| `SupabaseConfig.swift` | `Swiss Coin/Services/` | Client singleton, URL + anon key |
| `RemoteDataService.swift` | `Swiss Coin/Services/` | Protocol for remote CRUD operations |
| `SupabaseDataService.swift` | `Swiss Coin/Services/` | Protocol implementation using Supabase |
| `SyncManager.swift` | `Swiss Coin/Services/` | Offline-first sync orchestration |
| `StorageService.swift` | `Swiss Coin/Services/` | Photo upload/download via Supabase Storage |
| `MigrationService.swift` | `Swiss Coin/Services/` | Local-to-cloud data migration |
| `PersonDTO.swift` | `Swiss Coin/Models/DTOs/` | Person ↔ Supabase mapping |
| `TransactionDTO.swift` | `Swiss Coin/Models/DTOs/` | FinancialTransaction ↔ Supabase mapping |
| `SplitDTO.swift` | `Swiss Coin/Models/DTOs/` | TransactionSplit ↔ Supabase mapping |
| `PayerDTO.swift` | `Swiss Coin/Models/DTOs/` | TransactionPayer ↔ Supabase mapping |
| `SettlementDTO.swift` | `Swiss Coin/Models/DTOs/` | Settlement ↔ Supabase mapping |
| `GroupDTO.swift` | `Swiss Coin/Models/DTOs/` | UserGroup ↔ Supabase mapping |
| `MessageDTO.swift` | `Swiss Coin/Models/DTOs/` | ChatMessage ↔ Supabase mapping |
| `SubscriptionDTO.swift` | `Swiss Coin/Models/DTOs/` | Subscription ↔ Supabase mapping |

---

## SupabaseConfig

Singleton providing the configured Supabase client.

```swift
// Swiss Coin/Services/SupabaseConfig.swift

import Foundation
import Supabase

final class SupabaseConfig {
    static let shared = SupabaseConfig()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://fgcjijairsikaeshpiof.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZnY2ppamFpcnNpa2Flc2hwaW9mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNzg0ODIsImV4cCI6MjA4Njk1NDQ4Mn0.Ivyy6jPxRlwd6PTuXoRHHikBYai0XUlbvLT8edvSxFA",
            options: SupabaseClientOptions(
                auth: .init(
                    storage: KeychainAuthStorage(),
                    flowType: .pkce
                )
            )
        )
    }
}

/// Store auth tokens in Keychain for persistence across app launches
final class KeychainAuthStorage: AuthLocalStorage {
    private let service = "com.swisscoin.auth"

    func store(key: String, value: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = value
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status))
        }
    }

    func retrieve(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status))
        }
        return result as? Data
    }

    func remove(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

---

## RemoteDataService Protocol

Defines the contract for all remote data operations. The app interacts with this protocol, not Supabase directly.

```swift
// Swiss Coin/Services/RemoteDataService.swift

import Foundation

protocol RemoteDataService {
    // MARK: - Persons
    func fetchPersons(since: Date?) async throws -> [PersonDTO]
    func upsertPerson(_ dto: PersonDTO) async throws
    func deletePerson(_ id: UUID) async throws

    // MARK: - Groups
    func fetchGroups(since: Date?) async throws -> [GroupDTO]
    func upsertGroup(_ dto: GroupDTO) async throws
    func deleteGroup(_ id: UUID) async throws
    func setGroupMembers(groupId: UUID, personIds: [UUID]) async throws

    // MARK: - Transactions
    func fetchTransactions(since: Date?) async throws -> [TransactionDTO]
    func upsertTransaction(_ dto: TransactionDTO) async throws
    func deleteTransaction(_ id: UUID) async throws

    // MARK: - Splits
    func fetchSplits(since: Date?) async throws -> [SplitDTO]
    func upsertSplits(_ dtos: [SplitDTO], forTransaction transactionId: UUID) async throws

    // MARK: - Payers
    func fetchPayers(since: Date?) async throws -> [PayerDTO]
    func upsertPayers(_ dtos: [PayerDTO], forTransaction transactionId: UUID) async throws

    // MARK: - Settlements
    func fetchSettlements(since: Date?) async throws -> [SettlementDTO]
    func upsertSettlement(_ dto: SettlementDTO) async throws
    func deleteSettlement(_ id: UUID) async throws

    // MARK: - Messages
    func fetchMessages(since: Date?) async throws -> [MessageDTO]
    func upsertMessage(_ dto: MessageDTO) async throws
    func deleteMessage(_ id: UUID) async throws

    // MARK: - Subscriptions
    func fetchSubscriptions(since: Date?) async throws -> [SubscriptionDTO]
    func upsertSubscription(_ dto: SubscriptionDTO) async throws
    func deleteSubscription(_ id: UUID) async throws

    // MARK: - Full Sync
    func performFullSync() async throws
}
```

---

## DTOs

All DTOs follow the same pattern:
- `Codable` with `CodingKeys` for snake_case ↔ camelCase mapping
- `init(from:)` constructor that converts from CoreData entity
- `apply(to:context:)` method that writes DTO values back to CoreData entity
- ISO 8601 dates, UUID identifiers

### PersonDTO

```swift
// Swiss Coin/Models/DTOs/PersonDTO.swift

import Foundation
import CoreData

struct PersonDTO: Codable, Identifiable {
    let id: UUID
    var ownerId: UUID
    var name: String
    var phoneNumber: String?
    var photoUrl: String?
    var colorHex: String?
    var isArchived: Bool
    var lastViewedDate: Date?
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case phoneNumber = "phone_number"
        case photoUrl = "photo_url"
        case colorHex = "color_hex"
        case isArchived = "is_archived"
        case lastViewedDate = "last_viewed_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(from person: Person, ownerId: UUID) {
        self.id = person.id ?? UUID()
        self.ownerId = ownerId
        self.name = person.name ?? ""
        self.phoneNumber = person.phoneNumber
        self.photoUrl = nil  // Set separately via StorageService
        self.colorHex = person.colorHex
        self.isArchived = person.isArchived
        self.lastViewedDate = person.lastViewedDate
        self.createdAt = nil  // Server-managed
        self.updatedAt = nil  // Server-managed
        self.deletedAt = nil
    }

    func apply(to person: Person) {
        person.name = name
        person.phoneNumber = phoneNumber
        person.colorHex = colorHex
        person.isArchived = isArchived
        person.lastViewedDate = lastViewedDate
        // photoUrl handled separately — download image and set photoData
    }
}
```

### TransactionDTO

```swift
// Swiss Coin/Models/DTOs/TransactionDTO.swift

import Foundation
import CoreData

struct TransactionDTO: Codable, Identifiable {
    let id: UUID
    var ownerId: UUID
    var title: String
    var amount: Double
    var currency: String?
    var date: Date
    var splitMethod: String?
    var note: String?
    var payerId: UUID?
    var createdById: UUID?
    var groupId: UUID?
    var createdAt: Date?
    var updatedAt: Date?
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
        self.createdAt = nil
        self.updatedAt = nil
        self.deletedAt = nil
    }

    func apply(to transaction: FinancialTransaction, context: NSManagedObjectContext) {
        transaction.title = title
        transaction.amount = amount
        transaction.currency = currency
        transaction.date = date
        transaction.splitMethod = splitMethod
        transaction.note = note

        // Resolve relationships by ID
        if let payerId = payerId {
            transaction.payer = fetchPerson(id: payerId, context: context)
        }
        if let createdById = createdById {
            transaction.createdBy = fetchPerson(id: createdById, context: context)
        }
        if let groupId = groupId {
            transaction.group = fetchGroup(id: groupId, context: context)
        }
    }

    private func fetchPerson(id: UUID, context: NSManagedObjectContext) -> Person? {
        let request = Person.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchGroup(id: UUID, context: NSManagedObjectContext) -> UserGroup? {
        let request = UserGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
```

### SplitDTO

```swift
// Swiss Coin/Models/DTOs/SplitDTO.swift

import Foundation
import CoreData

struct SplitDTO: Codable, Identifiable {
    let id: UUID
    var transactionId: UUID
    var owedById: UUID
    var amount: Double
    var rawAmount: Double?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case owedById = "owed_by_id"
        case amount
        case rawAmount = "raw_amount"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from split: TransactionSplit, transactionId: UUID) {
        self.id = UUID()  // TransactionSplit has no id in current model — generate one
        self.transactionId = transactionId
        self.owedById = split.owedBy?.id ?? UUID()
        self.amount = split.amount
        self.rawAmount = split.rawAmount > 0 ? split.rawAmount : nil
        self.createdAt = nil
        self.updatedAt = nil
    }

    func apply(to split: TransactionSplit, context: NSManagedObjectContext) {
        split.amount = amount
        split.rawAmount = rawAmount ?? 0

        if let person = fetchPerson(id: owedById, context: context) {
            split.owedBy = person
        }
    }

    private func fetchPerson(id: UUID, context: NSManagedObjectContext) -> Person? {
        let request = Person.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
```

### PayerDTO

```swift
// Swiss Coin/Models/DTOs/PayerDTO.swift

import Foundation
import CoreData

struct PayerDTO: Codable, Identifiable {
    let id: UUID
    var transactionId: UUID
    var paidById: UUID
    var amount: Double
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case paidById = "paid_by_id"
        case amount
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from payer: TransactionPayer, transactionId: UUID) {
        self.id = UUID()  // TransactionPayer has no id in current model — generate one
        self.transactionId = transactionId
        self.paidById = payer.paidBy?.id ?? UUID()
        self.amount = payer.amount
        self.createdAt = nil
        self.updatedAt = nil
    }

    func apply(to payer: TransactionPayer, context: NSManagedObjectContext) {
        payer.amount = amount

        if let person = fetchPerson(id: paidById, context: context) {
            payer.paidBy = person
        }
    }

    private func fetchPerson(id: UUID, context: NSManagedObjectContext) -> Person? {
        let request = Person.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
```

### SettlementDTO

```swift
// Swiss Coin/Models/DTOs/SettlementDTO.swift

import Foundation
import CoreData

struct SettlementDTO: Codable, Identifiable {
    let id: UUID
    var ownerId: UUID
    var amount: Double
    var currency: String?
    var date: Date
    var note: String?
    var isFullSettlement: Bool
    var fromPersonId: UUID
    var toPersonId: UUID
    var createdAt: Date?
    var updatedAt: Date?
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
        self.createdAt = nil
        self.updatedAt = nil
        self.deletedAt = nil
    }

    func apply(to settlement: Settlement, context: NSManagedObjectContext) {
        settlement.amount = amount
        settlement.currency = currency
        settlement.date = date
        settlement.note = note
        settlement.isFullSettlement = isFullSettlement

        settlement.fromPerson = fetchPerson(id: fromPersonId, context: context)
        settlement.toPerson = fetchPerson(id: toPersonId, context: context)
    }

    private func fetchPerson(id: UUID, context: NSManagedObjectContext) -> Person? {
        let request = Person.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
```

### GroupDTO

```swift
// Swiss Coin/Models/DTOs/GroupDTO.swift

import Foundation
import CoreData

struct GroupDTO: Codable, Identifiable {
    let id: UUID
    var ownerId: UUID
    var name: String
    var photoUrl: String?
    var colorHex: String?
    var createdDate: Date
    var lastViewedDate: Date?
    var memberIds: [UUID]?  // Not stored in user_groups table — separate junction table
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case photoUrl = "photo_url"
        case colorHex = "color_hex"
        case createdDate = "created_date"
        case lastViewedDate = "last_viewed_date"
        case memberIds = "member_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(from group: UserGroup, ownerId: UUID) {
        self.id = group.id ?? UUID()
        self.ownerId = ownerId
        self.name = group.name ?? ""
        self.photoUrl = nil  // Set separately via StorageService
        self.colorHex = group.colorHex
        self.createdDate = group.createdDate ?? Date()
        self.lastViewedDate = group.lastViewedDate
        self.memberIds = (group.members as? Set<Person>)?.compactMap { $0.id }
        self.createdAt = nil
        self.updatedAt = nil
        self.deletedAt = nil
    }

    func apply(to group: UserGroup, context: NSManagedObjectContext) {
        group.name = name
        group.colorHex = colorHex
        group.createdDate = createdDate
        group.lastViewedDate = lastViewedDate
        // photoUrl handled separately — download image and set photoData
        // memberIds handled separately via setGroupMembers()
    }
}
```

### MessageDTO

```swift
// Swiss Coin/Models/DTOs/MessageDTO.swift

import Foundation
import CoreData

struct MessageDTO: Codable, Identifiable {
    let id: UUID
    var ownerId: UUID
    var content: String
    var timestamp: Date
    var isFromUser: Bool
    var isEdited: Bool
    var withPersonId: UUID?
    var withGroupId: UUID?
    var withSubscriptionId: UUID?
    var onTransactionId: UUID?
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case content
        case timestamp
        case isFromUser = "is_from_user"
        case isEdited = "is_edited"
        case withPersonId = "with_person_id"
        case withGroupId = "with_group_id"
        case withSubscriptionId = "with_subscription_id"
        case onTransactionId = "on_transaction_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(from message: ChatMessage, ownerId: UUID) {
        self.id = message.id ?? UUID()
        self.ownerId = ownerId
        self.content = message.content ?? ""
        self.timestamp = message.timestamp ?? Date()
        self.isFromUser = message.isFromUser
        self.isEdited = message.isEdited
        self.withPersonId = message.withPerson?.id
        self.withGroupId = message.withGroup?.id
        self.withSubscriptionId = message.withSubscription?.id
        self.onTransactionId = message.onTransaction?.id
        self.createdAt = nil
        self.updatedAt = nil
        self.deletedAt = nil
    }

    func apply(to message: ChatMessage, context: NSManagedObjectContext) {
        message.content = content
        message.timestamp = timestamp
        message.isFromUser = isFromUser
        message.isEdited = isEdited

        if let personId = withPersonId {
            message.withPerson = fetchPerson(id: personId, context: context)
        }
        if let groupId = withGroupId {
            message.withGroup = fetchGroup(id: groupId, context: context)
        }
        if let subId = withSubscriptionId {
            message.withSubscription = fetchSubscription(id: subId, context: context)
        }
        if let txId = onTransactionId {
            message.onTransaction = fetchTransaction(id: txId, context: context)
        }
    }

    private func fetchPerson(id: UUID, context: NSManagedObjectContext) -> Person? {
        let request = Person.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchGroup(id: UUID, context: NSManagedObjectContext) -> UserGroup? {
        let request = UserGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchSubscription(id: UUID, context: NSManagedObjectContext) -> Subscription? {
        let request = Subscription.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchTransaction(id: UUID, context: NSManagedObjectContext) -> FinancialTransaction? {
        let request = FinancialTransaction.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
```

### SubscriptionDTO

```swift
// Swiss Coin/Models/DTOs/SubscriptionDTO.swift

import Foundation
import CoreData

struct SubscriptionDTO: Codable, Identifiable {
    let id: UUID
    var ownerId: UUID
    var name: String
    var amount: Double
    var cycle: String
    var customCycleDays: Int?
    var startDate: Date
    var nextBillingDate: Date?
    var isShared: Bool
    var isActive: Bool
    var category: String?
    var iconName: String?
    var colorHex: String?
    var notes: String?
    var notificationEnabled: Bool
    var notificationDaysBefore: Int
    var isArchived: Bool
    var subscriberIds: [UUID]?  // Junction table — handled separately
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case amount
        case cycle
        case customCycleDays = "custom_cycle_days"
        case startDate = "start_date"
        case nextBillingDate = "next_billing_date"
        case isShared = "is_shared"
        case isActive = "is_active"
        case category
        case iconName = "icon_name"
        case colorHex = "color_hex"
        case notes
        case notificationEnabled = "notification_enabled"
        case notificationDaysBefore = "notification_days_before"
        case isArchived = "is_archived"
        case subscriberIds = "subscriber_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(from subscription: Subscription, ownerId: UUID) {
        self.id = subscription.id ?? UUID()
        self.ownerId = ownerId
        self.name = subscription.name ?? ""
        self.amount = subscription.amount
        self.cycle = subscription.cycle ?? "monthly"
        self.customCycleDays = subscription.customCycleDays > 0 ? Int(subscription.customCycleDays) : nil
        self.startDate = subscription.startDate ?? Date()
        self.nextBillingDate = subscription.nextBillingDate
        self.isShared = subscription.isShared
        self.isActive = subscription.isActive
        self.category = subscription.category
        self.iconName = subscription.iconName
        self.colorHex = subscription.colorHex
        self.notes = subscription.notes
        self.notificationEnabled = subscription.notificationEnabled
        self.notificationDaysBefore = Int(subscription.notificationDaysBefore)
        self.isArchived = subscription.isArchived
        self.subscriberIds = (subscription.subscribers as? Set<Person>)?.compactMap { $0.id }
        self.createdAt = nil
        self.updatedAt = nil
        self.deletedAt = nil
    }

    func apply(to subscription: Subscription) {
        subscription.name = name
        subscription.amount = amount
        subscription.cycle = cycle
        subscription.customCycleDays = Int16(customCycleDays ?? 0)
        subscription.startDate = startDate
        subscription.nextBillingDate = nextBillingDate
        subscription.isShared = isShared
        subscription.isActive = isActive
        subscription.category = category
        subscription.iconName = iconName
        subscription.colorHex = colorHex
        subscription.notes = notes
        subscription.notificationEnabled = notificationEnabled
        subscription.notificationDaysBefore = Int16(notificationDaysBefore)
        subscription.isArchived = isArchived
        // subscriberIds handled separately via junction table
    }
}
```

### ProfileDTO

```swift
// Swiss Coin/Models/DTOs/ProfileDTO.swift

import Foundation

struct ProfileDTO: Codable, Identifiable {
    let id: UUID
    var displayName: String
    var fullName: String?
    var phone: String?
    var email: String?
    var photoUrl: String?
    var colorHex: String?
    var isArchived: Bool
    var lastViewedDate: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case fullName = "full_name"
        case phone
        case email
        case photoUrl = "photo_url"
        case colorHex = "color_hex"
        case isArchived = "is_archived"
        case lastViewedDate = "last_viewed_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

---

## StorageService

Handles photo upload and download via Supabase Storage. Uses the private `photos` bucket.

```swift
// Swiss Coin/Services/StorageService.swift

import Foundation
import Supabase
import UIKit

final class StorageService {
    static let shared = StorageService()
    private let client = SupabaseConfig.shared.client
    private let bucket = "photos"

    private init() {}

    /// Upload a photo and return the storage path
    func uploadPhoto(
        imageData: Data,
        entityType: String,  // "persons" or "groups"
        entityId: UUID
    ) async throws -> String {
        let path = "\(entityType)/\(entityId.uuidString).jpg"

        // Compress if needed (max 500KB)
        let compressed = compressImage(data: imageData, maxBytes: 500_000)

        try await client.storage
            .from(bucket)
            .upload(
                path,
                data: compressed,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        return path
    }

    /// Get a signed URL for a photo (valid for 1 hour)
    func getSignedUrl(path: String) async throws -> URL {
        let url = try await client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: 3600)
        return url
    }

    /// Download photo data
    func downloadPhoto(path: String) async throws -> Data {
        let data = try await client.storage
            .from(bucket)
            .download(path: path)
        return data
    }

    /// Delete a photo
    func deletePhoto(path: String) async throws {
        try await client.storage
            .from(bucket)
            .remove(paths: [path])
    }

    /// Compress image data to fit within maxBytes
    private func compressImage(data: Data, maxBytes: Int) -> Data {
        guard data.count > maxBytes,
              let image = UIImage(data: data) else { return data }

        var compression: CGFloat = 0.8
        var compressed = image.jpegData(compressionQuality: compression) ?? data

        while compressed.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            compressed = image.jpegData(compressionQuality: compression) ?? data
        }

        return compressed
    }
}
```

### Photo Handling in Views

For displaying photos, prefer `photoUrl` (remote) with fallback to `photoData` (local):

```swift
// Example usage in a view
if let photoUrl = person.photoUrl,
   let url = URL(string: photoUrl) {
    AsyncImage(url: url) { image in
        image.resizable().scaledToFill()
    } placeholder: {
        avatarPlaceholder
    }
} else if let photoData = person.photoData,
          let uiImage = UIImage(data: photoData) {
    Image(uiImage: uiImage)
        .resizable()
        .scaledToFill()
} else {
    avatarPlaceholder
}
```

---

## ViewModel Changes

ViewModels continue using `@FetchRequest` for UI reactivity. The only change is adding sync calls after CoreData saves.

```swift
// Example: After saving a new person in a ViewModel
func savePerson(_ person: Person) {
    do {
        try viewContext.save()

        // Trigger sync in background (non-blocking)
        Task {
            try? await SyncManager.shared.pushEntity(
                PersonDTO(from: person, ownerId: currentUserId),
                table: "persons"
            )
        }
    } catch {
        // Handle error
    }
}
```

This is a minimal, non-invasive pattern: CoreData save happens synchronously (UI updates instantly via @FetchRequest), and the remote sync fires asynchronously. If sync fails, the SyncManager will retry on the next sync cycle.

---

## CoreData Model v7 Changes

The CoreData model needs additions for sync support. Create `Swiss_Coin 7.xcdatamodel` (new version, set as current):

### New Attributes

| Entity | Attribute | Type | Purpose |
|--------|-----------|------|---------|
| `TransactionSplit` | `id` | UUID (optional) | Unique identifier for sync |
| `TransactionSplit` | `updatedAt` | Date (optional) | Change tracking |
| `TransactionPayer` | `id` | UUID (optional) | Unique identifier for sync |
| `TransactionPayer` | `updatedAt` | Date (optional) | Change tracking |
| `Person` | `photoUrl` | String (optional) | Remote photo URL |
| `Person` | `updatedAt` | Date (optional) | Change tracking |
| `Person` | `deletedAt` | Date (optional) | Soft delete timestamp |
| `UserGroup` | `photoUrl` | String (optional) | Remote photo URL |
| `UserGroup` | `updatedAt` | Date (optional) | Change tracking |
| `UserGroup` | `deletedAt` | Date (optional) | Soft delete timestamp |
| `FinancialTransaction` | `updatedAt` | Date (optional) | Change tracking |
| `FinancialTransaction` | `deletedAt` | Date (optional) | Soft delete timestamp |
| `Settlement` | `updatedAt` | Date (optional) | Change tracking |
| `Settlement` | `deletedAt` | Date (optional) | Soft delete timestamp |
| `ChatMessage` | `updatedAt` | Date (optional) | Change tracking |
| `ChatMessage` | `deletedAt` | Date (optional) | Soft delete timestamp |
| `Subscription` | `updatedAt` | Date (optional) | Change tracking |
| `Subscription` | `deletedAt` | Date (optional) | Soft delete timestamp |
| `Reminder` | `updatedAt` | Date (optional) | Change tracking |
| `Reminder` | `deletedAt` | Date (optional) | Soft delete timestamp |

### Migration Notes

- Use **lightweight migration** (automatic). All new attributes are optional with no default values, so lightweight migration is supported.
- Existing `Persistence.swift` already has lightweight migration enabled via `NSMigratePersistentStoresAutomaticallyOption`.
- No mapping model required.

### Swift Model Updates

Add `@NSManaged` properties to each entity's Swift file:

```swift
// Example addition to Person.swift
@NSManaged public var photoUrl: String?
@NSManaged public var updatedAt: Date?
@NSManaged public var deletedAt: Date?
```

```swift
// Example addition to TransactionSplit.swift
@NSManaged public var id: UUID?
@NSManaged public var updatedAt: Date?
```
