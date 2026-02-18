# 10 - Testing and Verification

End-to-end testing checklist for the Supabase integration. Covers authentication, schema, RLS, storage, migration, sync, and build verification.

---

## Table of Contents

1. [Authentication Testing](#authentication-testing)
2. [Schema Verification](#schema-verification)
3. [RLS Verification](#rls-verification)
4. [Storage Verification](#storage-verification)
5. [Data Migration Verification](#data-migration-verification)
6. [Sync Verification](#sync-verification)
7. [Edge Function Verification](#edge-function-verification)
8. [Build Verification](#build-verification)
9. [Performance Testing](#performance-testing)

---

## Authentication Testing

### Phone OTP Flow

- [ ] User can request OTP via phone number
- [ ] OTP is delivered (check Supabase Auth logs)
- [ ] Valid OTP signs the user in and creates a session
- [ ] Invalid OTP shows appropriate error
- [ ] Session JWT is stored in Keychain (not UserDefaults)
- [ ] Profile is auto-created in `profiles` table via auth trigger

```sql
-- Verify auth trigger created profile
SELECT id, display_name, created_at
FROM profiles
WHERE id = '<user-uuid>';
```

### Session Restoration

- [ ] App restores session on cold launch (no re-authentication needed)
- [ ] Expired session triggers token refresh automatically
- [ ] After force-quit and relaunch, session is still valid

```swift
// Test session restoration
let session = SupabaseConfig.shared.client.auth.currentSession
assert(session != nil, "Session should be restored from Keychain")
```

### Sign Out

- [ ] Sign out clears Keychain tokens
- [ ] Sign out clears UserDefaults sync timestamps
- [ ] Sign out does NOT delete local CoreData (user may sign back in)
- [ ] After sign out, all Supabase calls return 401

```sql
-- Verify no active sessions (from Supabase dashboard)
SELECT * FROM auth.sessions WHERE user_id = '<user-uuid>';
```

---

## Schema Verification

### Table Count

Verify all 15 tables exist (plus profiles):

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

Expected tables (16):

| # | Table |
|---|-------|
| 1 | `profiles` |
| 2 | `persons` |
| 3 | `user_groups` |
| 4 | `group_members` |
| 5 | `subscriptions` |
| 6 | `subscription_subscribers` |
| 7 | `subscription_payments` |
| 8 | `subscription_settlements` |
| 9 | `subscription_reminders` |
| 10 | `financial_transactions` |
| 11 | `transaction_splits` |
| 12 | `transaction_payers` |
| 13 | `settlements` |
| 14 | `reminders` |
| 15 | `chat_messages` |
| 16 | `device_tokens` |

### Foreign Key Integrity

```sql
-- List all foreign keys
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table,
    ccu.column_name AS foreign_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name;
```

Expected foreign keys:

| Table | Column | References |
|-------|--------|------------|
| `profiles` | `id` | `auth.users(id)` |
| `persons` | `owner_id` | `auth.users(id)` |
| `user_groups` | `owner_id` | `auth.users(id)` |
| `group_members` | `group_id` | `user_groups(id)` |
| `group_members` | `person_id` | `persons(id)` |
| `subscriptions` | `owner_id` | `auth.users(id)` |
| `subscription_subscribers` | `subscription_id` | `subscriptions(id)` |
| `subscription_subscribers` | `person_id` | `persons(id)` |
| `financial_transactions` | `owner_id` | `auth.users(id)` |
| `financial_transactions` | `payer_id` | `persons(id)` |
| `financial_transactions` | `created_by_id` | `persons(id)` |
| `financial_transactions` | `group_id` | `user_groups(id)` |
| `transaction_splits` | `transaction_id` | `financial_transactions(id)` |
| `transaction_splits` | `owed_by_id` | `persons(id)` |
| `transaction_payers` | `transaction_id` | `financial_transactions(id)` |
| `transaction_payers` | `paid_by_id` | `persons(id)` |
| `settlements` | `owner_id` | `auth.users(id)` |
| `settlements` | `from_person_id` | `persons(id)` |
| `settlements` | `to_person_id` | `persons(id)` |
| `reminders` | `owner_id` | `auth.users(id)` |
| `reminders` | `to_person_id` | `persons(id)` |
| `chat_messages` | `owner_id` | `auth.users(id)` |
| `chat_messages` | `with_person_id` | `persons(id)` |
| `chat_messages` | `with_group_id` | `user_groups(id)` |
| `chat_messages` | `with_subscription_id` | `subscriptions(id)` |
| `chat_messages` | `on_transaction_id` | `financial_transactions(id)` |
| `device_tokens` | `user_id` | `auth.users(id)` |

### moddatetime Triggers

Verify all tables with `updated_at` have automatic timestamp triggers:

```sql
-- List all moddatetime triggers
SELECT
    trigger_name,
    event_object_table
FROM information_schema.triggers
WHERE trigger_name LIKE 'handle_%_updated_at'
ORDER BY event_object_table;
```

Expected triggers on: `profiles`, `persons`, `user_groups`, `subscriptions`, `financial_transactions`, `transaction_splits`, `transaction_payers`, `settlements`, `reminders`, `chat_messages`, `subscription_payments`, `subscription_settlements`, `subscription_reminders`, `device_tokens`.

### Auth Trigger

```sql
-- Verify the auth trigger exists
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
    AND event_object_table = 'users';
```

### Indexes

```sql
-- List all custom indexes
SELECT
    indexname,
    tablename,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexname NOT LIKE '%_pkey'
ORDER BY tablename, indexname;
```

Key indexes to verify:

| Table | Index | Columns |
|-------|-------|---------|
| `persons` | `idx_persons_owner_id` | `owner_id` |
| `financial_transactions` | `idx_transactions_owner_id` | `owner_id` |
| `financial_transactions` | `idx_transactions_date` | `date` |
| `settlements` | `idx_settlements_owner_id` | `owner_id` |
| `chat_messages` | `idx_messages_owner_id` | `owner_id` |

---

## RLS Verification

### Cross-User Isolation

Test that User A cannot access User B's data.

```sql
-- As User A (set JWT in request header)
-- This should return ONLY User A's persons
SELECT * FROM persons;

-- This should return 0 rows (User B's person ID)
SELECT * FROM persons WHERE id = '<user-b-person-uuid>';
```

### Testing RLS with SQL

```sql
-- Simulate a specific user's context
SET request.jwt.claim.sub = '<user-a-uuid>';

-- Should return only User A's data
SELECT count(*) FROM persons WHERE owner_id = '<user-a-uuid>';

-- Should return 0 (not User A's data)
SELECT count(*) FROM persons WHERE owner_id = '<user-b-uuid>';
```

### Child Table Access

```sql
-- Verify transaction_splits inherits access from parent transaction
-- User A should only see splits for their own transactions
SELECT ts.*
FROM transaction_splits ts
JOIN financial_transactions ft ON ts.transaction_id = ft.id
WHERE ft.owner_id = auth.uid();

-- This should be enforced by RLS policy, not just the JOIN
SELECT * FROM transaction_splits;  -- Should only return User A's splits
```

### INSERT Rejection

```sql
-- Attempting to insert a person for another user should fail
INSERT INTO persons (owner_id, name)
VALUES ('<other-user-uuid>', 'Hacker Test');
-- Expected: ERROR - new row violates RLS policy
```

### RLS Checklist

- [ ] `profiles`: Users can only read/update their own profile
- [ ] `persons`: Users can only CRUD their own persons (by `owner_id`)
- [ ] `user_groups`: Users can only CRUD their own groups (by `owner_id`)
- [ ] `group_members`: Users can only manage members of their own groups
- [ ] `subscriptions`: Users can only CRUD their own subscriptions (by `owner_id`)
- [ ] `subscription_subscribers`: Users can only manage subscribers of their own subscriptions
- [ ] `financial_transactions`: Users can only CRUD their own transactions (by `owner_id`)
- [ ] `transaction_splits`: Users can only manage splits of their own transactions
- [ ] `transaction_payers`: Users can only manage payers of their own transactions
- [ ] `settlements`: Users can only CRUD their own settlements (by `owner_id`)
- [ ] `reminders`: Users can only CRUD their own reminders (by `owner_id`)
- [ ] `chat_messages`: Users can only CRUD their own messages (by `owner_id`)
- [ ] `subscription_payments`: Users can only manage payments of their own subscriptions
- [ ] `subscription_settlements`: Users can only manage settlements of their own subscriptions
- [ ] `subscription_reminders`: Users can only manage reminders of their own subscriptions
- [ ] `device_tokens`: Users can only manage their own device tokens (by `user_id`)

---

## Storage Verification

### Photo Upload

```swift
// Test uploading a person's photo
let testImage = UIImage(systemName: "person.fill")!
let data = testImage.pngData()!

let path = try await StorageService.shared.uploadPhoto(
    imageData: data,
    entityType: "persons",
    entityId: UUID()
)
assert(!path.isEmpty, "Upload should return a storage path")
```

### Photo Download

```swift
// Test downloading the uploaded photo
let downloaded = try await StorageService.shared.downloadPhoto(path: path)
assert(!downloaded.isEmpty, "Download should return non-empty data")
```

### Private Bucket Access Control

```sql
-- Verify the photos bucket exists and is private
SELECT id, name, public
FROM storage.buckets
WHERE name = 'photos';
-- Expected: public = false
```

- [ ] Unauthenticated request to photo URL returns 401
- [ ] Authenticated user can only access photos in their own folder
- [ ] Signed URLs expire after the configured duration

### Storage Policies

```sql
-- List storage policies
SELECT policyname, tablename, cmd, qual
FROM pg_policies
WHERE schemaname = 'storage';
```

- [ ] INSERT policy: Users can upload to `{bucket}/persons/{their-person-id}/*`
- [ ] SELECT policy: Users can read their own photos
- [ ] DELETE policy: Users can delete their own photos

---

## Data Migration Verification

### Fresh Install (No Migration Needed)

- [ ] New user with no local data skips migration entirely
- [ ] `shouldRunMigration()` returns `false`
- [ ] App goes directly to main screen after auth

### Existing User Migration

- [ ] Migration screen appears after first sign-in
- [ ] Progress bar updates through all 16 steps
- [ ] Entity counts display correctly
- [ ] Migration completes without errors
- [ ] `supabase_migration_completed` is set to `true` in UserDefaults
- [ ] Subsequent app launches skip migration

### FK Order Verification

Test that all entities upload in correct dependency order:

```sql
-- After migration, verify data exists in correct order
-- Step 1: Profile exists
SELECT count(*) FROM profiles WHERE id = '<user-uuid>';
-- Expected: 1

-- Step 2: Self-person exists
SELECT count(*) FROM persons WHERE id = '<user-uuid>' AND owner_id = '<user-uuid>';
-- Expected: 1

-- Step 3: Other persons exist
SELECT count(*) FROM persons WHERE owner_id = '<user-uuid>' AND id != '<user-uuid>';

-- Step 4: Groups exist
SELECT count(*) FROM user_groups WHERE owner_id = '<user-uuid>';

-- Step 5: Group members exist
SELECT count(*) FROM group_members gm
JOIN user_groups ug ON gm.group_id = ug.id
WHERE ug.owner_id = '<user-uuid>';

-- Continue for all entity types...
```

### Photo Migration

- [ ] Person photos uploaded to `photos/persons/{person-id}.jpg`
- [ ] Group photos uploaded to `photos/groups/{group-id}.jpg`
- [ ] `photo_url` column updated in `persons` and `user_groups` tables
- [ ] Photos are accessible via signed URL

```sql
-- Verify photo URLs are populated
SELECT id, name, photo_url
FROM persons
WHERE owner_id = '<user-uuid>'
AND photo_url IS NOT NULL;
```

### UUID Remapping

```sql
-- Verify the old local current-user UUID does NOT appear anywhere
-- (should have been remapped to auth.users.id)
SELECT 'persons' as tbl, count(*) FROM persons WHERE id = '<old-local-uuid>'
UNION ALL
SELECT 'tx_payer', count(*) FROM financial_transactions WHERE payer_id = '<old-local-uuid>'
UNION ALL
SELECT 'tx_created_by', count(*) FROM financial_transactions WHERE created_by_id = '<old-local-uuid>'
UNION ALL
SELECT 'splits', count(*) FROM transaction_splits WHERE owed_by_id = '<old-local-uuid>'
UNION ALL
SELECT 'payers', count(*) FROM transaction_payers WHERE paid_by_id = '<old-local-uuid>'
UNION ALL
SELECT 'settlement_from', count(*) FROM settlements WHERE from_person_id = '<old-local-uuid>'
UNION ALL
SELECT 'settlement_to', count(*) FROM settlements WHERE to_person_id = '<old-local-uuid>';
-- Expected: ALL counts should be 0
```

### Balance Consistency

After migration, verify that server-calculated balances match local balances:

```swift
// For each person with a non-zero balance:
let localBalance = person.calculateBalance()
let serverResponse = try await SupabaseConfig.shared.client.functions
    .invoke("calculate-balance", options: .init(body: ["person_id": person.id!.uuidString]))
let serverBalance = try JSONDecoder().decode(BalanceResponse.self, from: serverResponse.data)

let diff = abs(localBalance.primaryAmount - serverBalance.primaryAmount)
assert(diff < 0.01, "Balance mismatch: local=\(localBalance.primaryAmount) server=\(serverBalance.primaryAmount)")
```

---

## Sync Verification

### CRUD to Supabase

Test each operation syncs correctly:

#### Create

- [ ] Create a new Person locally → appears in Supabase `persons` table
- [ ] Create a new Transaction locally → appears in `financial_transactions` with correct `payer_id`, `group_id`
- [ ] Create a new Settlement locally → appears in `settlements` with correct `from_person_id`, `to_person_id`

```sql
-- Verify new person synced
SELECT * FROM persons
WHERE owner_id = '<user-uuid>'
ORDER BY created_at DESC
LIMIT 1;
```

#### Update

- [ ] Edit a person's name locally → `name` updates in Supabase, `updated_at` advances
- [ ] Edit a transaction amount → `amount` updates in Supabase

```sql
-- Check updated_at advanced
SELECT id, name, updated_at
FROM persons
WHERE id = '<person-uuid>';
```

#### Delete

- [ ] Delete a person locally → `deleted_at` is set in Supabase (soft delete)
- [ ] Deleted person no longer appears in local `@FetchRequest` results

```sql
-- Verify soft delete
SELECT id, name, deleted_at
FROM persons
WHERE id = '<deleted-person-uuid>';
-- Expected: deleted_at IS NOT NULL
```

### Multi-Device Sync

- [ ] Create a transaction on Device A
- [ ] Open app on Device B → transaction appears after sync
- [ ] Edit transaction on Device B
- [ ] Open app on Device A → edit is reflected

### Offline to Online

- [ ] Put device in airplane mode
- [ ] Create 3 transactions, 1 settlement, 1 new person
- [ ] Disable airplane mode
- [ ] Verify all 5 records sync to Supabase within debounce window (5 seconds + network latency)

```sql
-- Check all 5 records appeared
SELECT 'persons' as tbl, count(*) FROM persons WHERE created_at > now() - interval '5 minutes'
UNION ALL
SELECT 'transactions', count(*) FROM financial_transactions WHERE created_at > now() - interval '5 minutes'
UNION ALL
SELECT 'settlements', count(*) FROM settlements WHERE created_at > now() - interval '5 minutes';
```

### Conflict Resolution

- [ ] Edit same person name on two devices while one is offline
- [ ] Bring both online
- [ ] Last-write-wins: the device with the later `updated_at` timestamp wins
- [ ] Both devices converge to the same value after sync

---

## Edge Function Verification

### calculate-balance

```bash
# Test with a real user JWT
curl -X POST https://fgcjijairsikaeshpiof.supabase.co/functions/v1/calculate-balance \
  -H "Authorization: Bearer <user-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"person_id": "<person-uuid>"}'

# Expected response:
# {"balances":{"USD":45.50},"is_settled":false,"primary_amount":45.50,"primary_currency":"USD"}
```

- [ ] Returns correct balances matching local calculation
- [ ] Returns 401 without JWT
- [ ] Returns 404 for person_id belonging to another user
- [ ] Returns `is_settled: true` for settled persons

### schedule-reminders

```bash
# Test with service role key
curl -X POST https://fgcjijairsikaeshpiof.supabase.co/functions/v1/schedule-reminders \
  -H "Authorization: Bearer <service-role-key>" \
  -H "Content-Type: application/json"

# Expected response:
# {"success":true,"reminders_created":2,"notifications_sent":1,"checked_at":"2026-02-18T..."}
```

- [ ] Creates reminders for subscriptions within notification window
- [ ] Does not duplicate reminders for same billing period
- [ ] Sends push notifications to device tokens

### send-push-notification

- [ ] Push notification received on iOS device
- [ ] Invalid device token is automatically cleaned from `device_tokens` table
- [ ] Notification contains correct title, body, and data payload

---

## Build Verification

### Xcode Build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -scheme "Swiss Coin" \
  -project "/Users/narenreddyagula/Documents/[05] Swisscoin/Swiss Coin/Swiss Coin.xcodeproj" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

- [ ] Build succeeds with no errors
- [ ] No warnings related to Supabase integration
- [ ] Supabase framework is properly linked

### Dependency Check

- [ ] `supabase-swift` v2.x resolves correctly via SPM
- [ ] All sub-modules available: Auth, PostgREST, Realtime, Storage, Functions
- [ ] No version conflicts with other dependencies

### File Checklist

New files that should exist after integration:

```
Swiss Coin/Services/
  SupabaseConfig.swift
  RemoteDataService.swift
  SupabaseDataService.swift
  SyncManager.swift
  StorageService.swift
  MigrationService.swift

Swiss Coin/Models/DTOs/
  PersonDTO.swift
  TransactionDTO.swift
  SplitDTO.swift
  PayerDTO.swift
  SettlementDTO.swift
  GroupDTO.swift
  MessageDTO.swift
  SubscriptionDTO.swift
  ProfileDTO.swift
```

---

## Performance Testing

### Sync Performance

- [ ] Full sync with 100 persons completes in < 10 seconds
- [ ] Full sync with 500 transactions completes in < 30 seconds
- [ ] Incremental sync (5 changed records) completes in < 2 seconds
- [ ] Background sync does not cause UI jank

### Storage Performance

- [ ] Photo upload (500KB JPEG) completes in < 3 seconds
- [ ] Photo download via signed URL completes in < 2 seconds
- [ ] AsyncImage caches photos correctly (no re-download on scroll)

### Memory

- [ ] No memory leaks during sync cycles (Profile in Instruments)
- [ ] CoreData context saves do not cause spikes
- [ ] Photo compression does not hold large images in memory

### Database Query Performance

```sql
-- Check query plan for common queries
EXPLAIN ANALYZE
SELECT * FROM financial_transactions
WHERE owner_id = '<user-uuid>'
ORDER BY date DESC
LIMIT 50;

-- Should use index scan, not sequential scan
-- Execution time should be < 10ms
```

---

## Verification SQL Cheat Sheet

Quick queries to verify the entire integration:

```sql
-- 1. Count all tables
SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';
-- Expected: 16

-- 2. Count all RLS policies
SELECT count(*) FROM pg_policies WHERE schemaname = 'public';
-- Expected: >= 16 (at least 1 per table)

-- 3. Count all triggers
SELECT count(*) FROM information_schema.triggers WHERE trigger_schema = 'public';
-- Expected: >= 14 (moddatetime triggers)

-- 4. Verify RLS is enabled on all tables
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';
-- Expected: ALL should have rowsecurity = true

-- 5. Count data for a specific user
SELECT
    (SELECT count(*) FROM persons WHERE owner_id = '<uuid>') as persons,
    (SELECT count(*) FROM user_groups WHERE owner_id = '<uuid>') as groups,
    (SELECT count(*) FROM financial_transactions WHERE owner_id = '<uuid>') as transactions,
    (SELECT count(*) FROM settlements WHERE owner_id = '<uuid>') as settlements,
    (SELECT count(*) FROM chat_messages WHERE owner_id = '<uuid>') as messages,
    (SELECT count(*) FROM subscriptions WHERE owner_id = '<uuid>') as subscriptions;

-- 6. Check for orphaned records (FK integrity)
SELECT 'orphaned_splits' as issue, count(*)
FROM transaction_splits ts
LEFT JOIN financial_transactions ft ON ts.transaction_id = ft.id
WHERE ft.id IS NULL
UNION ALL
SELECT 'orphaned_payers', count(*)
FROM transaction_payers tp
LEFT JOIN financial_transactions ft ON tp.transaction_id = ft.id
WHERE ft.id IS NULL
UNION ALL
SELECT 'orphaned_group_members', count(*)
FROM group_members gm
LEFT JOIN user_groups ug ON gm.group_id = ug.id
WHERE ug.id IS NULL;
-- Expected: ALL counts should be 0

-- 7. Check moddatetime is working
UPDATE persons SET name = name WHERE id = (SELECT id FROM persons LIMIT 1);
SELECT id, updated_at FROM persons ORDER BY updated_at DESC LIMIT 1;
-- updated_at should be within last few seconds

-- 8. Verify storage bucket
SELECT id, name, public FROM storage.buckets WHERE name = 'photos';
-- Expected: public = false
```

---

## Issue Reporting

When filing issues related to the Supabase integration, include:

1. **Supabase logs**: Dashboard > Logs > select service (API, Auth, Edge Functions)
2. **iOS console output**: Filter by "Swiss Coin" or "Supabase"
3. **Network trace**: Charles Proxy or Proxyman capture of the failing request
4. **SQL state**: Run the relevant verification queries above
5. **Sync state**: UserDefaults sync timestamps (`sync_last_push_*`, `sync_last_pull_*`)
