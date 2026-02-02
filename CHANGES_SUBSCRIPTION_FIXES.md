# Subscription Bug Fixes & Missing Features

## Changes Summary

### 1. Fix `markAsPaid()` to create payment record
**File:** `Swiss Coin/Features/Subscriptions/Components/SubscriptionListRowView.swift`

Previously, `markAsPaid()` only advanced the `nextBillingDate` without creating any payment record. Now it:
- Captures the current `nextBillingDate` as `billingPeriodStart` before advancing
- Calculates the new next billing date as `billingPeriodEnd`
- Creates a `SubscriptionPayment` entity with `id`, `amount`, `date`, `billingPeriodStart`, `billingPeriodEnd`, `payer` (current user), and `subscription`
- Saves with proper try/catch and rollback on failure

### 2. Populate billingPeriodStart/End on RecordSubscriptionPaymentView
**File:** `Swiss Coin/Features/Subscriptions/RecordSubscriptionPaymentView.swift`

The `savePayment()` function now:
- Captures the subscription's current `nextBillingDate` as `billingPeriodStart` before advancing
- Calculates the new next billing date as `billingPeriodEnd`
- Sets both `payment.billingPeriodStart` and `payment.billingPeriodEnd` on the payment entity

### 3. Fix paused subscriptions in balance calculations
**File:** `Swiss Coin/Features/Subscriptions/Models/Subscription+Extensions.swift`

Added `isActive` guard checks to all balance calculation methods so paused subscriptions return zero/empty:
- `calculateUserBalance()` — returns `0` when `!isActive`
- `calculateMemberShare(for:)` — returns `0` when `!isActive`
- `calculateBalanceWith(member:)` — returns `0` when `!isActive`
- `getMemberBalances()` — returns `[]` when `!isActive`

This cascades to `getMembersWhoOweYou()` and `getMembersYouOwe()` which depend on `getMemberBalances()`.

### 4. Toggle SubscriptionReminder.isRead
**File:** `Swiss Coin/Features/Subscriptions/SharedSubscriptionConversationView.swift`

- Added `.onAppear` modifier to reminder items in the conversation view
- When a reminder appears on screen, `markReminderAsRead()` is called
- The method checks if `isRead` is already `true` to avoid redundant saves
- Sets `reminder.isRead = true` and saves with proper try/catch and rollback

### 5. Add settlement amount validation
**File:** `Swiss Coin/Features/Subscriptions/SubscriptionSettlementView.swift`

- Added `outstandingBalance` computed property that returns the absolute balance with the selected member
- Added `isOverSettlement` computed property that checks if entered amount exceeds outstanding balance
- Shows a warning banner with `exclamationmark.triangle.fill` icon and descriptive text (using `CurrencyFormatter`) when over-settling
- In `saveSettlement()`, the entered amount is capped at the outstanding balance using `min(enteredAmount, maxAmount)`

### 6. Display payment notes in conversation
**File:** `Swiss Coin/Features/Subscriptions/Components/SubscriptionPaymentCardView.swift`

- Restructured the body into a `VStack` to accommodate the optional note row
- When `payment.note` exists and is non-empty, displays it below the payment details
- Uses a `text.quote` icon with `AppTypography.footnote()` styling, italic, limited to 2 lines
- Follows the app's existing design system (AppColors, Spacing, etc.)

### 7. Fix conversation view direct haptic usage
**File:** `Swiss Coin/Features/Subscriptions/SharedSubscriptionConversationView.swift`

- Removed the `private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)` instance property
- Replaced `hapticGenerator.prepare()` with `HapticManager.prepare()`
- Replaced `hapticGenerator.impactOccurred()` with `HapticManager.lightTap()`
- All haptic feedback now uses the centralized `HapticManager` for consistency

---

## Design Principles Followed
- **CoreData naming:** Used `payer` (not `paidBy`), correct relationship names
- **Error handling:** All CoreData saves wrapped in try/catch with `viewContext.rollback()` on failure
- **Currency display:** Used `CurrencyFormatter.format()` for all amounts (no hardcoded "$")
- **Haptic feedback:** Used `HapticManager` exclusively (no direct `UIImpactFeedbackGenerator`)
- **Existing patterns preserved:** All original functionality maintained
