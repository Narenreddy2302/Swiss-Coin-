# 05 - Realtime

Supabase Realtime enables live sync of data changes. When a record is inserted, updated, or deleted in PostgreSQL, the change is pushed to subscribed iOS clients in real time via WebSocket.

---

## Table of Contents

1. [Tables to Enable](#1-tables-to-enable)
2. [Channel Architecture](#2-channel-architecture)
3. [Enable Realtime on Tables](#3-enable-realtime-on-tables)
4. [iOS RealtimeService](#4-ios-realtimeservice)
5. [NotificationCenter Propagation](#5-notificationcenter-propagation)
6. [Debouncing Rapid Changes](#6-debouncing-rapid-changes)
7. [Conflict Handling](#7-conflict-handling)
8. [Connection Lifecycle](#8-connection-lifecycle)

---

## 1. Tables to Enable

Not all tables need Realtime. Enable it only on tables that benefit from live updates:

| Table | Enable | Rationale |
|-------|--------|-----------|
| `financial_transactions` | Yes | Core data -- live sync of new expenses |
| `settlements` | Yes | Settlement changes should appear immediately |
| `chat_messages` | Yes | Messages need real-time delivery |
| `reminders` | Yes | New reminders should push instantly |
| `subscription_reminders` | Yes | Subscription reminder alerts |
| `subscriptions` | Yes | Shared subscription changes |
| `profiles` | No | Rarely changes, pull on app launch |
| `persons` | No | Contacts change infrequently, pull-based |
| `user_groups` | No | Groups change infrequently |
| `group_members` | No | Membership changes are rare |
| `transaction_splits` | No | Always fetched with parent transaction |
| `transaction_payers` | No | Always fetched with parent transaction |
| `subscription_subscribers` | No | Fetched with parent subscription |
| `subscription_payments` | No | Pull-based, not time-critical |
| `subscription_settlements` | No | Pull-based, not time-critical |

### Why Not Everything?

- Realtime has a cost per active channel/subscription
- Child tables (splits, payers) are always fetched alongside their parent
- Infrequently changing tables (persons, groups) are better served by pull-on-launch
- Keeping the channel count low improves reliability and reduces bandwidth

---

## 2. Channel Architecture

### Single Channel Per User

Use one channel per authenticated user, filtered by `owner_id`:

```
Channel: user-sync-{userId}
  |
  +-- financial_transactions (INSERT, UPDATE, DELETE)
  +-- settlements (INSERT, UPDATE, DELETE)
  +-- chat_messages (INSERT, UPDATE, DELETE)
  +-- reminders (INSERT, UPDATE, DELETE)
  +-- subscription_reminders (INSERT, UPDATE, DELETE)
  +-- subscriptions (INSERT, UPDATE, DELETE)
```

### Why One Channel?

- Simpler connection management (one WebSocket)
- All events filtered by the same `owner_id`
- Reduces reconnection overhead
- Easier to subscribe/unsubscribe on auth state changes

### Filter Pattern

All subscriptions use the same filter: `owner_id=eq.{userId}`

This works because:
1. RLS ensures the user only receives their own data
2. The filter reduces server-side processing
3. Combined with RLS, this provides defense-in-depth

---

## 3. Enable Realtime on Tables

Realtime must be enabled per-table in the Supabase Dashboard or via SQL:

```sql
-- Enable Realtime publication for specific tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.financial_transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.settlements;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.reminders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.subscription_reminders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.subscriptions;
```

### Verify Realtime is Enabled

```sql
-- Check which tables are in the realtime publication
SELECT * FROM pg_publication_tables
WHERE pubname = 'supabase_realtime';
```

---

## 4. iOS RealtimeService

```swift
// Swiss Coin/Services/Supabase/RealtimeService.swift

import Foundation
import Supabase
import Realtime
import Combine
import os

/// Manages Supabase Realtime subscriptions.
/// Subscribes on authentication, unsubscribes on sign-out.
/// Forwards database changes to the SyncEngine via NotificationCenter.
@MainActor
final class RealtimeService: ObservableObject {

    static let shared = RealtimeService()

    @Published private(set) var isConnected = false

    private let client = SupabaseConfig.shared.client
    private let logger = Logger(subsystem: "com.swisscoin", category: "Realtime")
    private var channel: RealtimeChannelV2?
    private var cancellables = Set<AnyCancellable>()

    // Tables to subscribe to
    private let realtimeTables = [
        "financial_transactions",
        "settlements",
        "chat_messages",
        "reminders",
        "subscription_reminders",
        "subscriptions"
    ]

    private init() {
        observeAuthState()
    }

    // MARK: - Auth State Observation

    /// Subscribe/unsubscribe based on auth state changes.
    private func observeAuthState() {
        AuthManager.shared.$authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .authenticated:
                    Task { await self.subscribe() }
                case .unauthenticated:
                    Task { await self.unsubscribe() }
                case .loading:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Subscribe

    /// Subscribe to Realtime changes for the authenticated user.
    func subscribe() async {
        guard let userId = AuthManager.shared.currentUserId else {
            logger.warning("Cannot subscribe: no authenticated user")
            return
        }

        // Unsubscribe from any existing channel first
        await unsubscribe()

        let channelName = "user-sync-\(userId.uuidString)"
        logger.info("Subscribing to channel: \(channelName)")

        let channel = client.realtimeV2.channel(channelName)

        // Subscribe to each table with postgres_changes
        for table in realtimeTables {
            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: table,
                filter: "owner_id=eq.\(userId.uuidString)"
            )

            // Listen for changes in a detached task
            Task { [weak self] in
                for await change in changes {
                    self?.handleChange(table: table, action: change)
                }
            }
        }

        // Connect the channel
        await channel.subscribe()
        self.channel = channel
        isConnected = true
        logger.info("Realtime connected")
    }

    // MARK: - Unsubscribe

    /// Unsubscribe from all Realtime channels.
    func unsubscribe() async {
        guard let channel else { return }

        await channel.unsubscribe()
        self.channel = nil
        isConnected = false
        logger.info("Realtime disconnected")
    }

    // MARK: - Handle Changes

    /// Process a Realtime change event and forward to the app.
    private func handleChange(table: String, action: AnyAction) {
        logger.info("Realtime change: \(table) - \(action.type)")

        let notification: Notification.Name
        switch table {
        case "financial_transactions":
            notification = .transactionChanged
        case "settlements":
            notification = .settlementChanged
        case "chat_messages":
            notification = .chatMessageChanged
        case "reminders":
            notification = .reminderChanged
        case "subscription_reminders":
            notification = .subscriptionReminderChanged
        case "subscriptions":
            notification = .subscriptionChanged
        default:
            logger.warning("Unknown table in Realtime event: \(table)")
            return
        }

        // Post notification with change details
        NotificationCenter.default.post(
            name: notification,
            object: nil,
            userInfo: [
                "table": table,
                "action": action.type.rawValue,
                "record": action.record,
                "oldRecord": action.oldRecord as Any
            ]
        )
    }
}

// MARK: - Realtime Action Wrapper

/// Type-erased wrapper for postgres change events.
struct AnyAction {
    enum ActionType: String {
        case insert = "INSERT"
        case update = "UPDATE"
        case delete = "DELETE"
    }

    let type: ActionType
    let record: [String: AnyJSON]
    let oldRecord: [String: AnyJSON]?
}

// MARK: - Notification Names

extension Notification.Name {
    static let transactionChanged = Notification.Name("transactionChanged")
    static let settlementChanged = Notification.Name("settlementChanged")
    static let chatMessageChanged = Notification.Name("chatMessageChanged")
    static let reminderChanged = Notification.Name("reminderChanged")
    static let subscriptionReminderChanged = Notification.Name("subscriptionReminderChanged")
    static let subscriptionChanged = Notification.Name("subscriptionChanged")
    static let realtimeConnectionChanged = Notification.Name("realtimeConnectionChanged")
}
```

---

## 5. NotificationCenter Propagation

### How Changes Flow to ViewModels

```
Supabase Realtime (WebSocket)
    |
    v
RealtimeService.handleChange()
    |
    v
NotificationCenter.post(.transactionChanged)
    |
    +-- SyncEngine.onTransactionChanged()
    |       |
    |       v
    |   CoreData context.save()
    |       |
    |       v
    |   @FetchRequest auto-updates View
    |
    +-- TransactionListViewModel.onReceive(.transactionChanged)
            |
            v
        Optional: trigger refresh, show toast, etc.
```

### ViewModel Integration Pattern

```swift
// In a ViewModel that needs to react to Realtime changes

class TransactionListViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Listen for Realtime transaction changes
        NotificationCenter.default.publisher(for: .transactionChanged)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleTransactionChange(notification)
            }
            .store(in: &cancellables)
    }

    private func handleTransactionChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let action = userInfo["action"] as? String else { return }

        switch action {
        case "INSERT":
            // SyncEngine already saved to CoreData
            // @FetchRequest will auto-update
            // Optionally show "New transaction added" toast
            break

        case "UPDATE":
            // CoreData updated by SyncEngine
            break

        case "DELETE":
            // SyncEngine marks as deleted in CoreData
            break

        default:
            break
        }
    }
}
```

### CoreData Auto-Refresh

Since SwiftUI's `@FetchRequest` automatically observes CoreData context changes, the primary flow is:

1. Realtime event arrives
2. SyncEngine updates CoreData
3. `@FetchRequest` detects the change
4. View re-renders automatically

NotificationCenter is used for **supplementary** reactions (toasts, badge updates, sounds) not covered by `@FetchRequest`.

---

## 6. Debouncing Rapid Changes

When multiple changes arrive in quick succession (e.g., bulk import, rapid edits), debounce to avoid excessive CoreData writes:

### SyncEngine Debounce Pattern

```swift
// In SyncEngine

private var pendingChanges: [String: [AnyAction]] = [:]
private var debounceTask: Task<Void, Never>?

func enqueueRealtimeChange(table: String, action: AnyAction) {
    pendingChanges[table, default: []].append(action)

    // Cancel previous debounce
    debounceTask?.cancel()

    // Process after 300ms of quiet
    debounceTask = Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

        guard !Task.isCancelled else { return }

        self?.processPendingChanges()
    }
}

private func processPendingChanges() {
    let changes = pendingChanges
    pendingChanges.removeAll()

    // Batch all changes into a single CoreData save
    let context = PersistenceController.shared.container.newBackgroundContext()
    context.perform {
        for (table, actions) in changes {
            for action in actions {
                self.applyChange(table: table, action: action, in: context)
            }
        }

        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }
}
```

### Debounce Settings

| Scenario | Delay | Rationale |
|----------|-------|-----------|
| Normal changes | 300ms | Batch rapid successive changes |
| Bulk import | 1000ms | Larger batch window during migration |
| Chat messages | 0ms (immediate) | Messages should appear instantly |

---

## 7. Conflict Handling

### Last-Write-Wins Strategy

Swiss Coin uses **last-write-wins (LWW)** based on `updated_at` timestamps:

```
Local change:  updated_at = 2024-01-15 10:00:05
Remote change: updated_at = 2024-01-15 10:00:08
                                          ^^^^
Result: Remote wins (newer timestamp)
```

### Conflict Resolution Flow

```
Realtime event arrives with record R_remote
    |
    v
Fetch local record R_local from CoreData
    |
    +-- R_local not found --> INSERT R_remote into CoreData
    |
    +-- R_local found
            |
            +-- R_remote.updated_at > R_local.updated_at
            |       --> UPDATE R_local with R_remote values
            |
            +-- R_remote.updated_at <= R_local.updated_at
            |       --> SKIP (local is newer, will be pushed)
            |
            +-- R_remote.deleted_at IS NOT NULL
                    --> Soft-delete R_local in CoreData
```

### Implementation

```swift
// In SyncEngine / ConflictResolver

struct ConflictResolver {

    /// Determine which version wins.
    /// - Parameters:
    ///   - local: Local CoreData record's updated_at
    ///   - remote: Remote Supabase record's updated_at
    /// - Returns: .local or .remote
    static func resolve(localUpdatedAt: Date?, remoteUpdatedAt: Date?) -> Winner {
        guard let local = localUpdatedAt else { return .remote }
        guard let remote = remoteUpdatedAt else { return .local }

        return remote > local ? .remote : .local
    }

    enum Winner {
        case local
        case remote
    }
}
```

### Edge Cases

| Scenario | Resolution |
|----------|-----------|
| Same `updated_at` timestamp | Remote wins (server is authoritative) |
| Local record has no `updated_at` | Remote wins |
| Remote record has `deleted_at` set | Soft-delete local record |
| Local record was deleted but remote updated | Remote update wins (undelete) |
| Both deleted | Keep deleted state |

### Why LWW?

- Swiss Coin is single-user: conflicts are rare (only multi-device edge case)
- Simple to implement and reason about
- No merge conflicts to resolve manually
- Correct for the 99% case (user editing on one device at a time)

---

## 8. Connection Lifecycle

### WebSocket States

```
App Launch
    |
    v
Auth Check
    |
    +-- Authenticated --> subscribe()
    |                       |
    |                       v
    |                   WebSocket CONNECTED
    |                       |
    |                   +---+---+
    |                   |       |
    |               Receiving   Connection Lost
    |               Events      |
    |                   |       v
    |                   |   AUTO-RECONNECT
    |                   |   (SDK handles)
    |                   |       |
    |                   +-------+
    |
    +-- Not Authenticated --> show login
                                |
                            User Signs In
                                |
                                v
                            subscribe()
```

### Reconnection

The Supabase Realtime SDK handles reconnection automatically:
- Exponential backoff on connection loss
- Re-subscribes to all channels on reconnect
- Emits connection state changes

### App Lifecycle Integration

```swift
// In Swiss_CoinApp.swift or SceneDelegate

// When app goes to background (optional: disconnect to save battery)
NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
    .sink { _ in
        // Optional: keep connected for ~30s, then disconnect
        // Or let the OS manage the WebSocket lifecycle
    }

// When app comes to foreground
NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
    .sink { _ in
        // Re-subscribe if needed
        Task {
            if AuthManager.shared.isAuthenticated {
                await RealtimeService.shared.subscribe()
            }
        }

        // Also trigger a pull sync to catch changes missed while backgrounded
        // SyncEngine.shared.pullAll()
    }
```

### Background Behavior

| State | WebSocket | Sync Strategy |
|-------|-----------|--------------|
| Foreground | Connected | Realtime events |
| Background (< 30s) | Connected | Still receiving |
| Background (> 30s) | iOS may suspend | Pull on foreground |
| Terminated | Disconnected | Full pull on next launch |

---

## Monitoring

### Connection Status UI

```swift
// Small indicator in the app UI showing sync status

struct SyncStatusIndicator: View {
    @ObservedObject private var realtime = RealtimeService.shared

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(realtime.isConnected ? AppColors.positive : AppColors.warning)
                .frame(width: 8, height: 8)

            Text(realtime.isConnected ? "Synced" : "Connecting...")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)
        }
    }
}
```

---

## Checklist

- [ ] Enable Realtime on 6 tables via SQL
- [ ] Verify publication includes correct tables
- [ ] Implement `RealtimeService.swift`
- [ ] Define `Notification.Name` extensions
- [ ] Wire RealtimeService to AuthManager state
- [ ] Implement debouncing in SyncEngine
- [ ] Implement LWW conflict resolver
- [ ] Add app lifecycle hooks (foreground/background)
- [ ] Build `SyncStatusIndicator` UI component
- [ ] Test Realtime events end-to-end
- [ ] Test reconnection behavior
- [ ] Test conflict resolution with concurrent edits
