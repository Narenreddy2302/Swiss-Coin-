# Edge Case Fixes — Audit Remediation

**Date:** 2026-02-02  
**Scope:** Critical, High, and select Medium severity issues from code audit

---

## CRITICAL Fixes

### C-1: Force unwrap crash in `Person+Extensions.swift`
**File:** `Swiss Coin/Extensions/Person+Extensions.swift`  
**Issue:** `safeName` property used `name!` force unwrap, which crashes if `name` is nil.  
**Fix:** Replaced with `guard let name = name` safe unwrap pattern, returning `"Unnamed Person"` as fallback. Matches the existing `displayName` pattern already in the file.

### C-7: Integer division truncation in `SplitInputView.swift`
**File:** `Swiss Coin/Features/Transactions/SplitInputView.swift`  
**Issue:** `100 / viewModel.selectedParticipants.count` performed integer division, silently truncating results (e.g., 3 participants → 33% each = 99% total, losing 1%).  
**Fix:** Changed to `100.0 / Double(viewModel.selectedParticipants.count)` for floating-point division. Updated string format to `"%.1f"` to display the decimal percentage.

### C-8: `Color.toHex()` crash on grayscale colors
**File:** `Swiss Coin/Extensions/Color+Hex.swift`  
**Issue:** `cgColor.components` returns only 2 components for grayscale colors (gray + alpha), but code indexed `[0]`, `[1]`, `[2]` — out-of-bounds crash.  
**Fix:** Replaced `cgColor.components` array indexing with `UIColor.getRed(&r, green:&g, blue:&b, alpha:&a)` which always decomposes into RGB. Applied to both `toHex()` and `isLight` computed property.

---

## HIGH Fixes

### H-3/H-4: Silent `try?` Core Data saves
**Files:**
- `Swiss Coin/Features/Subscriptions/SubscriptionDetailView.swift` (notification toggle + stepper bindings)
- `Swiss Coin/Utilities/CurrentUser.swift` (`updateProfile` method)

**Issue:** `try? context.save()` silently swallowed save failures, leaving in-memory state inconsistent with the persistent store.  
**Fix:**
- **SubscriptionDetailView:** Both `try?` sites replaced with `do/catch` blocks that call `viewContext.rollback()`, trigger `HapticManager.error()`, and display error via the existing `showingError`/`errorMessage` alert.
- **CurrentUser:** Replaced with `do/catch` that calls `context.rollback()` and prints the error (no UI available in this utility class).

### H-8: QuickActionSheetPresenter dismisses on save failure
**File:** `Swiss Coin/Features/QuickAction/QuickActionComponents.swift`  
**Issue:** The "Done" button called `saveTransaction()` then unconditionally called `dismiss()`, closing the sheet even when the save failed — losing user input.  
**Fix:** Added `if !viewModel.showingError` guard before `dismiss()`. The sheet stays open on error so the user can retry or fix input.

### H-11: `UUID()` fallback in PeopleView NSPredicate
**File:** `Swiss Coin/Features/People/PeopleView.swift`  
**Issue:** `CurrentUser.currentUserId ?? UUID()` used a random UUID as fallback, which would never match any record — effectively hiding all people if the user ID was nil.  
**Fix:** Replaced with an immediately-invoked closure that checks `currentUserId`. If nil, uses a predicate without the `id !=` filter (shows all people with transactions) instead of filtering against a random UUID.

### H-13/H-14: Missing `@MainActor` on ViewModels
**Files:**
- `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift`
- `Swiss Coin/Features/Transactions/TransactionViewModel.swift`

**Issue:** `@Published` property writes from background threads can cause UI glitches or crashes. Both ViewModels drive SwiftUI views but lacked `@MainActor` annotation.  
**Fix:** Added `@MainActor` to both class declarations, ensuring all property access and mutations are confined to the main thread.

---

## MEDIUM Fixes

### M-1: DateFormatter allocation per render
**Files changed:**
- `Swiss Coin/Utilities/Extensions.swift` — Added `static let mediumDate` and `static let dayOfWeek` formatters
- `Swiss Coin/Features/People/Components/TransactionCardView.swift` — Uses `DateFormatter.mediumDate`
- `Swiss Coin/Features/People/Components/GroupTransactionCardView.swift` — Uses `DateFormatter.mediumDate`
- `Swiss Coin/Features/People/Components/DateHeaderView.swift` — Uses `DateFormatter.dayOfWeek` and `DateFormatter.mediumDate`
- `Swiss Coin/Features/Transactions/TransactionRowView.swift` — Uses `DateFormatter.mediumDate`

**Issue:** `DateFormatter()` was allocated on every SwiftUI render cycle in computed properties. `DateFormatter` is expensive to create.  
**Fix:** Added two new static formatters to the existing `DateFormatter` extension and replaced all 5 inline allocations in the 4 most performance-critical view files.

### Dark mode: Hardcoded `AppColors.background`
**File:** `Swiss Coin/Utilities/DesignSystem.swift`  
**Issue:** `AppColors.background` was hardcoded to `Color.black`, making the app dark-only. Light mode would show black backgrounds.  
**Fix:** Changed to `Color(.systemBackground)` which automatically adapts to the system appearance (white in light mode, black in dark mode).

---

## Summary

| Severity | ID | Status |
|----------|-------|--------|
| Critical | C-1 | ✅ Fixed |
| Critical | C-7 | ✅ Fixed |
| Critical | C-8 | ✅ Fixed |
| High | H-3/H-4 | ✅ Fixed |
| High | H-8 | ✅ Fixed |
| High | H-11 | ✅ Fixed |
| High | H-13 | ✅ Fixed |
| High | H-14 | ✅ Fixed |
| Medium | M-1 | ✅ Fixed (4 files) |
| Medium | Dark mode | ✅ Fixed |

**Total files modified:** 12  
**All changes are minimal and surgical — no functionality removed, no APIs changed.**
