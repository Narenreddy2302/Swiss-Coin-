# Swiss Coin — Deep Edge Case & Error Handling Audit

**Date:** 2026-02-02  
**Scope:** All Swift files in `Swiss Coin/` (Features, Services, Utilities, Models, Extensions, Components, Views, App)  
**Auditor:** Automated deep scan  

---

## Summary

| Severity | Count |
|----------|-------|
| 🔴 CRITICAL (potential crash) | 8 |
| 🟠 HIGH (data loss / corruption) | 14 |
| 🟡 MEDIUM (logic bug / UX issue) | 22 |
| 🔵 LOW (performance / code quality) | 18 |

---

## 🔴 CRITICAL — Potential Crashes

### C-1: Force unwrap in `Person+Extensions.swift` (line 68)
**File:** `Swiss Coin/Extensions/Person+Extensions.swift`  
**Line:** 68  
**Code:**
```swift
return name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name! : "Unnamed Person"
```
**Risk:** If `name` is non-nil but becomes nil between the ternary check and the force unwrap (race condition on CoreData managed object), this crashes. Even without a race, the force unwrap is unnecessary.  
**Fix:**
```swift
guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    return "Unnamed Person"
}
return name
```

---

### C-2: Force unwrap of `kCFBooleanTrue` / `kCFBooleanFalse` in `KeychainHelper.swift` (lines 45, 110)
**File:** `Swiss Coin/Utilities/KeychainHelper.swift`  
**Lines:** 45, 110  
**Code:**
```swift
kSecReturnData as String: kCFBooleanTrue!,
kSecReturnData as String: kCFBooleanFalse!
```
**Risk:** Technically safe since `kCFBooleanTrue`/`kCFBooleanFalse` are CF constants that should never be nil, but force unwrapping CF bridged values is fragile. If Apple ever changes the bridging, this crashes.  
**Severity:** Low-critical (extremely unlikely but avoidable)  
**Fix:** Use `true as CFBoolean` or just `true`:
```swift
kSecReturnData as String: true,
```

---

### C-3: Division by zero in `QuickActionViewModel.calculateSplits()` (line 385-438)
**File:** `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift`  
**Lines:** 385, 386, 416, 433  
**Code:**
```swift
let equalShare = total / count    // count is Double(participantIds.count), guarded > 0
let adjustedBase = (total - totalAdjustments) / count  // line 433 — NOT guarded if totalAdjustments > total
```
**Risk:** While `count > 0` is guarded at line 381, the `.adjustment` case (line 433) computes `(total - totalAdjustments) / count`. If totalAdjustments exceeds total, `adjustedBase` goes negative. Not a crash but produces incorrect negative splits. The `count` guard handles division-by-zero, but the logic gap produces nonsensical results.  
**Fix:** Clamp `adjustedBase` to 0 minimum, or validate totalAdjustments ≤ total before calculating.

---

### C-4: Division by zero in `TransactionDetailView` (line 223)
**File:** `Swiss Coin/Features/Transactions/TransactionDetailView.swift`  
**Line:** 223  
**Code:**
```swift
let percentage = (split.amount / transaction.amount) * 100
```
**Risk:** If `transaction.amount` is 0 (e.g., manually set or corrupted data), this produces `inf` or `nan`. Although guarded by `if transaction.amount > 0`, the guard only prevents display, not the calculation path in `splitRow`.  
**Actual guard (line 222):**
```swift
if transaction.amount > 0 {
    let percentage = (split.amount / transaction.amount) * 100
```
**Status:** ✅ Actually guarded. Low risk.

---

### C-5: Division by zero in `TransactionViewModel.calculateSplit()` (line 203)
**File:** `Swiss Coin/Features/Transactions/TransactionViewModel.swift`  
**Line:** 203  
**Code:**
```swift
let myShareRatio = myShares / totalShares  // shares case
```
**Risk:** `totalShares` is guarded at line 198 (`guard totalShares > 0`), so this is safe. ✅

---

### C-6: Division by zero in `Subscription+Extensions.swift` (lines 139, 157, 189, 206)
**File:** `Swiss Coin/Features/Subscriptions/Models/Subscription+Extensions.swift`  
**Lines:** 139, 157, 189, 206  
**Code:**
```swift
return amount / Double(subscriberCount)  // line 139
let amountPerMember = payment.amount / Double(subscriberCount)  // line 157
```
**Risk:** `subscriberCount` is computed as `isShared ? count + 1 : 1`, so minimum is 1. Safe for non-shared. However, if somehow `isShared == true` and `subscribers` set returns `nil` (CoreData fault), `count + 1 = 1`. The guard at line 153 (`guard subscriberCount > 0`) provides protection.  
**Status:** ✅ Guarded, but worth noting the defensive nature depends on CoreData relationship integrity.

---

### C-7: Integer division truncation in `SplitInputView` (line 91)
**File:** `Swiss Coin/Features/Transactions/SplitInputView.swift`  
**Line:** 91  
**Code:**
```swift
let defaultPercent = viewModel.selectedParticipants.isEmpty ? 100 : (100 / viewModel.selectedParticipants.count)
```
**Risk:** This is **integer division** (Int / Int). For 3 participants: `100 / 3 = 33` (not 33.33). Total = 99%, not 100%. Users will see their split doesn't add to 100%.  
**Fix:**
```swift
let defaultPercent = viewModel.selectedParticipants.isEmpty ? 100.0 : (100.0 / Double(viewModel.selectedParticipants.count))
viewModel.rawInputs[personId] = String(format: "%.1f", defaultPercent)
```

---

### C-8: `Color.toHex()` can crash on grayscale/non-RGB colors (line 45-53)
**File:** `Swiss Coin/Extensions/Color+Hex.swift`  
**Lines:** 45-53  
**Code:**
```swift
guard let components = UIColor(self).cgColor.components else {
    return AppColors.defaultAvatarColorHex
}
let r = Float(components[0])
let g = Float(components[1])
let b = Float(components[2])
```
**Risk:** For grayscale colors (e.g., `Color.gray`), `cgColor.components` returns only 2 elements `[white, alpha]`. Accessing `components[1]` and `components[2]` would give `alpha` and crash with index-out-of-bounds respectively. Same for `isLight`.  
**Fix:**
```swift
let uiColor = UIColor(self)
var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
return String(format: "#%02lX%02lX%02lX", lroundf(Float(r) * 255), lroundf(Float(g) * 255), lroundf(Float(b) * 255))
```

---

## 🟠 HIGH — Data Loss / Corruption Risks

### H-1: Deleting a Person cascades and destroys ALL their transactions
**File:** CoreData Model (`Swiss_Coin.xcdatamodel`)  
**Entity:** `Person` → `toTransactions` relationship  
**Delete Rule:** `Cascade`  
**Risk:** When a user deletes a person from `PeopleView.deletePerson()`, the cascade delete rule on `toTransactions` destroys ALL `FinancialTransaction` objects where that person was the payer. This means:
- If Person A paid for a group dinner with 5 people, deleting Person A deletes the entire transaction
- All associated `TransactionSplit` records also get cascade-deleted through `FinancialTransaction.splits`
- Other people's balance calculations silently change
- **No confirmation about data loss scope** — the alert just says "remove all associated data"

**Fix:** Change `Person.toTransactions` delete rule to `Nullify` instead of `Cascade`. Handle orphaned transactions gracefully (show "Deleted User" as payer). Add clearer warning about what will be deleted.

---

### H-2: Deleting a Person also cascade-deletes `owedSplits`
**File:** CoreData Model  
**Entity:** `Person` → `owedSplits` relationship  
**Delete Rule:** `Cascade`  
**Risk:** If someone deletes a contact who owes them money:
- All `TransactionSplit` records where that person owed money are deleted
- The parent `FinancialTransaction` still exists but now has incomplete split data
- Balance calculations for remaining participants become incorrect
- Settlement amounts become wrong

**Fix:** Change to `Nullify`. Show "Deleted Person" in splits UI.

---

### H-3: `try? context.save()` silently drops save failures in `SubscriptionDetailView` (lines 160, 179)
**File:** `Swiss Coin/Features/Subscriptions/SubscriptionDetailView.swift`  
**Lines:** 160, 179  
**Code:**
```swift
try? viewContext.save()  // Toggle notification
try? viewContext.save()  // Stepper change
```
**Risk:** If the save fails, the in-memory changes persist but are not persisted to disk. On app restart, the user's notification settings revert silently. No rollback is performed.  
**Fix:** Add proper do/catch with rollback and error alert, or at minimum `viewContext.rollback()` on failure.

---

### H-4: `try? context.save()` in `CurrentUser.updateProfile()` (line 116)
**File:** `Swiss Coin/Utilities/CurrentUser.swift`  
**Line:** 116  
**Code:**
```swift
try? context.save()
```
**Risk:** Profile updates (name, color, phone) can silently fail. The user believes their changes were saved.  
**Fix:** Return a `Bool` or throw, and handle in the caller.

---

### H-5: PersonalDetailsView saves twice — CoreData then calls `updateProfile()` which saves again
**File:** `Swiss Coin/Features/Profile/PersonalDetailsView.swift`  
**Lines:** 498-514  
**Code:**
```swift
try context.save()  // First save

CurrentUser.updateProfile(  // Second save inside this method
    name: displayName,
    colorHex: profileColor,
    ...
)
```
**Risk:** Double-saving the same context can trigger unnecessary merge notifications and is wasteful. If the first save succeeds but the second fails silently (it uses `try?`), data is partially saved. Additionally, `updateProfile` fetches and mutates the same object that was just saved, creating a redundant write.  
**Fix:** Remove the `updateProfile` call since the entity is already updated and saved.

---

### H-6: No validation for negative amounts in settlement creation
**File:** `Swiss Coin/Features/People/SettlementView.swift`, `GroupSettlementView.swift`  
**Risk:** `CurrencyFormatter.parse()` can return negative values if user inputs "-50". The validation `amount > 0.001` catches this, but `CurrencyFormatter.parse()` itself doesn't prevent negative parsing. A user typing "-5" in the custom amount field would be rejected, which is correct.  
**Status:** ✅ Guarded by validation, but UI doesn't prevent negative input. Add `.keyboardType(.decimalPad)` to prevent minus sign input.

---

### H-7: Race condition on `CurrentUser._currentUserId` static var
**File:** `Swiss Coin/Utilities/CurrentUser.swift`  
**Risk:** `_currentUserId` is a `static var` with no synchronization. If `reset()` is called from one thread while `isCurrentUser()` reads from another, the value could be in an inconsistent state.  
**Impact:** Low in practice (all UI runs on main thread), but `updateProfile` could theoretically be called from background.  
**Fix:** Use `@MainActor` isolation or a lock.

---

### H-8: `QuickActionSheetPresenter` calls `dismiss()` after `saveTransaction()` regardless of success
**File:** `Swiss Coin/Features/QuickAction/QuickActionComponents.swift`  
**Line:** ~91  
**Code:**
```swift
Button("Done") {
    viewModel.saveTransaction()
    dismiss()
}
```
**Risk:** `saveTransaction()` is synchronous but may fail (showing an error alert). Calling `dismiss()` immediately after closes the sheet regardless of whether the save succeeded, hiding the error alert. The user's transaction is lost.  
**Fix:** Only dismiss on success. Either use a completion handler or check `viewModel.showingError`.

---

### H-9: HomeView `allPeople` FetchRequest has no limit
**File:** `Swiss Coin/Features/Home/HomeView.swift`  
**Lines:** 16-19  
**Code:**
```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
    animation: .default)
private var allPeople: FetchedResults<Person>
```
**Risk:** Fetches ALL Person records to calculate balances. For each person, `calculateBalance()` iterates all their transactions, settlements, etc. With 100+ contacts each having many transactions, this triggers an O(n*m) computation on every view render.  
**Fix:** Add `fetchLimit` or cache balance calculations. Consider a background calculation with `@Published` results.

---

### H-10: Balance recalculation happens in View body (multiple views)
**Files:**
- `Swiss Coin/Features/People/PeopleView.swift` — `PersonListRowView.balance` (computed property calling `person.calculateBalance()`)
- `Swiss Coin/Features/Home/HomeView.swift` — `totalYouOwe` / `totalOwedToYou` iterates all people
- `Swiss Coin/Features/People/GroupListRowView` — `group.calculateBalance()`

**Risk:** Balance calculation traverses CoreData relationship graphs. In view body, this runs on every render. With SwiftUI's diffing, any @Published change triggers re-render of all visible rows, each recalculating O(transactions * splits).  
**Fix:** Cache calculated balances; recompute only when data changes.

---

### H-11: `PersonListView` FetchRequest predicate uses `CurrentUser.currentUserId ?? UUID()`
**File:** `Swiss Coin/Features/People/PeopleView.swift`  
**Lines:** 88-93  
**Code:**
```swift
predicate: NSPredicate(
    format: "id != %@ AND ...",
    (CurrentUser.currentUserId ?? UUID()) as CVarArg
)
```
**Risk:** If `CurrentUser.currentUserId` is nil (after reset/logout), a random UUID is used. This means the current user's Person entity could appear in the people list, or the predicate may not correctly filter.  
**Fix:** Handle the nil case explicitly; don't create random UUIDs for predicates.

---

### H-12: TransactionHistoryView `@FetchRequest` has no `fetchLimit`
**File:** `Swiss Coin/Features/Transactions/TransactionHistoryView.swift`  
**Lines:** 5-9  
**Code:**
```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \FinancialTransaction.date, ascending: false)],
    animation: .default)
private var transactions: FetchedResults<FinancialTransaction>
```
**Risk:** Fetches ALL transactions. For power users with thousands of records, this loads everything into memory.  
**Fix:** Add pagination or `fetchBatchSize` at minimum.

---

### H-13: `QuickActionViewModel` not marked `@MainActor` but has `@Published` properties
**File:** `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift`  
**Risk:** `QuickActionViewModel` is `ObservableObject` with 25+ `@Published` properties but is not `@MainActor`. In theory, if `fetchData()` or `saveTransaction()` were called from a background task, `@Published` updates would happen off-main-thread, causing SwiftUI rendering issues.  
**Current mitigations:** All callers are in SwiftUI views (main thread). But the class itself doesn't enforce this.  
**Fix:** Add `@MainActor` to the class declaration.

---

### H-14: `TransactionViewModel` not marked `@MainActor`
**File:** `Swiss Coin/Features/Transactions/TransactionViewModel.swift`  
**Risk:** Same as H-13. `ObservableObject` with `@Published` but no `@MainActor`.  
**Fix:** Add `@MainActor`.

---

## 🟡 MEDIUM — Logic Bugs / UX Issues

### M-1: DateFormatter created per render in 12+ locations
**Files:**
- `Components/TransactionCardView.swift:110`
- `Components/DateHeaderView.swift:19, 23`
- `Components/GroupTransactionCardView.swift:101`
- `TransactionDetailView.swift:42`
- `TransactionRowView.swift:145`
- `SubscriptionConversationItem.swift:53, 57`
- `GroupBalanceCalculator.swift:243, 247`
- `BalanceCalculator.swift:163, 167`

**Code pattern:**
```swift
let formatter = DateFormatter()
formatter.dateFormat = "MMM d, yyyy"
return formatter.string(from: date)
```
**Risk:** `DateFormatter` is expensive to create. Creating one in a computed property or `dateDisplayString` means it's allocated every time the view body is evaluated. With a list of 50 items, that's 50 allocations per render.  
**Fix:** Use the existing `DateFormatter.shortDate` static extension in `Utilities/Extensions.swift`, or create additional static formatters for other formats.

---

### M-2: `SplitInputView` uses `person.id ?? UUID()` creating ephemeral keys
**File:** `Swiss Coin/Features/Transactions/SplitInputView.swift`  
**Line:** 7  
**Code:**
```swift
private var personId: UUID {
    person.id ?? UUID()
}
```
**Risk:** If `person.id` is nil (should never happen per CoreData schema but...), every render creates a new UUID key, meaning `rawInputs` is never read correctly and grows unboundedly.  
**Fix:** Guard and handle the nil case explicitly.

---

### M-3: `TransactionViewModel` uses `person.id ?? UUID()` in 8+ places
**File:** `Swiss Coin/Features/Transactions/TransactionViewModel.swift`  
**Risk:** Same pattern as M-2. Each `?? UUID()` creates different UUIDs on each call, so raw inputs can never be looked up.  
**Fix:** Pre-validate that all participants have valid IDs.

---

### M-4: `ConversationItem.id` generates new UUID when entity id is nil
**File:** `Swiss Coin/Utilities/BalanceCalculator.swift`  
**Lines:** 132-139  
**Code:**
```swift
var id: UUID {
    switch self {
    case .transaction(let t): return t.id ?? UUID()
    ...
    }
}
```
**Risk:** If a CoreData entity has a nil id, every access to the `ConversationItem.id` property generates a new UUID. SwiftUI's `ForEach` uses `id` for diffing — changing IDs means SwiftUI destroys and recreates views every render cycle, causing flickering and infinite re-renders.  
**Fix:** Cache the generated UUID in the enum case, or guarantee IDs are never nil.

---

### M-5: Same issue in `GroupConversationItem.id` (GroupBalanceCalculator.swift:197-204)
**File:** `Swiss Coin/Utilities/GroupBalanceCalculator.swift`  
**Status:** Same bug as M-4.

---

### M-6: `PersonalDetailsView` saves email/fullName to UserDefaults, not CoreData
**File:** `Swiss Coin/Features/Profile/PersonalDetailsView.swift`  
**Lines:** 508-509  
**Code:**
```swift
UserDefaults.standard.set(email, forKey: "user_email")
UserDefaults.standard.set(fullName, forKey: "user_full_name")
```
**Risk:** `clearAllData()` in `PrivacySecurityView` does NOT clear UserDefaults for these keys. After a "Clear All Data & Sign Out", email and full name persist and leak to the next session.  
**Fix:** Add these keys to the `clearAllData()` cleanup.

---

### M-7: PIN lockout is trivially bypassable
**File:** `Swiss Coin/Features/Profile/PrivacySecurityView.swift`  
**Lines:** 652-658  
**Code:**
```swift
if attemptsRemaining <= 0 {
    errorMessage = "Too many attempts. Please try again later."
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        onCancel()
        dismiss()
    }
}
```
**Risk:** After 5 wrong PIN attempts, the user just waits 2 seconds and can try again (the sheet dismisses, they reopen it and `attemptsRemaining` resets to 5). There's no persistent lockout.  
**Fix:** Persist attempt count and lockout time in Keychain or UserDefaults.

---

### M-8: `AuthManager.shared` is `@StateObject` in both `ContentView` AND `PhoneLoginView`
**Files:**
- `Swiss Coin/App/ContentView.swift:13` — `@StateObject private var authManager = AuthManager.shared`
- `Swiss Coin/Features/Auth/PhoneLoginView.swift:12` — `@StateObject private var authManager = AuthManager.shared`

**Risk:** `@StateObject` is meant to create and own the object. Using it with a singleton (`AuthManager.shared`) means two views "own" the same singleton. While it works because the singleton pattern overrides ownership, it's semantically incorrect and could confuse SwiftUI's lifecycle.  
**Fix:** Use `@ObservedObject` or `@EnvironmentObject` for the child view (`PhoneLoginView`). `ContentView` can own it.

---

### M-9: Settlement allows overpayment in `SettlementView`
**File:** `Swiss Coin/Features/People/SettlementView.swift`  
**Line:** ~line 34  
**Code:**
```swift
private var isValidAmount: Bool {
    guard let amount = parsedAmount else { return false }
    return amount > 0.001 && amount <= abs(currentBalance) + 0.001
}
```
**Risk:** The `+ 0.001` tolerance allows very slight overpayments. While this handles floating point imprecision, `settleFullAmount()` uses `abs(currentBalance)` directly which could be $0.001 more than the actual debt due to accumulated floating point errors across many transactions. Over time, these compound.  
**Fix:** Use cent-based integer arithmetic for all balance calculations.

---

### M-10: Empty name accepted in `AddPersonView` allows blank contacts
**File:** `Swiss Coin/Features/People/AddPersonView.swift`  
**Line:** 14  
**Code:**
```swift
Button("Save Person") {
    addPerson()
}
.disabled(name.isEmpty)
```
**Risk:** A name consisting of only whitespace (e.g., "   ") passes the `.isEmpty` check but `addPerson()` trims it and guards:
```swift
let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
guard !trimmedName.isEmpty else { ... }
```
But the button is still enabled for whitespace-only input, leading to a confusing UX where pressing "Save" does nothing visible.  
**Fix:** Disable the button when trimmed name is empty.

---

### M-11: `deleteItems(offsets:)` in `TransactionHistoryView` can delete multiple items
**File:** `Swiss Coin/Features/Transactions/TransactionHistoryView.swift`  
**Lines:** 107-112  
**Code:**
```swift
private func deleteItems(offsets: IndexSet) {
    withAnimation {
        offsets.map { transactions[$0] }.forEach { transaction in
            deleteTransaction(transaction)
        }
    }
}
```
**Risk:** Each `deleteTransaction` call does a separate `save()`. If the second save fails, the first deletion is already committed. Should be atomic.  
**Fix:** Delete all items, then save once.

---

### M-12: `QuickActionViewModel.init()` uses default `viewContext` before `setup(context:)` is called
**File:** `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift`  
**Lines:** 107-110  
**Code:**
```swift
init() {
    self.viewContext = PersistenceController.shared.container.viewContext
    participantIds.insert(currentUserUUID)
}
```
**Risk:** The default init uses the shared viewContext. Later, `setup(context:)` replaces it. Any operations between init and setup use the shared context, which may differ from the environment context passed to the view.  
**Fix:** Require context in init or make setup mandatory before any operations.

---

### M-13: Group deletion doesn't clean up orphaned member references
**File:** `Swiss Coin/Features/People/PeopleView.swift` — `deleteGroup()`  
**Risk:** When a group is deleted:
- `UserGroup.transactions` has Cascade delete → transactions are destroyed ✅
- `UserGroup.members` has Nullify delete → Person's `toGroups` set is updated ✅
- `UserGroup.chatMessages` has Cascade delete → messages destroyed ✅
- BUT: Group transactions that had splits involving members now have their parent `FinancialTransaction` deleted (cascade from UserGroup.transactions), which cascade-deletes `TransactionSplit` records. **Person balance calculations silently change** because the splits are gone.

**Fix:** Consider Nullify on `UserGroup.transactions` and show "Deleted Group" label, or warn the user about balance impact.

---

### M-14: `ContactsManager` is not `@MainActor` but has `@Published` properties
**File:** `Swiss Coin/Services/ContactsManager.swift`  
**Risk:** `ContactsManager` has `@Published var contacts` and `@Published var authorizationStatus`. While `fetchContacts()` wraps updates in `await MainActor.run`, the class itself doesn't guarantee main-thread access.  
**Fix:** Add `@MainActor` to the class.

---

### M-15: `PersonalDetailsViewModel` is not `@MainActor` but has `@Published` properties
**File:** `Swiss Coin/Features/Profile/PersonalDetailsView.swift`  
**Line:** 322  
**Risk:** Same pattern as M-14. The image picker callback dispatches to main via `DispatchQueue.main.async`, but the class doesn't enforce it.  
**Fix:** Add `@MainActor`.

---

### M-16: No input length limits on text fields
**Files:** Throughout the app (AddPersonView, AddGroupView, AddSubscriptionView, message inputs, notes, etc.)  
**Risk:** A user could paste an extremely long string (e.g., 1MB of text) into any TextField. CoreData stores it, and displaying it would freeze the UI.  
**Fix:** Add `.onChange` modifiers that truncate input to reasonable limits (e.g., 200 chars for names, 1000 for notes).

---

### M-17: `TransactionEditView.saveChanges()` proportional recalculation rounding error
**File:** `Swiss Coin/Features/Transactions/TransactionEditView.swift`  
**Lines:** 240-243  
**Code:**
```swift
let ratio = newAmount / oldAmount
if let splits = transaction.splits as? Set<TransactionSplit> {
    for split in splits {
        split.amount = (split.amount * ratio * 100).rounded() / 100.0
    }
}
```
**Risk:** After rounding, the sum of splits may not equal `newAmount` due to accumulated rounding errors. For 3 splits, each could be off by ±$0.01, totaling ±$0.03 discrepancy.  
**Fix:** After proportional calculation, adjust the largest split to absorb the rounding difference.

---

### M-18: `PrivacySecurityView.enableBiometric()` uses `DispatchQueue.main.async` inside `@MainActor` class
**File:** `Swiss Coin/Features/Profile/PrivacySecurityView.swift`  
**Line:** 364  
**Code:**
```swift
context.evaluatePolicy(...) { success, authError in
    DispatchQueue.main.async {
        if success { ... }
    }
}
```
**Risk:** The `PrivacySecurityViewModel` is `@MainActor`, but the LAContext callback runs on an arbitrary thread. The `DispatchQueue.main.async` is correct here, but mixing `@MainActor` with manual dispatch can lead to subtle ordering issues.  
**Fix:** Consider using Swift concurrency instead: `Task { @MainActor in ... }`.

---

### M-19: `MockDataGenerator.clearAllData()` uses `NSBatchDeleteRequest` which bypasses context
**File:** `Swiss Coin/Utilities/MockDataGenerator.swift`  
**Line:** 84  
**Code:**
```swift
let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
_ = try? context.execute(deleteRequest)
```
**Risk:** `NSBatchDeleteRequest` operates at the SQL level, bypassing the `NSManagedObjectContext`. In-memory objects and any UI observing `@FetchRequest` won't be notified of the deletion until the context is refreshed. This could leave stale data in UI.  
**Fix:** Call `context.refreshAllObjects()` after batch delete, or use standard context-based deletion for small datasets.

---

### M-20: `Persistence.init()` continues without a working store on error
**File:** `Swiss Coin/Services/Persistence.swift`  
**Lines:** 29-62  
**Risk:** If the persistent store fails to load and the retry also fails, the app continues with a non-functional CoreData stack. All saves will silently fail, and the user's data is lost. The comment says "Continuing with in-memory store as fallback" but no in-memory store is actually created.  
**Fix:** Actually create an in-memory fallback store, or show a user-facing error.

---

### M-21: `SplitInputView.onAppear` default percentage uses integer division
**File:** `Swiss Coin/Features/Transactions/SplitInputView.swift`  
**Line:** 91  
**Code:**
```swift
let defaultPercent = viewModel.selectedParticipants.isEmpty ? 100 : (100 / viewModel.selectedParticipants.count)
```
**Risk:** Already covered in C-7 but the consequence is: with 3 participants, default is "33" (not "33.33"), totaling 99%. Validation will reject this, confusing users.

---

### M-22: `SubscriptionSettlementView` over-settlement warning but still allows save
**File:** `Swiss Coin/Features/Subscriptions/SubscriptionSettlementView.swift`  
**Lines:** 170-176  
**Risk:** The view shows a warning if amount exceeds balance, and the save function caps the amount — but the UI still shows the uncapped amount, which could confuse users who think they settled more than they did.  
**Fix:** Update the displayed amount to show the capped value, or prevent saving when over-settling.

---

## 🔵 LOW — Performance & Code Quality

### L-1: `QuickActionViewModel.fetchData()` has no `fetchLimit` on Person and Group requests
**File:** `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift`  
**Lines:** 152-159  
**Risk:** Fetches ALL people and ALL groups into memory arrays. For most users this is fine, but it's unbounded.  
**Fix:** Add pagination or fetchBatchSize.

---

### L-2: Redundant `Identifiable` conformance on Person
**File:** `Swiss Coin/Models/CoreData/Person.swift`  
**Line:** Last line — `extension Person: Identifiable {}`  
**Risk:** `NSManagedObject` already has an `objectID` but SwiftUI `Identifiable` requires `id`. Since Person has an `id: UUID?` property, this works. No bug, just noting the optional `id` could technically be nil for Identifiable.

---

### L-3: `CurrencyFormatter` static cache not thread-safe
**File:** `Swiss Coin/Utilities/CurrencyFormatter.swift`  
**Lines:** 47-48, 64-82  
**Risk:** `_cachedCode`, `_currencyFmt`, `_decimalFmt` are static vars mutated without synchronization. If called from multiple threads simultaneously (unlikely but possible), race condition could produce garbled formatters.  
**Fix:** Use a lock or make the class `@MainActor`.

---

### L-4: `HapticManager` generators are always initialized even when haptics are disabled
**File:** `Swiss Coin/Utilities/HapticManager.swift`  
**Lines:** 26-30  
**Risk:** Five static feedback generators are initialized at class load time. Minor memory overhead (~few KB) even when haptics are disabled.  
**Impact:** Negligible.

---

### L-5: `Color(hex:)` scanner can fail silently
**File:** `Swiss Coin/Extensions/Color+Hex.swift`  
**Risk:** If the hex string is completely invalid (e.g., "hello"), `Scanner.scanHexInt64` puts 0 in `int`, and the switch falls to `default` which uses the fallback color. This is correct behavior but the user gets no indication their color is wrong.

---

### L-6: `NotificationManager.rescheduleAllSubscriptionReminders()` has no fetchLimit
**File:** `Swiss Coin/Services/NotificationManager.swift`  
**Line:** 168  
**Risk:** Fetches all active subscriptions with notifications enabled. For most users this is small, but unbounded.

---

### L-7: `SearchView` (if it exists) — no file content checked
**File:** `Swiss Coin/Features/Search/SearchView.swift`  
**Risk:** Not audited in detail. Check for unbounded search results.

---

### L-8: Multiple `FetchRequest` without `fetchBatchSize`
**Files:** Most `@FetchRequest` declarations throughout the app.  
**Risk:** Without `fetchBatchSize`, CoreData loads all matching objects into memory at once. Setting `fetchBatchSize` to 20-50 enables faulting and reduces memory usage.

---

### L-9: `SharedSubscriptionListView` recalculates `totalMonthly` and `myMonthlyShare` on every render
**File:** `Swiss Coin/Features/Subscriptions/SharedSubscriptionListView.swift`  
**Lines:** 18-45  
**Risk:** Both computed properties iterate ALL active shared subscriptions on every render.  
**Fix:** Cache in a view model.

---

### L-10: `GroupConversationDateGroup.dateDisplayString` and `ConversationDateGroup.dateDisplayString` are identical
**Files:** `GroupBalanceCalculator.swift`, `BalanceCalculator.swift`  
**Risk:** Code duplication. Both create DateFormatters per call.  
**Fix:** Extract to a shared extension or protocol.

---

### L-11: `PersonConversationView` creates `UIImpactFeedbackGenerator` as instance property
**File:** `Swiss Coin/Features/People/PersonConversationView.swift`  
**Line:** 18  
**Code:**
```swift
private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
```
**Risk:** This generator is created per view instance. Since `HapticManager` already provides static generators, this is redundant. SwiftUI structs are recreated frequently, so this allocates a new generator on each view initialization.  
**Fix:** Use `HapticManager.lightTap()` instead.

---

### L-12: `QuickActionViewModel` has redundant `currentUserUUID` fallback
**File:** `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift`  
**Lines:** 64-75  
**Code:**
```swift
var currentUserUUID: UUID {
    if let id = CurrentUser.currentUserId { return id }
    let key = "stable_current_user_uuid"
    ...
}
```
**Risk:** Creates a secondary stable UUID stored under a different UserDefaults key than `CurrentUser`. If `CurrentUser` is reset but this key isn't, there's an identity mismatch.  
**Fix:** Use `CurrentUser.currentUserId` exclusively. Handle nil by ensuring CurrentUser always has an ID.

---

### L-13: `SubscriptionPayment` and related entities missing `TransactionSplit`-like ID field
**Status:** Not a bug, just noting these entities properly have `id` fields.

---

### L-14: `EditSubscriptionView.saveSubscription()` removes all members then re-adds them
**File:** `Swiss Coin/Features/Subscriptions/EditSubscriptionView.swift`  
**Lines:** 230-240  
**Risk:** This creates unnecessary CoreData churn (delete + insert vs. diff). For small member sets it's fine. No data loss risk since it's in a single save transaction.

---

### L-15: No accessibility identifiers on interactive elements
**Files:** Throughout the app.  
**Risk:** UI testing and VoiceOver navigation may be degraded without accessibility identifiers.

---

### L-16: `PhoneLoginView` creates `@StateObject` of singleton
**File:** `Swiss Coin/Features/Auth/PhoneLoginView.swift`  
**Risk:** Already noted in M-8 as a subset issue.

---

### L-17: `Persistence.loadPersistentStores` closure captures `container` but container is `let`
**File:** `Swiss Coin/Services/Persistence.swift`  
**Risk:** The capture `[container]` is correct but the variable is already a `let` constant. No bug, just unnecessary capture syntax.

---

### L-18: `ContactsManager.fetchContacts()` loads ALL phone contacts into memory
**File:** `Swiss Coin/Services/ContactsManager.swift`  
**Risk:** For users with thousands of contacts, this can use significant memory. The `enumerateContacts` API is efficient but the results array has no limit.  
**Fix:** Consider paginated loading or lazy loading for large contact lists.

---

## Additional Notes

### What's Done Well ✅
1. **CoreData saves consistently use try/catch with rollback** — Most save operations properly handle errors and rollback
2. **Input validation before CoreData writes** — Names are trimmed, amounts validated > 0
3. **Haptic feedback is centralized** — `HapticManager` provides consistent UX
4. **Design system is centralized** — `DesignSystem.swift` prevents magic numbers
5. **CurrencyFormatter has robust caching** — Rebuilds only when currency changes
6. **Settlement direction logic is correct** — Balance positive/negative properly determines from/to
7. **Duplicate phone number detection** — AddPersonView and EditPersonView check for existing phones
8. **Notification scheduling has proper guards** — Past dates, inactive subs, disabled notifications all handled

### Recommended Priority Order
1. **C-8** (Color.toHex crash on grayscale) — Real crash, easy fix
2. **C-1** (Force unwrap in safeName) — Real crash, one-line fix  
3. **H-1/H-2** (Cascade delete destroying transactions/splits) — Silent data loss
4. **H-8** (QuickActionSheetPresenter dismiss on failure) — Data loss
5. **C-7** (Integer division for default percent) — User-facing bug
6. **M-1** (DateFormatter per render) — Performance, easy win
7. **H-3/H-4** (Silent save failures) — Data integrity
8. **H-9/H-10** (Unbounded fetches + in-body calculations) — Performance at scale
