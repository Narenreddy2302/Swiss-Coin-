# SWISS COIN — COMPREHENSIVE CODEBASE AUDIT REPORT

**Date:** 2026-02-06
**Codebase:** `/home/user/Swiss-Coin-/` — iOS native SwiftUI + CoreData personal finance app
**Files Analyzed:** 124 Swift source files, 6 SQL migrations, project configuration, assets, tests
**Audit Scope:** Feature completeness, UI/UX, architecture, security, performance, backend integration, App Store compliance, testing

---

## Problem #1, CRITICAL, App Store Compliance, Privacy Manifest (PrivacyInfo.xcprivacy) Missing

- **What is broken:** No Privacy Manifest file exists anywhere in the project, which is mandatory for all iOS 17+ apps submitted to the App Store.
- **Location:** Project root and `Swiss Coin/` directory — file `PrivacyInfo.xcprivacy` does not exist
- **Current behavior:** App builds and runs without a Privacy Manifest; the app accesses Contacts, Face ID, Photo Library, and UserDefaults (all privacy-relevant APIs)
- **Expected behavior:** A complete `PrivacyInfo.xcprivacy` declaring all accessed API categories (NSPrivacyAccessedAPITypes), tracking domains, and data collection disclosures
- **Why this blocks launch:** Apple rejects all new submissions and updates without a valid Privacy Manifest as of spring 2024. This is an automatic rejection with no human review override.
- **Fix required:** Create `PrivacyInfo.xcprivacy` at project root declaring: NSPrivacyAccessedAPICategoryUserDefaults (used extensively), NSPrivacyAccessedAPICategoryFileTimestamp if applicable, NSPrivacyTracking = NO, and list all NSPrivacyAccessedAPITypeReasons. Add to Xcode target build phases.

---

## Problem #2, CRITICAL, App Store Compliance, App Icon Assets Missing — Only JSON Config Present

- **What is broken:** The AppIcon asset catalog contains only a `Contents.json` manifest referencing 1024x1024 variants, but no actual PNG image files exist in the asset set.
- **Location:** `Swiss Coin/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- **Current behavior:** Build may succeed with a blank/missing icon; App Store Connect will reject the binary during upload validation
- **Expected behavior:** Complete icon set with at least the 1024x1024 universal icon PNG file present, plus dark and tinted variants if declared
- **Why this blocks launch:** App Store Connect rejects binaries missing the required app icon. The app cannot be submitted without it.
- **Fix required:** Export the app icon as a 1024x1024 PNG file, place it in the `AppIcon.appiconset/` directory with the correct filename referenced in `Contents.json`. Verify with `actool` or Xcode build that the icon resolves.

---

## Problem #3, CRITICAL, Testing, Zero Test Coverage — All Test Files Are Empty Stubs

- **What is broken:** The entire test suite consists of empty placeholder methods with no assertions, no test logic, and no coverage of any feature.
- **Location:** `Swiss CoinTests/Swiss_CoinTests.swift` (1 empty `example()` method), `Swiss CoinUITests/Swiss_CoinUITests.swift` (2 empty methods), `Swiss CoinUITests/Swiss_CoinUITestsLaunchTests.swift` (screenshot-only)
- **Current behavior:** All tests "pass" because they assert nothing; `example()` is a blank function body; UI tests only launch the app
- **Expected behavior:** Minimum 60% coverage of financial calculation logic (BalanceCalculator, GroupBalanceCalculator, TransactionViewModel split math), persistence layer tests, and critical path UI tests for transaction creation and settlement flows
- **Why this blocks launch:** No test coverage means regressions ship silently, financial calculations are unverified, and Apple's TestFlight review may flag an untested app. Any last-minute change could introduce a crash with zero safety net.
- **Fix required:** Write unit tests for: BalanceCalculator.calculateBalance(), GroupBalanceCalculator.calculateMemberBalances(), TransactionViewModel.calculateSplit() (all 5 split methods), CurrencyFormatter.format()/parse(), CurrentUser singleton, and Persistence CoreData stack. Write UI tests for: onboarding flow, transaction creation, settlement flow, subscription creation.

---

## Problem #4, CRITICAL, Backend Integration, Supabase Backend Completely Disconnected — Zero Network Calls

- **What is broken:** Despite 8,000+ lines of production-quality Supabase SQL migrations defining 60+ tables with RLS policies, the iOS app makes zero network requests. `SupabaseManager.swift` is a local-only `AuthManager` aliased via `typealias`.
- **Location:** `Swiss Coin/Services/SupabaseManager.swift` (entire file), `supabase/migrations/001-006_*.sql` (all migrations unused)
- **Current behavior:** All data stays on-device in CoreData. No sync, no cloud backup, no multi-device support. No URLSession, no REST calls, no Supabase Swift SDK imported. The class explicitly states "No external dependencies or network calls — fully offline."
- **Expected behavior:** Either (A) full Supabase integration with auth, real-time sync, conflict resolution, and offline queue, or (B) explicit offline-first design with the misleading Supabase naming removed
- **Why this blocks launch:** If multi-user or cloud sync is a product requirement, the entire backend is dead. Users lose all data on app uninstall. The `PhoneLoginView` suggests phone authentication that doesn't exist, which could be flagged as deceptive by App Review.
- **Fix required:** Decision point: (A) Integrate `supabase-swift` SDK, implement real phone+OTP auth, create sync layer between CoreData and Supabase tables, add offline queue with conflict resolution, OR (B) remove all Supabase references, rename `SupabaseManager` to `LocalAuthManager`, update `PhoneLoginView` to remove phone auth pretense, and delete unused SQL migrations.

---

## Problem #5, CRITICAL, Security, Authentication Is Fake — No Actual Identity Verification

- **What is broken:** `PhoneLoginView` displays a phone number input and "Get Started" button, but `authenticate()` simply generates a random UUID and stores it in UserDefaults. No OTP, no server validation, no identity verification of any kind.
- **Location:** `Swiss Coin/Features/Auth/PhoneLoginView.swift`, `Swiss Coin/Services/SupabaseManager.swift` (AuthManager class)
- **Current behavior:** User enters any phone number (or none), taps "Get Started," app creates a random UUID, sets `authState = .authenticated`, stores `swiss_coin_signed_out = false` in UserDefaults. Any person with the device is "authenticated."
- **Expected behavior:** Phone number validated, OTP sent via SMS, OTP verified server-side, session token generated and stored in Keychain, session expiration and refresh implemented
- **Why this blocks launch:** A finance app with no real authentication is a security liability. The UI suggesting phone login when none exists could trigger App Review rejection under guideline 2.3.1 (accurate metadata). Auth state in plaintext UserDefaults can be trivially manipulated.
- **Fix required:** Either implement real phone+OTP authentication via Supabase Auth (or Firebase Auth), store session tokens in Keychain, add session expiration handling, OR redesign the onboarding to honestly present the app as a local-only tool with no account, removing the phone number input entirely.

---

## Problem #6, CRITICAL, Data Integrity, Floating-Point Double Used for All Currency Amounts

- **What is broken:** Every monetary value in the entire app — transactions, splits, settlements, subscriptions, payments — uses IEEE 754 `Double`, which cannot represent decimal fractions exactly.
- **Location:** CoreData model `Swiss_Coin.xcdatamodel/contents` (all amount attributes), `FinancialTransaction.swift:22`, `TransactionSplit.swift:20-21`, `Settlement.swift:21`, `Subscription.swift:22`, `SubscriptionPayment.swift:21`, `BalanceCalculator.swift:13-54`, `GroupBalanceCalculator.swift:17-42`
- **Current behavior:** `0.1 + 0.2 = 0.30000000000000004` in Double arithmetic. Errors compound across hundreds of transactions. A user splitting $100.00 three ways gets `33.333333...` per person, totaling `99.999999...` — a penny vanishes.
- **Expected behavior:** All monetary calculations use `Decimal` (NSDecimalNumber) or integer cents to guarantee exact arithmetic. Rounding applied at calculation boundaries.
- **Why this blocks launch:** A personal finance app that miscalculates money is fundamentally broken. Users will notice balance discrepancies. This is a trust-destroying bug for a financial product.
- **Fix required:** Migrate all CoreData amount attributes from `Double` to `Decimal` (attributeType="Decimal"). Update `BalanceCalculator`, `GroupBalanceCalculator`, `TransactionViewModel.calculateSplit()`, and `CurrencyFormatter` to use `Decimal` arithmetic. Apply banker's rounding (`NSDecimalNumber.RoundingMode.bankers`) at display boundaries.

---

## Problem #7, CRITICAL, Security, Sensitive PII Stored Unencrypted in UserDefaults

- **What is broken:** User email, full name, user UUID, authentication flags, and privacy preferences are stored in plaintext UserDefaults instead of the Keychain.
- **Location:** `Swiss Coin/Features/Profile/PersonalDetailsView.swift:490-491,540-541` (email, full name), `Swiss Coin/Utilities/CurrentUser.swift:22-27,141` (user UUID), `Swiss Coin/Features/Profile/PrivacySecurityView.swift:54-60,89,101,110,117` (biometric_enabled, pin_enabled, auto_lock_timeout, show_balance_to_contacts, show_last_seen)
- **Current behavior:** `UserDefaults.standard.string(forKey: "user_email")`, `UserDefaults.standard.string(forKey: "user_full_name")`, `UserDefaults.standard.set(id.uuidString, forKey: "currentUserId")` — all plaintext, backed up to iCloud, readable on jailbroken devices
- **Expected behavior:** All PII (email, name, user ID) stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Security flags (biometric_enabled, pin_enabled) stored in Keychain to prevent tampering.
- **Why this blocks launch:** UserDefaults is not encrypted, is included in device backups, and can be read by other apps on compromised devices. Storing financial app user identity in plaintext is a security violation that could fail App Review under guideline 5.1.1 (data collection and storage).
- **Fix required:** Migrate `user_email`, `user_full_name`, and `currentUserId` from UserDefaults to `KeychainHelper.save()`. Migrate security flags (`biometric_enabled`, `pin_enabled`) to Keychain. Keep only non-sensitive display preferences (theme, font size) in UserDefaults/AppStorage.

---

## Problem #8, CRITICAL, Security, PIN Hash Uses SHA256 Without Salt or Rate Limiting

- **What is broken:** The app's PIN protection hashes the 6-digit PIN with plain SHA256 and no salt, making it trivially reversible via precomputed lookup table (only 1,000,000 possible inputs).
- **Location:** `Swiss Coin/Features/Profile/PrivacySecurityView.swift:104-112` (savePIN function)
- **Current behavior:** `SHA256.hash(data: Data(pin.utf8))` produces an unsalted hash stored in Keychain. No rate limiting on failed PIN attempts. No lockout mechanism. No brute-force protection.
- **Expected behavior:** PIN hashed with PBKDF2 (or Argon2) using a random 16-byte salt, 100,000+ iterations. Salt stored alongside hash in Keychain. Rate limiting: 5 failed attempts triggers 30-second lockout, 10 attempts triggers 5-minute lockout. PIN memory cleared after verification.
- **Why this blocks launch:** An attacker with Keychain access (jailbroken device, backup extraction) can reverse any 6-digit SHA256 hash in under 1 second using a precomputed table. This renders the entire PIN security feature useless for a financial app.
- **Fix required:** Replace `SHA256.hash()` with `CCKeyDerivationPBKDF` using `kCCPBKDF2` algorithm, random 16-byte salt, and minimum 100,000 rounds. Store salt+hash together in Keychain. Implement attempt counter with exponential backoff lockout stored in Keychain (not UserDefaults, to prevent tampering).

---

## Problem #9, CRITICAL, Data Integrity, CurrentUser Singleton Has Race Condition — Not Thread-Safe

- **What is broken:** `CurrentUser._currentUserId` is a static mutable variable read and written from multiple threads without synchronization, causing potential race conditions in balance calculations and transaction attribution.
- **Location:** `Swiss Coin/Utilities/CurrentUser.swift:19-29` (static var _currentUserId), `CurrentUser.swift:45-48` (isCurrentUser reads without lock), `CurrentUser.swift:127-142` (setCurrentUser writes without lock)
- **Current behavior:** Thread 1 calls `setCurrentUser(userA)` while Thread 2 calls `isCurrentUser(userB)` — result is undefined. CoreData background contexts trigger balance recalculations on background threads that read `_currentUserId` concurrently with main thread writes.
- **Expected behavior:** All access to `_currentUserId` synchronized via `NSLock`, `DispatchQueue`, or `@MainActor` annotation. Read-write access serialized.
- **Why this blocks launch:** Race condition in `isCurrentUser()` means balance calculations could attribute transactions to the wrong user, showing incorrect amounts owed. In a finance app, showing wrong balances is a critical trust failure that could also lead to incorrect settlements.
- **Fix required:** Add `private static let lock = NSLock()` to `CurrentUser`. Wrap all reads and writes to `_currentUserId` in `lock.lock()`/`lock.unlock()`. Alternatively, mark the entire `CurrentUser` struct with `@MainActor` to confine all access to the main thread.

---

## Problem #10, HIGH, Data Integrity, TransactionSplit Entity Missing Primary Key (No UUID)

- **What is broken:** The `TransactionSplit` CoreData entity has no `id` attribute, making individual splits impossible to uniquely identify, reference, or sync.
- **Location:** `Swiss Coin/Resources/Swiss_Coin.xcdatamodeld/Swiss_Coin.xcdatamodel/contents:104-108`, `Swiss Coin/Models/CoreData/TransactionSplit.swift`
- **Current behavior:** TransactionSplit has only `amount` (required Double) and `rawAmount` (optional Double) plus relationships. No UUID. Splits are identified only by their relationship to a transaction and person — not unique if same person appears in multiple splits.
- **Expected behavior:** Every entity has a UUID primary key for unique identification, future backend sync compatibility, and audit trail integrity
- **Why this blocks launch:** Without a primary key, individual splits cannot be updated, referenced in settlements, or synced to any backend. If Supabase integration is ever implemented, this entity cannot map to the `transaction_splits` table which expects a UUID primary key.
- **Fix required:** Add `id` attribute (UUID, required, indexed) to TransactionSplit entity in the CoreData model. Generate UUIDs on creation. Add lightweight migration to populate existing records.

---

## Problem #11, HIGH, Data Integrity, Cascade Delete Rules Destroy Transaction History on Person Deletion

- **What is broken:** Deleting a `Person` entity cascades deletion to all their transactions, splits, settlements, reminders, chat messages, and subscription payments — permanently destroying financial history.
- **Location:** `Swiss_Coin.xcdatamodel/contents:9-17` — Person entity relationships: `toTransactions` (Cascade), `owedSplits` (Cascade), `fromSettlements` (Cascade), `toSettlements` (Cascade), `reminders` (Cascade), `chatMessages` (Cascade), `subscriptionPayments` (Cascade)
- **Current behavior:** Deleting a person removes every transaction they paid for, every split they owed, and every settlement — wiping financial records that involve other people
- **Expected behavior:** Soft delete via `isDeleted` flag or `Nullify` delete rule that preserves transaction history while removing the person from active views
- **Why this blocks launch:** A user deleting a contact loses all shared financial history. If Person A deletes Person B, all transactions B paid for (which may involve Persons C, D, E) are also destroyed. This is catastrophic data loss affecting multiple users' records.
- **Fix required:** Change all Person relationship delete rules from `Cascade` to `Nullify`. Implement soft delete with `isArchived` or `isDeleted` boolean flag on Person. Filter archived persons from active views but preserve their transaction and settlement history.

---

## Problem #12, HIGH, Data Integrity, FinancialTransaction.payer Is Optional — Transactions Without a Payer

- **What is broken:** The `payer` relationship on `FinancialTransaction` is marked optional in the CoreData model, allowing transactions to exist without anyone designated as the person who paid.
- **Location:** `Swiss_Coin.xcdatamodel/contents:99` — `<relationship name="payer" optional="YES">`
- **Current behavior:** A transaction can be saved with `payer = nil`. Balance calculations in `BalanceCalculator.swift:21-25` check `if transaction.payer == self` which evaluates to false for nil payers, silently excluding these transactions from all balance computations.
- **Expected behavior:** Every financial transaction must have a payer. The relationship should be non-optional with creation-time validation enforcing this invariant.
- **Why this blocks launch:** Orphaned transactions with no payer create invisible balance discrepancies. Money is recorded as spent but attributed to nobody, making balances incorrect without any visible error.
- **Fix required:** Make `payer` relationship non-optional in CoreData model. Add validation in `TransactionViewModel.saveTransaction()` to reject transactions without a payer. Add migration to audit existing transactions for nil payers.

---

## Problem #13, HIGH, Performance, Balance Calculation Is O(n²) and Uncached — Recalculates on Every Render

- **What is broken:** `HomeView` calls `person.calculateBalance()` for every person on every SwiftUI view render. Each `calculateBalance()` iterates through all of that person's transactions, creating O(people × transactions) complexity with no caching.
- **Location:** `Swiss Coin/Features/Home/HomeView.swift:40-64` (totalYouOwe, totalOwedToYou computed properties), `Swiss Coin/Utilities/BalanceCalculator.swift:13-54` (calculateBalance iterates all transactions per person)
- **Current behavior:** With 50 people and 200 transactions each, the home screen performs 10,000 transaction iterations on every view update. HomeView is the landing screen, so this runs on every app launch and every return to the home tab.
- **Expected behavior:** Balance calculations cached and invalidated only when transactions, settlements, or reminders change. Computed once, stored as a cached property or computed in a background context.
- **Why this blocks launch:** Users with moderate data (50+ contacts, 500+ transactions) will experience visible UI lag on the home screen. This is the first screen users see — poor performance here creates an immediate negative impression.
- **Fix required:** Implement a `BalanceCache` that stores computed balances per person and invalidates on CoreData `NSManagedObjectContextDidSave` notifications. Move computation to a background context. Use `@State` or `@Published` to trigger UI updates only when cache changes.

---

## Problem #14, HIGH, Security, Mock Data Generator Has No Compile-Time Production Guard

- **What is broken:** `MockDataGenerator` and `MockDataConfig` are available in production builds with a simple runtime boolean toggle. No `#if DEBUG` compiler directive prevents mock data from being seeded into a production database.
- **Location:** `Swiss Coin/Utilities/MockDataGenerator.swift:16-22`
- **Current behavior:** `MockDataConfig.isEnabled` is a `static var` that defaults to `false` but can be set to `true` from any code path at runtime, including in Release builds. Calling `MockDataGenerator.seed(context:)` injects fake people, transactions, and subscriptions into the production CoreData store.
- **Expected behavior:** `MockDataGenerator` entirely excluded from Release builds via `#if DEBUG` compilation guard. Impossible to invoke in production.
- **Why this blocks launch:** A stray code path or future developer mistake could inject test data ("John Doe owes you $50") into a real user's financial records. This corrupts production data and destroys user trust.
- **Fix required:** Wrap the entire `MockDataGenerator` struct and `MockDataConfig` struct in `#if DEBUG` / `#endif` blocks. Remove any non-debug references. Verify with a Release build that the symbols are absent.

---

## Problem #15, HIGH, Data Integrity, Settlement Entity Has No Group Relationship

- **What is broken:** The `Settlement` entity can only reference `fromPerson` and `toPerson` but has no relationship to `UserGroup`, making it impossible to distinguish personal settlements from group settlements.
- **Location:** `Swiss_Coin.xcdatamodel/contents:110-117`, `Swiss Coin/Utilities/GroupBalanceCalculator.swift:109-122`
- **Current behavior:** Group settlement calculations in `GroupBalanceCalculator` must infer group context from the people involved rather than querying settlements directly associated with a group. Settlements between two people who are in multiple groups cannot be attributed to the correct group.
- **Expected behavior:** `Settlement` entity has an optional `group` relationship to `UserGroup`, enabling direct queries like "all settlements in Group X"
- **Why this blocks launch:** Group balance displays may show incorrect settlement totals when members share multiple groups. Users settling a debt in Group A may see it incorrectly reflected in Group B.
- **Fix required:** Add `group` optional relationship from `Settlement` to `UserGroup` (inverse: `settlements`). Update `GroupSettlementView` and `GroupBalanceCalculator` to use this relationship. Add lightweight migration.

---

## Problem #16, HIGH, Performance, Photo Data Stored Directly in CoreData — Database Bloat

- **What is broken:** Profile photos and contact photos are stored as binary `photoData` attributes directly in the CoreData SQLite database rather than as external file references.
- **Location:** `Swiss Coin/Features/Profile/PersonalDetailsView.swift:531-535` (saves jpegData to CoreData), `Swiss_Coin.xcdatamodel/contents` (Person.photoData, UserGroup.photoData as Binary Data attributes)
- **Current behavior:** Each photo stored at 800x800 JPEG (0.8 quality) directly in the SQLite database. With 100 contacts having photos, the database grows by ~50-100MB. CoreData loads these blobs during fetch requests even when only names are needed.
- **Expected behavior:** Photos stored in the app's Documents directory as files. CoreData stores only the file path/name. Photos loaded lazily on demand. `allowsExternalBinaryDataStorage` enabled at minimum.
- **Why this blocks launch:** Database bloat causes slow launch times, slow fetch requests, and excessive memory usage. CoreData faulting doesn't help when the blob is in the same SQLite row. Users with many contacts will experience degraded performance.
- **Fix required:** Enable `allowsExternalBinaryDataStorage` on photoData attributes in the CoreData model (checkbox in Xcode model editor). For optimal solution, store photos as files in Documents directory and reference by filename in CoreData.

---

## Problem #17, HIGH, Architecture, No Balance Rounding — Accumulated Errors Display to Users

- **What is broken:** Neither `BalanceCalculator.calculateBalance()` nor `GroupBalanceCalculator.calculateMemberBalances()` round results to 2 decimal places, allowing accumulated floating-point errors to display as visible cents discrepancies.
- **Location:** `Swiss Coin/Utilities/BalanceCalculator.swift:13-54` (returns raw Double, no rounding), `Swiss Coin/Utilities/GroupBalanceCalculator.swift:17-42` (same issue), `GroupBalanceCalculator.swift:86,93` (hardcoded 0.01 threshold for zero-check)
- **Current behavior:** After 50+ transactions, a user's balance might show as "$127.340000000001" or "-$45.129999999999" internally. `CurrencyFormatter` may round for display, but comparison logic (`balance > 0`, `balance < -0.01`) operates on unrounded values, causing inconsistent "you owe" vs "they owe" determinations.
- **Expected behavior:** All balance calculations rounded to 2 decimal places (or currency-appropriate precision) before storage, comparison, or display. Zero threshold defined as a named constant matching currency precision.
- **Why this blocks launch:** Users see one balance on the home screen and a different balance on the person detail screen due to intermediate rounding differences. Financial inconsistency erodes trust.
- **Fix required:** Add `(result * 100).rounded() / 100` at the return point of `calculateBalance()` and `calculateMemberBalances()`. Define `static let zeroThreshold: Double = 0.005` as a named constant. Apply consistently across all balance comparison points. (Full fix is Problem #6's Decimal migration.)

---

## Problem #18, MEDIUM, Security, No Certificate Pinning for Future Network Calls

- **What is broken:** No `URLSessionDelegate` implementing certificate pinning exists in the codebase. When backend integration is added, all API calls will be vulnerable to man-in-the-middle attacks.
- **Location:** Entire codebase — no pinning implementation found in any file
- **Current behavior:** Currently moot since no network calls exist, but when Supabase integration is implemented, all traffic will trust any valid certificate including those from compromised CAs
- **Expected behavior:** Certificate pinning implemented for all API endpoints using either public key pinning or certificate pinning via `URLSessionDelegate.urlSession(_:didReceive:completionHandler:)`
- **Why this blocks launch:** Without pinning, an attacker on the same network can intercept all API traffic (auth tokens, financial data, personal information) using a rogue certificate. Required for financial app security.
- **Fix required:** Implement `URLSessionPinningDelegate` with Supabase's public key hash. Use `TrustKit` or native URLSession pinning. Add certificate rotation plan.

---

## Problem #19, MEDIUM, Performance, Missing CoreData Indexes on Frequently Queried Attributes

- **What is broken:** No database indexes are defined on any CoreData entity attributes, causing full table scans for all fetch requests.
- **Location:** `Swiss_Coin.xcdatamodel/contents` — zero `<fetchIndex>` elements defined for any entity
- **Current behavior:** Fetching transactions by date, people by name, or settlements by person all perform sequential scans. Performance degrades linearly with data growth.
- **Expected behavior:** Indexes on: `FinancialTransaction.date`, `Person.id`, `Person.name`, `UserGroup.id`, `Settlement.date`, `Subscription.nextBillingDate`, `Reminder.isRead`
- **Why this blocks launch:** Users with 500+ transactions will notice sluggish list loading, slow search results, and delayed badge count calculations. Not a blocker for small datasets but degrades quickly.
- **Fix required:** Add `<fetchIndex>` entries to the CoreData model for the attributes listed above. Test with Instruments to verify index usage.

---

## Problem #20, MEDIUM, UI/UX, Contact Cache Not Cleared on App Background — Privacy Concern

- **What is broken:** `ContactsManager` caches phone contacts (names, phone numbers, emails, thumbnail photos) in memory with a 60-second TTL but never clears the cache when the app enters the background.
- **Location:** `Swiss Coin/Services/ContactsManager.swift` — `cacheValidityDuration: TimeInterval = 60`
- **Current behavior:** Contacts data persists in memory during background state. If the app is memory-mapped or the device is compromised while backgrounded, cached contact data is accessible.
- **Expected behavior:** Cache cleared on `UIApplication.didEnterBackgroundNotification`. Cache TTL reduced to 30 seconds. Email addresses excluded from cache if not needed for core functionality.
- **Why this blocks launch:** Retaining contacts in memory longer than necessary is a privacy concern. Under GDPR and similar regulations, apps should minimize data retention. App Review may question contacts usage justification if data is held unnecessarily.
- **Fix required:** Subscribe to `UIApplication.didEnterBackgroundNotification` in `ContactsManager` and clear the cached contacts array and thumbnail images. Reduce TTL to 30 seconds.

---

## Problem #21, MEDIUM, Data Integrity, Validation Limits Defined but Not Enforced at Data Layer

- **What is broken:** `DesignSystem.ValidationLimits` defines maximum lengths and amounts (maxNameLength=100, maxTransactionAmount=1,000,000, etc.) but these are only enforced at the UI layer via text field modifiers, not at the CoreData save level.
- **Location:** `Swiss Coin/Utilities/DesignSystem.swift:447-474` (limits defined), CoreData model (no constraints)
- **Current behavior:** A programmatic CoreData save (from migration, sync, or mock data) can create a Person with a 10,000-character name or a $999,999,999 transaction. UI limits are bypassed.
- **Expected behavior:** Validation in `NSManagedObject.validateForInsert()` / `validateForUpdate()` overrides, or pre-save validation in a service layer
- **Why this blocks launch:** Data corruption from any non-UI code path (future sync, import, migration) will go undetected until it causes UI rendering issues or crashes.
- **Fix required:** Add `validateForInsert()` and `validateForUpdate()` overrides to `Person`, `FinancialTransaction`, and `Subscription` managed object subclasses that enforce `ValidationLimits` constraints. Throw descriptive `NSError` on violation.

---

## Problem #22, MEDIUM, UI/UX, CurrencyFormatter Locale Parsing Bug for European Formats

- **What is broken:** `CurrencyFormatter.parse()` strips commas and apostrophes but does not handle European locales where periods are thousand separators and commas are decimal separators.
- **Location:** `Swiss Coin/Utilities/CurrencyFormatter.swift:154-187`
- **Current behavior:** For Swiss locale (de_CH), "1'234.56" formats correctly but "1.234,56" (German de_DE format) would strip the comma producing "1.23456" then fail to parse as the intended "1234.56". For EUR users, the parse function may return incorrect values.
- **Expected behavior:** Parse function respects the active locale's number format, or uses `NumberFormatter` with the correct locale to parse the string
- **Why this blocks launch:** European users (EUR, CHF, SEK) entering amounts in their locale format get incorrect parsed values. A German user typing "1.000" (meaning one thousand) gets parsed as "1.0" (one dollar).
- **Fix required:** Use `NumberFormatter` with the currency's configured locale for parsing. Remove manual string stripping. Add locale-aware parsing tests for all 15 supported currencies.

---

## Problem #23, MEDIUM, Feature, Missing Major Currencies — 15 Supported vs Market Expectations

- **What is broken:** The app supports 15 currencies but is missing several high-demand currencies for an app named "Swiss Coin" targeting an international audience.
- **Location:** `Swiss Coin/Utilities/CurrencyFormatter.swift:25-41`
- **Current behavior:** Supported: USD, EUR, GBP, INR, CNY, JPY, CHF, CAD, AUD, KRW, SGD, AED, BRL, MXN, SEK. Missing: HKD, NZD, THB, ZAR, TWD, MYR, IDR, PHP, PLN, NOK, DKK, CZK, HUF, TRY
- **Expected behavior:** At minimum add HKD, NZD, NOK, DKK, PLN, TRY for European and Asia-Pacific coverage
- **Why this blocks launch:** Users in Hong Kong, New Zealand, Scandinavia (NOK, DKK), or Turkey cannot use the app with their local currency. Limits addressable market significantly.
- **Fix required:** Add at minimum: HKD, NZD, NOK, DKK, PLN, TRY with correct locale identifiers and symbol/placement configurations in the `CurrencyConfig` dictionary.

---

## Problem #24, MEDIUM, Performance, Image Processing Runs on Main Thread

- **What is broken:** Photo resizing (800x800 `UIGraphicsImageRenderer`) executes synchronously on the main thread when a user selects a profile photo.
- **Location:** `Swiss Coin/Features/Profile/PersonalDetailsView.swift:565-588`
- **Current behavior:** Large photos (4000x3000 from camera) are resized on the main thread, blocking UI for 100-500ms. The resize target of 800x800 is also larger than necessary for a profile thumbnail.
- **Expected behavior:** Image processing dispatched to a background queue. Resize target reduced to 400x400 for profile photos. UI shows a loading indicator during processing.
- **Why this blocks launch:** Users experience a visible freeze when selecting a photo. On older devices (iPhone SE, iPad mini), this can trigger a watchdog termination if combined with other main-thread work.
- **Fix required:** Wrap the `UIGraphicsImageRenderer` block in `DispatchQueue.global(qos: .userInitiated).async {}`. Dispatch result back to main thread. Reduce max dimension from 800 to 400. Add activity indicator during processing.

---

## Problem #25, MEDIUM, UI/UX, Amount Font Uses .rounded Design — Digits Jump During Editing

- **What is broken:** Financial amount displays use `.system(size:weight:design: .rounded)` font design, which is proportionally-spaced, causing digits to shift horizontally when values change.
- **Location:** `Swiss Coin/Utilities/DesignSystem.swift:350-363` (amount font definitions)
- **Current behavior:** When a user types an amount like "$1,234.56", each digit has a different width. The digit "1" is narrower than "0", causing the entire number to visually shift left/right as digits change. Particularly noticeable during live editing.
- **Expected behavior:** Amount fields use `.monospacedDigit()` modifier to ensure all digits have equal width, preventing visual jitter
- **Why this blocks launch:** While not a crash, digit-jumping in a finance app looks unprofessional and makes it harder for users to verify amounts. This is a polish issue that signals lack of attention to detail.
- **Fix required:** Add `.monospacedDigit()` modifier to all amount font definitions in `DesignSystem`. Example: `.system(size: 17, weight: .bold, design: .rounded).monospacedDigit()`

---

## Problem #26, MEDIUM, Accessibility, Disabled State Opacity Too Low — Fails WCAG Contrast

- **What is broken:** The disabled color is `Color(.secondaryLabel).opacity(0.4)`, resulting in approximately 24% effective opacity which fails WCAG AA contrast requirements.
- **Location:** `Swiss Coin/Utilities/DesignSystem.swift:272`
- **Current behavior:** Disabled buttons and text have very low contrast against both light and dark backgrounds. Users with low vision cannot distinguish disabled from hidden elements.
- **Expected behavior:** Disabled state meets minimum WCAG AA 4.5:1 contrast ratio for normal text, or 3:1 for large text. Typical disabled opacity is 0.38-0.6 of primary label.
- **Why this blocks launch:** Accessibility failures can trigger App Review feedback and negative reviews from users with visual impairments. Apple increasingly enforces accessibility standards.
- **Fix required:** Increase disabled opacity to `0.6` or use `Color(.tertiaryLabel)` which is Apple's system-provided disabled color with guaranteed accessibility compliance.

---

## Problem #27, MEDIUM, Architecture, Hardcoded Help URL in Profile View

- **What is broken:** The help center URL is hardcoded as a string literal in the view layer, making it impossible to update without an app release.
- **Location:** `Swiss Coin/Features/Profile/ProfileView.swift:343`
- **Current behavior:** `openURL("https://swisscoin.app/help")` — if this domain expires, changes, or the path changes, users get a broken link until the next app update ships
- **Expected behavior:** URLs centralized in a configuration file or fetched from a remote config endpoint. At minimum, defined as constants in a `URLs` enum.
- **Why this blocks launch:** If `swisscoin.app` is not yet registered or configured, users tapping "Help" see a browser error. A broken help link during App Review triggers questions about app completeness.
- **Fix required:** Create a `URLs` enum in configuration with all external URLs. Verify `swisscoin.app/help` resolves before submission. Consider adding a fallback URL.

---

## Problem #28, LOW, Security, Auto-Lock Timeout Allows 30-Minute Maximum

- **What is broken:** The security auto-lock timeout can be set to 30 minutes, which is excessively long for a financial application.
- **Location:** `Swiss Coin/Features/Profile/PrivacySecurityView.swift:225-230`
- **Current behavior:** Picker options: 1 min, 5 min, 15 min, 30 min. A 30-minute timeout means the app stays unlocked for half an hour after last interaction.
- **Expected behavior:** Maximum timeout of 10-15 minutes for a finance app. Default should be 1-5 minutes.
- **Why this blocks launch:** Not a blocker per se, but a security best practice concern for financial applications. Banking apps typically enforce 5-minute maximums.
- **Fix required:** Remove the 30-minute option. Set maximum to 15 minutes. Change default from user-selected to 5 minutes.

---

## Problem #29, LOW, Architecture, "Me" vs "You" Display Name Inconsistency

- **What is broken:** The current user is referred to as both "You" and "Me" in different parts of the code, creating inconsistent UI labels.
- **Location:** `Swiss Coin/Utilities/CurrentUser.swift:35` (`displayName = "You"`), `CurrentUser.swift:84` (`user.name = "Me"`)
- **Current behavior:** The current user's display name constant is "You" but the CoreData Person entity for the current user has its name set to "Me". Different screens may show different labels for the same user.
- **Expected behavior:** Consistent terminology throughout the app. Either "You" everywhere or "Me" everywhere, with context-appropriate usage.
- **Why this blocks launch:** Minor polish issue. Does not prevent launch but creates an inconsistent feel.
- **Fix required:** Unify to "You" for third-person context ("You paid $50") and "Me" for self-reference context ("Split with Me"). Update `CurrentUser.displayName` and Person name to be consistent, or use context-dependent display logic.

---

## Problem #30, LOW, App Store Compliance, No Entitlements File Defined

- **What is broken:** No `.entitlements` file exists in the project. Features like Push Notifications, iCloud, and App Groups require entitlements.
- **Location:** `Swiss Coin.xcodeproj/project.pbxproj` — no CODE_SIGN_ENTITLEMENTS key present
- **Current behavior:** App builds without explicit entitlements. Push notifications or iCloud backup will fail silently at runtime without proper entitlements.
- **Expected behavior:** Entitlements file present with at minimum: `aps-environment` (if push notifications planned), `keychain-access-groups` for shared Keychain access
- **Why this blocks launch:** Not a blocker for current offline-only functionality. Becomes blocking if push notifications or iCloud features are added.
- **Fix required:** Create `Swiss Coin.entitlements` file. Add to build settings as `CODE_SIGN_ENTITLEMENTS`. Add required capability entitlements as features are implemented.

---

## Problem #31, LOW, Data Integrity, CoreData Migration Silently Destroys Data on Schema Conflict

- **What is broken:** When a CoreData lightweight migration fails, the `Persistence` controller deletes the corrupted store and falls back to an in-memory store, silently destroying all user data.
- **Location:** `Swiss Coin/Services/Persistence.swift` — error handling for migration codes 134140, 134130, 134110
- **Current behavior:** On migration error: delete store file, create new in-memory store, log error. User's data is gone. No backup, no recovery prompt, no user notification.
- **Expected behavior:** Before attempting migration, create a backup of the store file. On failure, present an alert to the user. Never silently destroy financial data.
- **Why this blocks launch:** If a future schema change triggers a migration failure, users lose all their financial records with no warning. Low probability but catastrophic impact.
- **Fix required:** Add pre-migration backup: copy SQLite file to `Documents/Backups/` with timestamp. On migration failure, preserve backup and present user-facing error alert with recovery options. Log diagnostic data for support.

---

## AUDIT SUMMARY

| Severity | Count | Categories |
|----------|-------|------------|
| CRITICAL | 9 | App Store Compliance (2), Security (3), Data Integrity (2), Backend (1), Testing (1) |
| HIGH | 8 | Data Integrity (4), Performance (1), Security (1), Architecture (1) |
| MEDIUM | 10 | Performance (2), Security (1), Data Integrity (1), UI/UX (3), Feature (1), Accessibility (1), Architecture (1) |
| LOW | 4 | Security (1), Architecture (1), App Store (1), Data Integrity (1) |
| **TOTAL** | **31** | |

### Top 3 Immediate Actions for App Store Submission
1. Create Privacy Manifest (Problem #1)
2. Add app icon PNG assets (Problem #2)
3. Decide backend architecture: offline-first or Supabase-integrated (Problem #4)

### Top 3 Data Integrity Fixes
1. Migrate from Double to Decimal for all currency amounts (Problem #6)
2. Fix CurrentUser thread safety (Problem #9)
3. Change cascade delete to nullify on Person relationships (Problem #11)
