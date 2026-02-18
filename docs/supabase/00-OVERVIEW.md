# 00 - Swiss Coin Supabase Integration: Master Overview

## Project Context

Swiss Coin is a premium iOS expense-splitting and personal finance app built with **SwiftUI + CoreData (MVVM)**. It is currently **100% offline** with all data stored locally via CoreData.

This integration adds **Supabase** as the full cloud backend:
- **Auth** -- Phone OTP login replacing local UUID identity
- **PostgreSQL** -- Cloud persistence for all 12 CoreData entities (mapped to 16 tables)
- **Storage** -- Profile photos, group photos, receipt images
- **Realtime** -- Live sync of transactions, settlements, messages
- **Edge Functions** -- Server-side logic (reminders, notifications)

The app transitions from **offline-only** to **offline-first with cloud sync**. CoreData remains the UI source of truth; Supabase provides durable cloud persistence and future multi-device/multi-user capabilities.

**Supabase Project:** `https://fgcjijairsikaeshpiof.supabase.co`

---

## Documentation Index

| # | File | Description |
|---|------|-------------|
| 00 | **`00-OVERVIEW.md`** (this file) | Master overview, architecture, phases, table mapping |
| 01 | **`01-AUTHENTICATION.md`** | Phone OTP auth, AuthManager rewrite, session management |
| 02 | **`02-DATABASE-SCHEMA.md`** | Full SQL for all 16 tables, triggers, indexes |
| 03 | **`03-ROW-LEVEL-SECURITY.md`** | RLS policies for all tables, testing queries |
| 04 | **`04-STORAGE.md`** | Buckets, upload policies, iOS StorageService |
| 05 | **`05-REALTIME.md`** | Channel architecture, RealtimeService, conflict handling |
| 06 | **`06-SYNC-ENGINE.md`** | Offline-first sync: queue, push/pull, conflict resolution |
| 07 | **`07-EDGE-FUNCTIONS.md`** | Server-side functions: reminders, cleanup, notifications |
| 08 | **`08-MIGRATION-GUIDE.md`** | Existing user migration: local data upload, ID remapping |
| 09 | **`09-TESTING.md`** | Integration tests, RLS verification, sync tests |
| 10 | **`10-DEPLOYMENT.md`** | Environment config, CI/CD, monitoring, rollback |

---

## Architecture Overview

```
+---------------------------------------------+
|              iOS App (SwiftUI)               |
|  +-------+  +----------+  +--------------+  |
|  | Views |->| ViewModels|->| Repositories |  |
|  +-------+  +----------+  +--------------+  |
|                               |      |       |
|                    +----------+  +---+----+  |
|                    | CoreData |  | Sync   |  |
|                    | (Local)  |  | Engine |  |
|                    +----------+  +--------+  |
+---------------------------------------------+
                                      |
                              +-------+-------+
                              |   Supabase    |
                              +---------------+
                              | Auth (OTP)    |
                              | PostgreSQL    |
                              | Storage       |
                              | Realtime      |
                              | Edge Fns      |
                              +---------------+
```

### Data Flow

1. **Write path:** User action -> ViewModel -> CoreData (save) -> SyncEngine (enqueue) -> Supabase (push)
2. **Read path:** Supabase (Realtime/pull) -> SyncEngine (merge) -> CoreData (update) -> ViewModel (observe) -> View
3. **Offline:** CoreData handles reads/writes normally; SyncEngine queues changes for later push
4. **Conflict resolution:** Last-write-wins based on `updated_at` timestamps

### Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| CoreData stays as UI source of truth | Existing app is built on it; SwiftUI `@FetchRequest` bindings; offline support |
| Phone OTP as primary auth | No email required for expense-splitting; lowest friction; Twilio SMS |
| Apple Sign-In deferred to Phase 2 | Simpler initial launch; phone is more universal for contact matching |
| Offline-first with cloud sync | Users expect the app to work without internet; sync on reconnect |
| Last-write-wins conflict resolution | Single-user app (for now); simplest correct strategy |
| Soft deletes (`deleted_at`) | Allows sync of deletions; prevents orphaned references |
| `owner_id` on all tables | Single-user data isolation; simple RLS; future multi-user ready |

---

## Implementation Phases

### Phase 0: Foundation (No User Impact)
- Add Supabase Swift SDK via SPM (v2.x)
- Create `SupabaseConfig.swift` singleton
- Set up environment-based configuration (dev/prod)
- **Depends on:** Nothing
- **Docs:** `01-AUTHENTICATION.md` (SDK setup section)

### Phase 1: Database & Security
- Apply all table migrations (16 tables)
- Enable RLS on all tables
- Create storage buckets (3 buckets)
- **Depends on:** Phase 0
- **Docs:** `02-DATABASE-SCHEMA.md`, `03-ROW-LEVEL-SECURITY.md`, `04-STORAGE.md`

### Phase 2: Authentication
- Rewrite `AuthManager` to use Supabase Auth
- Build Phone OTP login UI (PhoneLoginView)
- Auto-profile creation via database trigger
- Session management (SDK auto-refresh)
- **Depends on:** Phase 1
- **Docs:** `01-AUTHENTICATION.md`

### Phase 3: Sync Engine
- Build `SyncEngine` with operation queue
- Implement push (local -> cloud) for all entities
- Implement pull (cloud -> local) for all entities
- Handle `deleted_at` soft deletes
- **Depends on:** Phase 2
- **Docs:** `06-SYNC-ENGINE.md`

### Phase 4: Realtime
- Enable Realtime on key tables
- Build `RealtimeService` with filtered channels
- Wire Realtime events to CoreData updates via SyncEngine
- **Depends on:** Phase 3
- **Docs:** `05-REALTIME.md`

### Phase 5: Storage Integration
- Build `StorageService` for photo/receipt uploads
- Migrate `photoData` blobs to Supabase Storage URLs
- Update Person/UserGroup to use `photoURL` fields
- **Depends on:** Phase 2
- **Docs:** `04-STORAGE.md`

### Phase 6: Edge Functions
- Reminder scheduling function
- Push notification dispatcher
- Data cleanup / maintenance
- **Depends on:** Phase 3
- **Docs:** `07-EDGE-FUNCTIONS.md`

### Phase 7: Migration & Launch
- Existing user data migration (local -> cloud)
- ID remapping (local UUIDs -> Supabase UUIDs)
- Beta testing, monitoring, rollback plan
- **Depends on:** Phases 3-6
- **Docs:** `08-MIGRATION-GUIDE.md`, `09-TESTING.md`, `10-DEPLOYMENT.md`

---

## CoreData to Supabase Table Mapping

| # | CoreData Entity | Supabase Table | Notes |
|---|-----------------|----------------|-------|
| 1 | *(auth.users)* | `profiles` | 1:1 with auth.users; auto-created by trigger |
| 2 | `Person` | `persons` | Contacts/people in the user's world |
| 3 | `UserGroup` | `user_groups` | Expense groups |
| 4 | *(M2M relationship)* | `group_members` | Junction: group <-> person |
| 5 | `Subscription` | `subscriptions` | Recurring expenses |
| 6 | *(M2M relationship)* | `subscription_subscribers` | Junction: subscription <-> person |
| 7 | `FinancialTransaction` | `financial_transactions` | Core expense/income records |
| 8 | `TransactionSplit` | `transaction_splits` | Who owes what on a transaction |
| 9 | `TransactionPayer` | `transaction_payers` | Who paid what on a transaction |
| 10 | `Settlement` | `settlements` | Debt settlements between people |
| 11 | `Reminder` | `reminders` | Payment reminders |
| 12 | `ChatMessage` | `chat_messages` | In-app messages/comments |
| 13 | `SubscriptionPayment` | `subscription_payments` | Individual subscription payments |
| 14 | `SubscriptionSettlement` | `subscription_settlements` | Subscription debt settlements |
| 15 | `SubscriptionReminder` | `subscription_reminders` | Subscription payment reminders |

**Total: 15 Supabase tables** (12 CoreData entities + `profiles` + 2 junction tables)

---

## New Files to Create

| # | File | Purpose |
|---|------|---------|
| 1 | `Swiss Coin/Services/Supabase/SupabaseConfig.swift` | Supabase client singleton |
| 2 | `Swiss Coin/Services/Supabase/AuthManager.swift` | Auth state, OTP login/logout |
| 3 | `Swiss Coin/Services/Supabase/SyncEngine.swift` | Offline-first sync coordinator |
| 4 | `Swiss Coin/Services/Supabase/SyncQueue.swift` | Pending operations queue |
| 5 | `Swiss Coin/Services/Supabase/RealtimeService.swift` | Realtime subscription manager |
| 6 | `Swiss Coin/Services/Supabase/StorageService.swift` | Photo/receipt upload/download |
| 7 | `Swiss Coin/Services/Supabase/SyncModels.swift` | Codable structs for Supabase rows |
| 8 | `Swiss Coin/Services/Supabase/ConflictResolver.swift` | Last-write-wins merge logic |
| 9 | `Swiss Coin/Features/Auth/PhoneLoginView.swift` | Phone OTP login screen |
| 10 | `Swiss Coin/Features/Auth/OTPVerificationView.swift` | 6-digit code entry screen |
| 11 | `Swiss Coin/Features/Auth/AuthViewModel.swift` | Login flow state management |
| 12 | `Swiss Coin/Features/Auth/PhoneNumberField.swift` | Country code + phone input |
| 13 | `Swiss Coin/Services/Supabase/NetworkMonitor.swift` | Reachability for sync decisions |
| 14 | `Swiss Coin/Services/Supabase/SyncStatus.swift` | Observable sync state for UI |

## Existing Files to Modify

| # | File | Changes |
|---|------|---------|
| 1 | `Swiss Coin/Utilities/CurrentUser.swift` | Replace local UUID with Supabase auth user ID |
| 2 | `Swiss Coin/Resources/Persistence.swift` | Add sync-related attributes to CoreData setup |
| 3 | `Swiss Coin/Swiss_CoinApp.swift` | Initialize Supabase on launch; auth state routing |
| 4 | `Swiss Coin.xcodeproj/project.pbxproj` | Add Supabase SPM dependency |
| 5 | `Swiss Coin/Features/Profile/ProfileView.swift` | Add logout, link to phone login |
| 6 | `Swiss Coin/Features/Home/HomeView.swift` | Show sync status indicator |
| 7 | `Swiss Coin/Resources/Swiss_Coin.xcdatamodeld` | Add syncStatus, remoteId, lastSyncedAt to entities |
| 8 | `Info.plist` | Add URL scheme for deep links |

---

## Quick Reference: Supabase Credentials

```
Project URL:  https://fgcjijairsikaeshpiof.supabase.co
Project Ref:  fgcjijairsikaeshpiof
API URL:      https://fgcjijairsikaeshpiof.supabase.co/rest/v1/
Realtime URL: wss://fgcjijairsikaeshpiof.supabase.co/realtime/v1/
Storage URL:  https://fgcjijairsikaeshpiof.supabase.co/storage/v1/
Auth URL:     https://fgcjijairsikaeshpiof.supabase.co/auth/v1/
Anon Key:     (stored in SupabaseConfig.swift, NOT committed to git)
```

> **Security:** The anon key is safe to embed in the iOS app (it's a publishable key). Row Level Security (RLS) ensures users can only access their own data. The service role key must NEVER be in client code.
