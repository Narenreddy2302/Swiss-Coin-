# Swiss Coin — Audit Report: Profile, Services, Utilities, Extensions, Components & CoreData Models

**Scan Date:** 2026-02-02  
**Auditor:** Claude (automated code audit)  
**Files Scanned:** 32  
**Project Root:** `/Swiss-Coin-/Swiss Coin/`

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Profile Views (6 files)](#profile-views)
3. [Services (3 files)](#services)
4. [Utilities (9 files)](#utilities)
5. [Extensions (2 files)](#extensions)
6. [Components (1 file)](#components)
7. [CoreData Models (11 files)](#coredata-models)
8. [Cross-Cutting Issues](#cross-cutting-issues)
9. [Critical Issues Summary](#critical-issues-summary)

---

## Executive Summary

| Category | Files | ✅ COMPLETE | 🔧 PARTIAL | ❌ MISSING | 🐛 BUGGY |
|----------|-------|------------|------------|-----------|----------|
| Profile | 6 | 5 | 1 | 0 | 0 |
| Services | 3 | 2 | 0 | 0 | 1 |
| Utilities | 9 | 7 | 1 | 0 | 1 |
| Extensions | 2 | 2 | 0 | 0 | 0 |
| Components | 1 | 1 | 0 | 0 | 0 |
| CoreData Models | 11 | 11 | 0 | 0 | 0 |
| **TOTAL** | **32** | **28** | **2** | **0** | **2** |

**Critical Issues Found:** 5  
**Warnings:** 12  
**Info/Recommendations:** 18  

---

## Profile Views

### 1. `Features/Profile/ProfileView.swift`
**Status:** ✅ COMPLETE

**What it does:** Main profile settings hub. Displays user avatar, name, currency. Links to Personal Details, Notifications, Privacy & Security, Appearance, Currency sub-views. Has Help, Feedback, Share, Version info, and Log Out.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ WARN | **Hidden NavigationLink pattern** (L67-70): Uses `NavigationLink.opacity(0)` behind a `onTapGesture` — this is a workaround that can cause accessibility issues. The same destination `PersonalDetailsView()` is linked twice (header at L70 AND Account section at L78). |
| 2 | ℹ️ INFO | `shareApp()` (L183-189): Uses `UIApplication.shared.connectedScenes` to get root VC for `UIActivityViewController` — standard but could fail on iPad if no window is found. |
| 3 | ℹ️ INFO | `logOut()` (L173): Calls `supabase.signOut()` in a Task but doesn't wait for completion before `dismiss()`. The dismiss happens synchronously while sign-out is still in-flight. |
| 4 | ℹ️ INFO | Hardcoded URLs: `https://swisscoin.app/help` and `https://swisscoin.app/feedback` (L107, L113). Should be centralized constants. |

**CoreData References:** ✅ Correct — uses `CurrentUser.getOrCreate(in:)` which returns `Person`.

---

### 2. `Features/Profile/PersonalDetailsView.swift`
**Status:** ✅ COMPLETE

**What it does:** Full profile editor: photo upload/removal, profile color picker, display name, full name, phone (read-only), email with validation. View model handles Supabase sync, CoreData local save, image resize/upload.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ WARN | **`loadCurrentUserData` stores originals BEFORE Supabase finishes** (L328-333): `originalDisplayName`, `originalFullName` etc. are set from CoreData values. The subsequent `loadFromSupabase()` async call updates them on completion, but there's a race window where `hasChanges` could be incorrectly `true`. |
| 2 | ℹ️ INFO | Magic number: image max dimension `800` (L463), compression quality `0.8` (L395), max file size `5 * 1024 * 1024` (L400). Should be named constants. |
| 3 | ℹ️ INFO | `formattedPhoneNumber` (L313-327): US-centric formatting. For a Swiss app, should handle Swiss phone formats (`+41 XX XXX XX XX`). Person+Extensions.swift already has Swiss formatting — **inconsistency**. |
| 4 | ℹ️ INFO | `ImagePicker` coordinator uses `[weak self]` correctly. Image resize logic is solid. |

**CoreData References:** ✅ Correct — `currentUser.name`, `currentUser.colorHex`, `context.save()`.

---

### 3. `Features/Profile/AppearanceSettingsView.swift`
**Status:** ✅ COMPLETE

**What it does:** Theme selection (light/dark/system), accent color picker, font size selector with preview, reduce motion, haptic feedback toggles, home screen settings (show balance, default tab). Auto-saves with debounced Combine pipeline. Syncs to Supabase.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ℹ️ INFO | `setupAutoSave()` fires immediately on first change due to `dropFirst()` — correct behavior, but first-time loading from Supabase will trigger an unnecessary save-back. |
| 2 | ℹ️ INFO | `ThemePreviewCard` is declared `struct` (not `private struct`) — exposed publicly but only used in this file. |
| 3 | ℹ️ INFO | Default values match between `@AppStorage` and `@Published`: ✅ consistent. |

**CoreData References:** N/A — uses `@AppStorage` and Supabase only.

---

### 4. `Features/Profile/CurrencySettingsView.swift`
**Status:** 🔧 PARTIAL

**What it does:** Currency selector with 20 currencies, search, display format options (symbol on/off, decimal places 0/2), preview.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ WARN | **No Supabase sync** — uses only `@AppStorage`. All other settings views sync to Supabase, but currency settings do NOT. This means currency preference is device-local only and won't survive device changes. |
| 2 | ⚠️ WARN | **Decimal places only offers 0 or 2** — no option for 1 or 3 (some currencies like KWD use 3). The Picker tag values are `0` and `2` only. |
| 3 | ℹ️ INFO | The `CurrencyFormatter` utility is hardcoded to CHF/Swiss locale but this view allows USD, EUR, etc. The two systems are disconnected. `CurrencyFormatter` ignores `@AppStorage("default_currency")`. |
| 4 | ℹ️ INFO | `formatPreview` (L129-137): Uses hardcoded `amount = 1234.56` — fine for preview. |
| 5 | ℹ️ INFO | No "Swiss Franc" is not listed first despite being the app's namesake. CHF is 8th in the list. |

**CoreData References:** N/A — `@AppStorage` only.

---

### 5. `Features/Profile/NotificationSettingsView.swift`
**Status:** ✅ COMPLETE

**What it does:** Comprehensive notification settings: master toggle, per-category toggles (transactions, reminders, subscriptions, settlements, groups, chat, summaries), quiet hours with time pickers, system permission check. Debounced auto-save to Supabase.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ℹ️ INFO | Very thorough implementation. 15+ individual notification toggles all properly synced. |
| 2 | ℹ️ INFO | `parseTime`/`formatTime` use `DateFormatter` with `"HH:mm"` — correct for 24h time strings. |
| 3 | ℹ️ INFO | System notification permission check on appear — good UX pattern. |

**CoreData References:** N/A — `@AppStorage` + Supabase.

---

### 6. `Features/Profile/PrivacySecurityView.swift`
**Status:** ✅ COMPLETE

**What it does:** Comprehensive security & privacy management: Face ID/Touch ID/Optic ID, PIN setup/verify (SHA256 hashed), auto-lock timeout, active sessions management, login history, blocked users, privacy toggles, data export, account deletion. Sub-views: `PINSetupView`, `PINVerifyView`, `ActiveSessionsView`, `LoginHistoryView`, `BlockedUsersView`.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | 🔴 CRIT | **PIN hashing uses bare SHA256 without salt** (L474, L559): `SHA256.hash(data: Data(pin.utf8))`. A 6-digit PIN has only 1M combinations. Without salt, this is trivially brute-forceable. Should use PBKDF2 or bcrypt with a random salt. |
| 2 | ⚠️ WARN | **`updateNotifyOnNewDevice` doesn't actually send the value** (L487-490): Creates empty `SecuritySettingsUpdate()` and ignores the `notify` parameter entirely. The `notifyOnNewDevice` state change is never persisted to Supabase. |
| 3 | ⚠️ WARN | **PIN lockout is client-side only** (L556-567): `attemptsRemaining` is a local `@State` variable. Restarting the app resets it to 5. Server-side PIN verification exists (`supabase.verifyPIN`) but is never called from `PINVerifyView`. |
| 4 | ℹ️ INFO | Biometric auth uses `evaluatePolicy` callback (not async/await). Works but mixing dispatch patterns. |
| 5 | ℹ️ INFO | `loadFromLocal()` handles default values carefully with `UserDefaults.standard.object(forKey:) as? Bool ?? true` pattern. |
| 6 | ℹ️ INFO | `PINSetupView` correctly requires PIN confirmation (enter + re-enter). |

**CoreData References:** N/A — `UserDefaults`, `KeychainHelper`, Supabase.

---

## Services

### 7. `Services/Persistence.swift`
**Status:** ✅ COMPLETE

**What it does:** Core Data stack setup. Singleton `PersistenceController` with `shared` and `preview` (in-memory) instances. Lightweight auto-migration enabled. Handles migration errors by destroying and recreating the store.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ WARN | **Silent data loss on migration failure** (L37-46): If migration fails (error codes 134140, 134130, 134110), the store is destroyed and recreated. In production, this silently deletes ALL user data. There's no user notification. |
| 2 | ℹ️ INFO | `preview` uses `/dev/null` for in-memory store — standard pattern. |
| 3 | ℹ️ INFO | Container name `"Swiss_Coin"` must match xcdatamodel filename exactly. |
| 4 | ℹ️ INFO | `fatalError` is NOT called on store load failure — app continues with potentially empty store. Good resilience, but user sees empty state without explanation. |

**CoreData References:** ✅ Standard NSPersistentContainer setup.

---

### 8. `Services/SupabaseManager.swift`
**Status:** 🐛 BUGGY

**What it does:** Centralized Supabase client. Handles OTP auth, session management, token refresh with retry, profile CRUD, settings management (appearance/notifications/privacy/security), blocked users, categories, photo upload/delete, data export, account deletion. ~1766 lines. Massive file with 40+ response/update model structs embedded.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | 🔴 CRIT | **Placeholder credentials in source** (L17-18): `SupabaseConfig.url = "https://your-project.supabase.co"` and `anonKey = "your-anon-key"`. These should be loaded from environment/config files, not hardcoded — even as placeholders, they establish a pattern where real keys could be committed. |
| 2 | 🔴 CRIT | **Infinite retry loop on 401** (L588-595): When a request gets 401, it calls `refreshToken()` then retries. If `refreshToken()` itself returns 401, this causes infinite recursion. No retry counter or flag to prevent recursive refresh. |
| 3 | ⚠️ WARN | **`generateUserIdFromPhone` uses `hashValue`** (L243-253): `String.hashValue` is NOT stable across app launches (randomized by Swift runtime). Users will get DIFFERENT UUIDs each time the app restarts, making local sessions unreliable. |
| 4 | ⚠️ WARN | **Deinit on MainActor-isolated class** (L108): `deinit` cancels `refreshTask`, but `deinit` runs on arbitrary threads. Swift concurrency warns about this. |
| 5 | ⚠️ WARN | **No request timeout for individual API calls**. `URLSession` config has 30s/60s timeouts but no per-request timeout. Long-running RPC calls could block indefinitely. |
| 6 | ℹ️ INFO | `AuthResponse` uses explicit `CodingKeys` with `access_token`/`refresh_token` but rest of file uses `keyDecodingStrategy = .convertFromSnakeCase`. This works but is inconsistent — `AuthResponse` will double-convert if not careful. Actually it's fine since explicit CodingKeys take precedence. |
| 7 | ℹ️ INFO | File is **1766 lines** — should be split into extensions or separate files (auth, profile, settings, sessions, etc.). |
| 8 | ℹ️ INFO | `TransactionCategory.id` is `UUID` but `SystemTransactionCategory.id` is `String` — two different category models with different ID types. |

**CoreData References:** N/A — network layer only. References `CurrentUser.currentUserId`.

---

### 9. `Services/ContactsManager.swift`
**Status:** ✅ COMPLETE

**What it does:** Contacts framework integration. Requests access, fetches all contacts with name, phone, email, thumbnail. Publishes to SwiftUI.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ℹ️ INFO | Clean implementation. `CNContactFetchRequest` with appropriate keys. |
| 2 | ℹ️ INFO | `fetchContacts()` is not paginated — fetches ALL contacts at once. Could be slow with large contact lists but acceptable for most use cases. |
| 3 | ℹ️ INFO | Not `@MainActor` annotated but updates `@Published` on `MainActor.run` — correct pattern. |

**CoreData References:** N/A.

---

## Utilities

### 10. `Utilities/BalanceCalculator.swift`
**Status:** ✅ COMPLETE

**What it does:** Extension on `Person` for balance calculation, mutual transaction retrieval, conversation item aggregation (transactions + settlements + reminders + messages), and date-grouped display. Defines `ConversationItem` enum and `ConversationDateGroup`.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ✅ GOOD | **CoreData properties correctly referenced**: `transaction.payer` ✅, `transaction.date` ✅, `split.owedBy` ✅, `split.amount` ✅, `transaction.splits` ✅. |
| 2 | ✅ GOOD | Settlement logic correctly differentiates `sentSettlements` (fromPerson=self) vs `receivedSettlements` (toPerson=self). |
| 3 | ℹ️ INFO | `getMutualTransactions()` casts `owedSplits as? Set<TransactionSplit>` and `toTransactions as? Set<FinancialTransaction>` — matches Person model properties. |
| 4 | ℹ️ INFO | `ConversationItem.id` uses `?? UUID()` fallback for nil IDs — creates new UUID each call, which could cause SwiftUI identity issues. Should use a stable fallback. |

**CoreData References:** ✅ All correct: `payer`, `date`, `owedBy`, `splits`, `sentSettlements`, `receivedSettlements`, `receivedReminders`, `chatMessages`.

---

### 11. `Utilities/CurrencyFormatter.swift`
**Status:** 🐛 BUGGY (Functional mismatch)

**What it does:** Static CHF currency formatter with format, formatAbsolute, formatDecimal, formatWithSign, formatCompact, parse.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | 🔴 CRIT | **Hardcoded to CHF/Swiss German locale** — ignores user's `@AppStorage("default_currency")` selection from `CurrencySettingsView`. Users who select USD, EUR, etc. will still see amounts formatted as CHF in any code path using this formatter. |
| 2 | ⚠️ WARN | `formatWithSign` threshold uses `0.01` — amounts between `-0.01` and `0.01` show no sign. This is correct for display but means a balance of `0.005` shows as unsigned. |
| 3 | ℹ️ INFO | `parse()` handles both `"CHF"` and `"Fr."` prefixes. Good. |

**CoreData References:** N/A.

---

### 12. `Utilities/CurrentUser.swift`
**Status:** ✅ COMPLETE

**What it does:** Manages current user identity. Stores UUID in UserDefaults, provides `isCurrentUser()`, `getOrCreate()` (finds or creates Person in CoreData), profile update, reset, and set methods.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ WARN | **User ID stored in UserDefaults** (L21-26): `UserDefaults.standard.string(forKey: "currentUserId")`. User IDs should be in Keychain (which is used for tokens but not the user ID). UserDefaults is backed up to iCloud and visible in backups. |
| 2 | ℹ️ INFO | `_currentUserId` uses lazy static initialization with closure — thread-safe in Swift. |
| 3 | ℹ️ INFO | `getOrCreate(in:)` properly handles the case where user doesn't exist — creates with defaults. |
| 4 | ℹ️ INFO | `updateProfile` calls `try? context.save()` — silently swallows save errors. |

**CoreData References:** ✅ Correct — `Person.fetchRequest()`, `person.id`, `person.name`, `person.colorHex`, `person.phoneNumber`, `person.photoData`.

---

### 13. `Utilities/DesignSystem.swift`
**Status:** ✅ COMPLETE

**What it does:** Centralized design tokens: `Spacing` (4pt grid, 8 values), `CornerRadius` (6 values), `IconSize` (6 values), `AvatarSize` (6 values), `ButtonHeight` (4 values), `AppAnimation` (5 presets), `AppColors` (semantic colors), `AppTypography` (13 font styles + 3 amount styles), button styles (`AppButtonStyle`, `PrimaryButtonStyle`, `SecondaryButtonStyle`), View extensions (`cardStyle`, `elevatedCardStyle`, `withHaptic`).

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ℹ️ INFO | `AppColors.background = Color.black` — hardcoded black. Doesn't adapt to light/dark mode. Other system colors use `Color(UIColor.secondarySystemBackground)` which DO adapt. Inconsistent. |
| 2 | ℹ️ INFO | Comprehensive and well-organized. All values follow a consistent naming pattern. |
| 3 | ℹ️ INFO | `AppButtonStyle` has a `HapticStyle` enum that duplicates `HapticManager` methods. Could just reference `HapticManager` directly. Minor. |

**CoreData References:** N/A.

---

### 14. `Utilities/Extensions.swift`
**Status:** ✅ COMPLETE (Minimal)

**What it does:** DateFormatter static instances (shortDate, longDate, shortDateTime). Contains a comment redirecting to `Person+Extensions.swift` for Person extensions.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ✅ GOOD | **No duplicate code** with `Person+Extensions.swift` — the comment clearly indicates Person properties are in the other file. |
| 2 | ℹ️ INFO | Only 3 DateFormatter instances. Very minimal file. Could be merged into DesignSystem or similar. |

**CoreData References:** N/A.

---

### 15. `Utilities/GroupBalanceCalculator.swift`
**Status:** ✅ COMPLETE

**What it does:** Extension on `UserGroup` for group balance calculation (overall, per-member), member categorization (who owes you / you owe), conversation items for groups, date grouping. Defines `GroupConversationItem` and `GroupConversationDateGroup`.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ✅ GOOD | **CoreData property references all correct**: `transaction.payer`, `split.owedBy`, `transaction.splits`, `transaction.date`, `settlement.amount`, `settlement.toPerson`, `settlement.fromPerson`. |
| 2 | ℹ️ INFO | `GroupConversationItem` and `GroupConversationDateGroup` are nearly identical to `ConversationItem` and `ConversationDateGroup` in `BalanceCalculator.swift`. Could share a protocol or generic type. |
| 3 | ℹ️ INFO | `displayName` and `initials` computed properties on `UserGroup` here duplicate similar logic in `Person+Extensions.swift` — same pattern, different entity. |
| 4 | ℹ️ INFO | `dateDisplayString` logic is identical between `ConversationDateGroup` and `GroupConversationDateGroup` — textbook DRY violation. |

**CoreData References:** ✅ All correct: `transactions`, `members`, `chatMessages` (on UserGroup), `payer`, `splits`, `owedBy`, `sentSettlements`, `receivedSettlements`, `receivedReminders`.

---

### 16. `Utilities/HapticManager.swift`
**Status:** ✅ COMPLETE

**What it does:** Centralized haptic feedback. Static generators for light/medium/heavy impact, selection, and notification feedback. Semantic wrappers: `save()`, `cancel()`, `delete()`, `toggle()`, `success()`, `warning()`, `error()`.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ℹ️ INFO | Clean, well-documented. Generators are pre-created as static properties (not lazily). This means they're alive for the app lifetime — acceptable overhead. |
| 2 | ℹ️ INFO | No `@AppStorage("haptic_feedback")` check. The appearance settings have a "Haptic Feedback" toggle but `HapticManager` doesn't consult it. Haptics will fire even when user disables them. |

**CoreData References:** N/A.

---

### 17. `Utilities/KeychainHelper.swift`
**Status:** ✅ COMPLETE

**What it does:** Keychain CRUD operations (save, read, delete, update, exists, deleteAll). Uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for security.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ✅ GOOD | Uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — good security. Data won't be included in backups or available when device is locked. |
| 2 | ℹ️ INFO | `deleteAll()` deletes ALL `kSecClassGenericPassword` items — not scoped to app. Could accidentally delete items from other apps sharing the same keychain group. Should add `kSecAttrService` to scope to this app. |
| 3 | ℹ️ INFO | No `kSecAttrService` set on any queries — items are stored with just `kSecAttrAccount` (key name). Should use a service identifier like `"com.swisscoin.app"`. |

**CoreData References:** N/A.

---

### 18. `Utilities/MockDataGenerator.swift`
**Status:** 🔧 PARTIAL

**What it does:** Development/test mock data generator. Creates 6 people, 3 groups, 25+ transactions, 5 settlements, 3 reminders, chat messages, and 6 subscriptions. Disabled by default (`isEnabled = false`).

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ✅ GOOD | `MockDataConfig.isEnabled` defaults to `false` — production safe. |
| 2 | ⚠️ WARN | **Force unwraps** in `createTransactions()` (L155-160): `people["Alex Johnson"]!`, `people["Sarah Chen"]!`, etc. If dict keys change, this crashes. |
| 3 | ℹ️ INFO | CoreData references are all correct: `FinancialTransaction.payer`, `.date`, `.splitMethod`, `.group`, `TransactionSplit.amount`, `.rawAmount`, `.owedBy`, `.transaction`, `Settlement.fromPerson`, `.toPerson`, `.isFullSettlement`, `Reminder.toPerson`, `.createdDate`, `.isRead`, `.isCleared`, `ChatMessage.withPerson`, `.withGroup`, `.isFromUser`, `.content`, `.timestamp`, `Subscription.subscribers`, `.cycle`, `.startDate`, `.isShared`. |
| 4 | ℹ️ INFO | Good variety of test data: equal splits, different payers, group/non-group, various amounts and dates. |
| 5 | ℹ️ INFO | `clearAllData` uses `NSBatchDeleteRequest` — efficient but doesn't trigger `NSManagedObjectContextDidSave` notifications. |

**CoreData References:** ✅ All correct.

---

## Extensions

### 19. `Extensions/Color+Hex.swift`
**Status:** ✅ COMPLETE

**What it does:** `Color(hex:)` initializer (supports 3/6/8 digit hex), `toHex()` converter, `isLight` brightness check, `contrastingColor` computed property.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ WARN | `toHex()` assumes `cgColor.components` has at least 3 elements (L46-50). Grayscale colors have only 2 components (white + alpha). Will crash with `Index out of range` on grayscale `Color.gray`, `Color.white`, etc. |
| 2 | ℹ️ INFO | `isLight` has the same grayscale components issue. |
| 3 | ℹ️ INFO | Fallback color in `init(hex:)` default case is blue `(0, 122, 255)` — matches `#007AFF`. |

**CoreData References:** N/A.

---

### 20. `Extensions/Person+Extensions.swift`
**Status:** ✅ COMPLETE

**What it does:** Computed properties on `Person`: `displayName`, `firstName`, `initials`, `safeName`, `safeColorHex`, `displayColor`, `avatarBackgroundColor`, `avatarTextColor`, `formattedPhoneNumber` (Swiss format), `hasContactInfo`, `hasCustomPhoto`, `alphabeticalSortDescriptor`, `compare(to:)`.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ✅ GOOD | **No duplication** with `Extensions.swift` — that file explicitly defers to this one via comment. |
| 2 | ℹ️ INFO | Phone formatting handles Swiss numbers (`+41` prefix) and 9-digit local numbers. Different from `PersonalDetailsViewModel.formattedPhoneNumber` which uses US formatting. **Inconsistency** (see cross-cutting issues). |
| 3 | ℹ️ INFO | `safeColorHex` defaults to `"#808080"` (gray) while `CurrentUser.defaultColorHex` is `"#007AFF"` (blue). Different fallback colors. |
| 4 | ℹ️ INFO | All property accesses are safe — nil-checks on `name`, `colorHex`, `phoneNumber`. |

**CoreData References:** ✅ Correct — references `name`, `colorHex`, `phoneNumber`, `photoData` — all exist on `Person` model.

---

## Components

### 21. `Components/ActionHeaderButton.swift`
**Status:** ✅ COMPLETE

**What it does:** Reusable segmented-style button with icon + title, tap animation, press state. Used in SubscriptionView.

**Findings:**

| # | Severity | Issue |
|---|----------|-------|
| 1 | ℹ️ INFO | Uses `onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, ...)` for press detection — standard SwiftUI workaround for tracking press state. |
| 2 | ℹ️ INFO | Correctly uses `DesignSystem` constants (`Spacing`, `IconSize`, `CornerRadius`, `AppAnimation`, `AppColors`, `AppTypography`). |

**CoreData References:** N/A.

---

## CoreData Models

### 22. `Models/CoreData/Person.swift`
**Status:** ✅ COMPLETE

**Schema Match:** ✅

**Attributes:** `id: UUID?`, `name: String?`, `phoneNumber: String?`, `photoData: Data?`, `colorHex: String?`

**Relationships:**
- `toTransactions: NSSet?` → FinancialTransaction (inverse of `payer`)
- `toGroups: NSSet?` → UserGroup (inverse of `members`)
- `toSubscriptions: NSSet?` → Subscription (inverse of `subscribers`)
- `owedSplits: NSSet?` → TransactionSplit (inverse of `owedBy`)
- `sentSettlements: NSSet?` → Settlement (inverse of `fromPerson`)
- `receivedSettlements: NSSet?` → Settlement (inverse of `toPerson`)
- `receivedReminders: NSSet?` → Reminder (inverse of `toPerson`)
- `chatMessages: NSSet?` → ChatMessage (inverse of `withPerson`)
- `subscriptionPayments: NSSet?` → SubscriptionPayment (inverse of `payer`)
- `sentSubscriptionSettlements: NSSet?` → SubscriptionSettlement (inverse of `fromPerson`)
- `receivedSubscriptionSettlements: NSSet?` → SubscriptionSettlement (inverse of `toPerson`)
- `receivedSubscriptionReminders: NSSet?` → SubscriptionReminder (inverse of `toPerson`)

**Generated Accessors:** ✅ All 12 relationship accessors present with add/remove for Object and NSSet.

---

### 23. `Models/CoreData/FinancialTransaction.swift`
**Status:** ✅ COMPLETE

**Schema Match:** ✅

**Attributes:** `id: UUID?`, `title: String?`, `amount: Double`, `date: Date?`, `splitMethod: String?`  
**Relationships:** `payer: Person?`, `group: UserGroup?`, `splits: NSSet?`

**Verification:**
- ✅ `payer` (not `paidBy`)
- ✅ `date` (not `createdAt`)
- ✅ `splits` to `TransactionSplit`

---

### 24. `Models/CoreData/TransactionSplit.swift`
**Status:** ✅ COMPLETE

**Schema Match:** ✅

**Attributes:** `amount: Double`, `rawAmount: Double`  
**Relationships:** `owedBy: Person?`, `transaction: FinancialTransaction?`

**Verification:**
- ✅ NO `id` attribute — correct per schema
- ✅ `owedBy` (not `person`)
- ✅ `rawAmount` present
- ⚠️ Conforms to `Identifiable` but has no `id` — uses `ObjectIdentifier` via NSManagedObject. This works because NSManagedObject inherits NSObject which provides a stable identity, but if used in ForEach, it relies on object identity, not a stable UUID.

---

### 25. `Models/CoreData/Settlement.swift`
**Status:** ✅ COMPLETE

**Schema Match:** ✅

**Attributes:** `id: UUID?`, `amount: Double`, `date: Date?`, `note: String?`, `isFullSettlement: Bool`  
**Relationships:** `fromPerson: Person?`, `toPerson: Person?`

---

### 26. `Models/CoreData/Reminder.swift`
**Status:** ✅ COMPLETE

**Schema Match:** ✅

**Attributes:** `id: UUID?`, `createdDate: Date?`, `amount: Double`, `message: String?`, `isRead: Bool`, `isCleared: Bool`  
**Relationships:** `toPerson: Person?`

---

### 27. `Models/CoreData/ChatMessage.swift`
**Status:** ✅ COMPLETE

**Schema Match:** ✅

**Attributes:** `id: UUID?`, `content: String?`, `timestamp: Date?`, `isFromUser: Bool`  
**Relationships:** `withPerson: Person?`, `withGroup: UserGroup?`, `withSubscription: Subscription?`

---

### 28. `Models/CoreData/UserGroup.swift`
**Status:** ✅ COMPLETE

**Schema Match:** ✅

**Attributes:** `id: UUID?`, `name: String?`, `photoData: Data?`, `colorHex: String?`, `createdDate: Date?`  
**Relationships:** `members: NSSet?` (Person), `transactions: NSSet?` (FinancialTransaction), `chatMessages: NSSet?` (ChatMessage)

---

### 29. `Models/CoreData/Subscription.swift`
**Status:** ✅ COMPLETE

**Schema Match:** ✅

**Attributes:** `id: UUID?`, `name: String?`, `amount: Double`, `cycle: String?`, `customCycleDays: Int16`, `startDate: Date?`, `nextBillingDate: Date?`, `isShared: Bool`, `isActive: Bool`, `category: String?`, `iconName: String?`, `colorHex: String?`, `notes: String?`, `notificationEnabled: Bool`, `notificationDaysBefore: Int16`  
**Relationships:** `subscribers: NSSet?` (Person), `payments: NSSet?` (SubscriptionPayment), `chatMessages: NSSet?` (ChatMessage), `reminders: NSSet?` (SubscriptionReminder), `settlements: NSSet?` (SubscriptionSettlement)

---

### 30. `Models/CoreData/SubscriptionPayment.swift`
**Status:** ✅ COMPLETE

**Schema Match:** ✅

**Attributes:** `id: UUID?`, `amount: Double`, `date: Date?`, `billingPeriodStart: Date?`, `billingPeriodEnd: Date?`, `note: String?`  
**Relationships:** `subscription: Subscription?`, `payer: Person?`

---

### 31. `Models/CoreData/SubscriptionSettlement.swift`
**Status:** ✅ COMPLETE

**Schema Match:** ✅

**Attributes:** `id: UUID?`, `amount: Double`, `date: Date?`, `note: String?`  
**Relationships:** `subscription: Subscription?`, `fromPerson: Person?`, `toPerson: Person?`

---

### 32. `Models/CoreData/SubscriptionReminder.swift`
**Status:** ✅ COMPLETE

**Schema Match:** ✅

**Attributes:** `id: UUID?`, `createdDate: Date?`, `amount: Double`, `message: String?`, `isRead: Bool`  
**Relationships:** `subscription: Subscription?`, `toPerson: Person?`

---

## Cross-Cutting Issues

### Issue A: Phone Number Formatting Inconsistency
| Location | Format |
|----------|--------|
| `PersonalDetailsViewModel.formattedPhoneNumber` | **US format**: `(555) 123-4567`, `+1 (555) 123-4567` |
| `Person+Extensions.formattedPhoneNumber` | **Swiss format**: `+41 XX XXX XX XX` |

**Impact:** The same phone number will display differently in Personal Details vs contact lists. For a **Swiss** app, all formatting should be Swiss.

### Issue B: CurrencyFormatter vs CurrencySettingsView Disconnect
- `CurrencyFormatter` is hardcoded to CHF with `Locale(identifier: "de_CH")`
- `CurrencySettingsView` allows selecting 20 currencies (USD, EUR, GBP, etc.)
- No code bridges the user's currency selection to actual formatting
- **Impact:** User changes currency to USD but amounts still display as CHF everywhere `CurrencyFormatter` is used.

### Issue C: Duplicate Conversation Item Types
- `ConversationItem` + `ConversationDateGroup` in `BalanceCalculator.swift`
- `GroupConversationItem` + `GroupConversationDateGroup` in `GroupBalanceCalculator.swift`
- These are nearly identical enums/structs with identical `dateDisplayString` logic.
- **Recommendation:** Extract shared protocol or generic type.

### Issue D: HapticManager Ignores User Preference
- `AppearanceSettingsView` has a "Haptic Feedback" toggle stored as `@AppStorage("haptic_feedback")`
- `HapticManager` has no awareness of this setting — always fires.
- **Impact:** User disabling haptics has no effect.

### Issue E: Default Color Inconsistencies
| Location | Default Color |
|----------|--------------|
| `Person+Extensions.safeColorHex` | `#808080` (gray) |
| `CurrentUser.defaultColorHex` | `#007AFF` (blue) |
| `PersonalDetailsViewModel.profileColor` | `#34C759` (green) |
| `ProfileView.userColor` fallback | `#34C759` (green) |
| `Color+Hex.init(hex:)` fallback | `(0, 122, 255)` = `#007AFF` (blue) |

Should be a single source of truth.

---

## Critical Issues Summary

### 🔴 CRITICAL (Must Fix)

| # | File | Issue |
|---|------|-------|
| C1 | `PrivacySecurityView.swift` | **Unsalted SHA256 for PIN** — 6-digit PIN trivially brute-forceable. Use PBKDF2/bcrypt with random salt. |
| C2 | `SupabaseManager.swift` | **Infinite 401 retry loop** — no recursion guard on token refresh. Will stack overflow if refresh token is also expired. |
| C3 | `SupabaseManager.swift` | **Placeholder credentials in source** — establishes dangerous pattern. Use `.xcconfig` or environment variables. |
| C4 | `CurrencyFormatter.swift` | **Hardcoded CHF ignores user currency setting** — currency selection UI is non-functional. |
| C5 | `SupabaseManager.swift` | **`String.hashValue` for UUID generation** — not stable across launches. Local sessions break on restart. |

### ⚠️ WARNINGS (Should Fix)

| # | File | Issue |
|---|------|-------|
| W1 | `CurrencySettingsView.swift` | No Supabase sync — currency is device-local only |
| W2 | `PrivacySecurityView.swift` | `updateNotifyOnNewDevice` sends empty update, value is lost |
| W3 | `PrivacySecurityView.swift` | PIN lockout is client-side only, resets on app restart |
| W4 | `Persistence.swift` | Silent data destruction on migration failure |
| W5 | `Color+Hex.swift` | `toHex()` and `isLight` crash on grayscale colors |
| W6 | `MockDataGenerator.swift` | Force unwraps on dictionary lookups |
| W7 | `CurrentUser.swift` | User ID in UserDefaults instead of Keychain |
| W8 | `KeychainHelper.swift` | No `kSecAttrService` — items not scoped to app |
| W9 | `PersonalDetailsView.swift` | US phone formatting in a Swiss app |
| W10 | `HapticManager.swift` | Ignores user's haptic feedback preference toggle |
| W11 | `DesignSystem.swift` | `AppColors.background = Color.black` doesn't adapt to light mode |
| W12 | `SupabaseManager.swift` | `deinit` on `@MainActor` class — thread-safety concern |

### ℹ️ RECOMMENDATIONS

| # | Category | Recommendation |
|---|----------|---------------|
| R1 | Architecture | Split `SupabaseManager.swift` (1766 lines) into separate files per domain |
| R2 | DRY | Unify `ConversationItem`/`GroupConversationItem` and their date groups |
| R3 | DRY | Unify default color constants into single source of truth |
| R4 | Currency | Make `CurrencyFormatter` respect `@AppStorage("default_currency")` |
| R5 | Currency | Move CHF to top of currency list (Swiss app) |
| R6 | UX | Add user notification when migration destroys data |
| R7 | Security | Scope Keychain items with `kSecAttrService` |
| R8 | Stability | Add retry counter to SupabaseManager 401 handler |
| R9 | Stability | Fix `ConversationItem.id` to use stable fallback instead of `UUID()` |
| R10 | Testing | Make MockDataGenerator use `guard let` instead of force unwraps |
| R11 | Code Quality | Profile URLs should be constants, not inline strings |
| R12 | Accessibility | Fix hidden NavigationLink pattern in ProfileView |
| R13 | Phone Format | Standardize on Swiss phone formatting throughout |
| R14 | CoreData | `TransactionSplit` has no `id` — verify ForEach usage doesn't cause issues |
| R15 | Security | Use `CryptoKit` HKDF or PBKDF2 for PIN hashing with per-user salt |
| R16 | Consistency | `@AppStorage` key names should follow a consistent naming convention |
| R17 | Resilience | Add server-side PIN lockout validation (use `supabase.verifyPIN`) |
| R18 | Resilience | Use stable hash (SHA256) instead of `String.hashValue` for phone-based UUID |
