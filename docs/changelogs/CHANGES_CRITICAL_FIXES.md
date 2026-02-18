# Critical Bug Fixes — Transaction & QuickAction System

**Date:** 2026-02-02  
**Scope:** 7 critical fixes across 8 files

---

## 1. Unified SplitMethod Enum (Data Consistency)

**Problem:** Two separate enums — `SplitMethod` in `TransactionViewModel.swift` (raw values: `"Equal"`, `"Percentage"`, `"Exact Amount"`, `"Adjustment"`, `"Shares"`) and `QuickActionSplitMethod` in `QuickActionModels.swift` (raw values: `"equal"`, `"amounts"`, `"percentages"`, `"shares"`, `"adjustment"`). Transactions saved from different flows wrote incompatible `splitMethod` strings to CoreData.

**Fix:** Single canonical `SplitMethod` enum in `QuickActionModels.swift` with consistent lowercase raw values:
- `.equal` → `"equal"`
- `.amount` → `"amount"` (was `.exact`/`"Exact Amount"` and `.amounts`/`"amounts"`)
- `.percentage` → `"percentage"` (was `"Percentage"` and `"percentages"`)
- `.shares` → `"shares"`
- `.adjustment` → `"adjustment"`

Includes both `displayName`, `icon` (for QuickAction UI), and `systemImage` (for Transaction picker UI).

**Files changed:**
- `Swiss Coin/Features/QuickAction/QuickActionModels.swift` — renamed enum, fixed raw values, added `systemImage`
- `Swiss Coin/Features/Transactions/TransactionViewModel.swift` — removed duplicate enum, updated `.exact` → `.amount`
- `Swiss Coin/Features/Transactions/SplitInputView.swift` — updated `.exact` → `.amount`
- `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift` — type changed to `SplitMethod`, `.amounts` → `.amount`, `.percentages` → `.percentage`
- `Swiss Coin/Features/QuickAction/Step3SplitMethodView.swift` — updated all type/case references
- `Swiss Coin/Features/QuickAction/QuickActionComponents.swift` — updated `SplitMethodChip` type

---

## 2. QuickActionViewModel: Group Member-Adding Restored

**Problem:** `selectGroup()` had the member-adding logic commented out, so selecting a group added no participants.

**Fix:** Uncommented the code that iterates `group.members as? Set<Person>` and inserts each member's `id` into `participantIds`.

**File:** `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift`

---

## 3. QuickActionViewModel: Stable currentUserUUID

**Problem:** `currentUserUUID` used `CurrentUser.currentUserId ?? UUID()`, generating a **random UUID on every access** if `CurrentUser` was reset or uninitialized. This caused participant IDs to be inconsistent.

**Fix:** Three-tier fallback that never generates an ephemeral UUID:
1. `CurrentUser.currentUserId` (primary)
2. Read from `UserDefaults("stable_current_user_uuid")` (persistent fallback)
3. Create once, persist to UserDefaults, and return (last resort — happens once)

**File:** `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift`

---

## 4. QuickActionSheet: Error Alert Surfaced

**Problem:** `QuickActionViewModel` had `@Published var showingError` and `errorMessage` but no UI ever displayed them — save failures were silent.

**Fix:** Added `.alert("Error", isPresented: $viewModel.showingError)` modifier to `QuickActionSheet` body, showing the error message with an OK button.

**File:** `Swiss Coin/Features/QuickAction/QuickActionSheet.swift`

---

## 5. Non-Split Transaction: No Self-Owed Split

**Problem:** For personal (non-split) transactions, the code created a `TransactionSplit` where the payer owes themselves the full amount. This skewed balance calculations across the app.

**Fix:** Removed the `else` branch that created a self-referencing split. Non-split transactions now have zero `TransactionSplit` records, correctly representing a personal expense with no debts.

**File:** `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift`

---

## 6. PIN Security: PBKDF2 with Salt

**Problem:** PIN was hashed with plain SHA256 (`SHA256.hash(data: Data(pin.utf8))`), no salt. A 6-digit PIN has only 1M combinations — trivially brute-forceable.

**Fix:**
- **Creation:** Generates a random 16-byte salt via `SecRandomCopyBytes`, stores it in Keychain under `"user_pin_salt"`, then derives a 256-bit key using `CCKeyDerivationPBKDF` (PBKDF2-HMAC-SHA256, 100,000 iterations).
- **Verification:** Reads salt from Keychain, re-derives the hash with the same parameters, compares to stored hash. Gracefully handles missing salt (corrupted state).
- **Deletion:** Cleans up both `"user_pin_hash"` and `"user_pin_salt"` from Keychain.
- Added `fileprivate` helper functions `pbkdf2Hash()` and `hexToBytes()` at file scope so both `PrivacySecurityViewModel` and `PINVerifyView` share the same implementation.

**File:** `Swiss Coin/Features/Profile/PrivacySecurityView.swift`  
**Note:** Existing PINs created with old SHA256 will not verify — users will need to reset their PIN. This is expected for a security upgrade.

---

## 7. HapticManager: Respects User Preference

**Problem:** `HapticManager` fired haptics unconditionally, ignoring `@AppStorage("haptic_feedback")` from `AppearanceSettingsView`.

**Fix:** Added a private `isEnabled` computed property that reads `UserDefaults.standard.object(forKey: "haptic_feedback")`. Returns `true` when the key has never been set (default), or the stored boolean value otherwise. Every public method now starts with `guard isEnabled else { return }`.

**File:** `Swiss Coin/Utilities/HapticManager.swift`

---

## CoreData Property Rules Followed

- Used `payer` (not `paidBy`) for transaction payer relationship
- Used `owedBy` (not `person`) for split person relationship
- Did not add `id` to `TransactionSplit`
- No new files created
