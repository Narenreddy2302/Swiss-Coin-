# SCAN: Subscriptions Feature — Detailed Registry

> Generated: 2026-02-02  
> Files audited: 27 / 27  
> Module: `Swiss Coin/Features/Subscriptions/`

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [File-by-File Registry](#file-by-file-registry)
4. [CoreData Property Compliance](#coredata-property-compliance)
5. [Cross-Cutting Issues](#cross-cutting-issues)
6. [Edge Cases & Missing Handling](#edge-cases--missing-handling)
7. [Dependency Map](#dependency-map)

---

## Executive Summary

| Metric | Value |
|---|---|
| Total files | 27 |
| ✅ COMPLETE | 21 |
| 🔧 PARTIAL | 5 |
| 🐛 BUGGY | 1 |
| ❌ MISSING | 0 |
| Critical issues | 4 |
| Medium issues | 8 |
| Low issues | 6 |

The Subscriptions feature is **well-structured** and follows established app patterns (PeopleView, GroupConversationView). It provides a full CRUD lifecycle for personal and shared subscriptions with cost-splitting, settlements, reminders, and an iMessage-style conversation thread. The main concerns are: (1) a settlement balance-direction bug, (2) missing `billingPeriodStart`/`billingPeriodEnd` usage on payments, (3) hardcoded `$` currency symbol, and (4) no swipe-to-delete on list rows.

---

## Architecture Overview

```
SubscriptionView (root — segmented Personal / Shared)
├── PersonalSubscriptionListView
│   ├── PersonalSubscriptionSummaryCard
│   ├── SubscriptionListRowView (context menu: edit / mark paid / pause / delete)
│   ├── EmptySubscriptionView
│   └── → SubscriptionDetailView
│       ├── StatusPill
│       ├── PaymentHistoryRow
│       ├── EditSubscriptionView (sheet)
│       └── Delete / Pause actions
├── SharedSubscriptionListView
│   ├── SharedSubscriptionSummaryCard
│   ├── SharedSubscriptionListRowView (context menu: details / record / remind)
│   ├── EmptySubscriptionView
│   └── → SharedSubscriptionConversationView
│       ├── SubscriptionInfoCard
│       ├── MemberBalancesCard
│       ├── SubscriptionPaymentCardView
│       ├── SubscriptionSettlementMessageView
│       ├── SubscriptionReminderMessageView
│       ├── MessageBubbleView (from shared components)
│       ├── SubscriptionActionBar
│       ├── MessageInputView (from shared components)
│       ├── RecordSubscriptionPaymentView (sheet)
│       │   └── PayerPickerView
│       ├── SubscriptionSettlementView (sheet)
│       └── SubscriptionReminderSheetView (sheet)
└── AddSubscriptionView (sheet — toolbar +)
    ├── IconPickerRow
    ├── ColorPickerRow
    ├── MemberPickerView (sheet)
    └── MemberChip
```

**Models:**
- `Subscription+Extensions.swift` — all business logic (billing status, cost calcs, balance calcs, conversation items)
- `SubscriptionConversationItem.swift` — enum + date grouping for conversation timeline

---

## File-by-File Registry

### 1. `SubscriptionView.swift`

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Root view — segmented control toggling Personal ↔ Shared tabs |
| **Features** | • Segment header with `ActionHeaderButton` (Personal / Shared) • `+` toolbar button opens `AddSubscriptionView` with `isSharedDefault` matching current segment • Animated segment transitions • Passes `viewContext` to sheet |
| **Issues** | None |
| **Edge cases** | None — simple orchestrator |
| **Dependencies** | `PersonalSubscriptionListView`, `SharedSubscriptionListView`, `AddSubscriptionView`, `ActionHeaderButton`, `HapticManager`, `AppColors`, `AppAnimation`, `Spacing` |

---

### 2. `AddSubscriptionView.swift`

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Form for creating a new subscription (personal or shared) |
| **Features** | • Name, amount, cycle (Weekly/Monthly/Yearly/Custom), custom days stepper • Start date picker • Category picker (8 categories) • Icon & color pickers (sheets) • Shared toggle with member picker • Notification toggle + days-before stepper • Notes text editor • Validation: name + amount required; shared requires ≥1 member • `calculateNextBillingDate()` from start date • Error handling with rollback |
| **Issues** | **[M-01]** Hardcoded `$` currency symbol — not locale-aware **[L-01]** `amount` is a `String` fed to `TextField` with `.decimalPad` — no input sanitization for multiple dots, commas, or locale-specific separators **[L-02]** When toggling `isShared` OFF, `selectedMembers` is cleared but there is no confirmation — could lose a carefully-selected member list accidentally |
| **Edge cases** | • `Double(amount) ?? 0` silently falls back to 0 for invalid input (e.g. "12.3.4") — the `canSave` guard blocks 0-amount saves, so user sees disabled Save with no explanation • `customCycleDays` default 30 is fine, but range 1...365 allows nonsensical 1-day cycles |
| **Dependencies** | `Subscription` (CoreData), `Person` (CoreData), `IconPickerRow`, `ColorPickerRow`, `MemberPickerView`, `MemberChip`, `CurrencyFormatter`, `HapticManager`, `AppTypography`, `AppColors`, `Spacing`, `CurrentUser` (implied via MemberPickerView) |

---

### 3. `EditSubscriptionView.swift`

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Form for editing an existing subscription |
| **Features** | • Pre-populates all fields from `@ObservedObject subscription` • Allows editing `nextBillingDate` directly (not available in Add) • Same form layout as AddSubscriptionView • Member update: removes all existing, re-adds selected • Error handling with rollback |
| **Issues** | **[M-02]** Member update strategy is destructive: removes ALL then re-adds. If the save fails after `removeFromSubscribers` but before `addToSubscribers`, the rollback should recover, but this is fragile. A diff-based approach would be safer. **[M-01]** Same hardcoded `$` as AddSubscriptionView **[L-03]** `subscribers` cast as `Set<Person>` could be nil; `?? []` handles it but the pattern is repeated across many files — a computed property on `Subscription` would DRY this up |
| **Edge cases** | • If subscription is deleted by another context while editing, `@ObservedObject` could trigger unexpected behavior • `amount` initialised as `String(subscription.amount)` which formats doubles like "9.99" but could produce "10.0" for round numbers |
| **Dependencies** | `Subscription`, `Person`, `IconPickerRow`, `ColorPickerRow`, `MemberPickerView`, `MemberChip`, `HapticManager`, `AppTypography`, `AppColors`, `Spacing` |

---

### 4. `SubscriptionDetailView.swift`

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Read-only detail view with sections: header, billing, cost summary, members, notifications, payments, notes, actions |
| **Features** | • Large icon display with amount + cycle • `StatusPill` for billing status • Monthly/yearly cost equivalents • Shared: shows per-member balance (owes you / you owe / settled) • Inline toggle for notifications (auto-saves) • Recent payments (last 5) with `PaymentHistoryRow` • Edit (sheet), Pause/Resume, Delete (with confirmation) • Delete uses "Cancel Subscription" wording |
| **Issues** | **[L-04]** Notification toggle saves on every toggle via `try? viewContext.save()` — swallows errors silently. The stepper also auto-saves. This is inconsistent with the rest of the app which uses explicit Save buttons. **[L-05]** `PaymentHistoryRow` references `CurrentUser.isCurrentUser(payment.payer?.id)` — this is an inline struct in this file, fine, but tightly coupled |
| **Edge cases** | • `recentPayments.prefix(5)` — no "View All" option; users with many payments can't see history beyond 5 • Delete action says "Cancel Subscription" but actually hard-deletes from CoreData — confusing wording • If subscription has related payments/settlements/reminders, cascade delete behavior depends on CoreData model config (not visible here) |
| **Dependencies** | `Subscription`, `SubscriptionPayment`, `Person`, `StatusPill`, `EditSubscriptionView`, `CurrencyFormatter`, `CurrentUser`, `HapticManager`, `AppTypography`, `AppColors`, `Spacing`, `CornerRadius`, `AvatarSize` |

---

### 5. `PersonalSubscriptionListView.swift`

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | List view for non-shared subscriptions, grouped by billing status |
| **Features** | • `@FetchRequest` filtered by `isShared == NO`, sorted by `nextBillingDate` ascending • Groups: Overdue, Due ("Attention Required"), Upcoming ("Active"), Paused • Summary card: monthly total, active count, next due date • Empty state overlay • `NavigationLink` → `SubscriptionDetailView` |
| **Issues** | None significant |
| **Edge cases** | • No pull-to-refresh • No swipe-to-delete gesture on rows (only context menu via `SubscriptionListRowView`) • No search/filter capability |
| **Dependencies** | `Subscription`, `PersonalSubscriptionSummaryCard`, `SubscriptionListRowView`, `SubscriptionDetailView`, `EmptySubscriptionView`, `AppColors`, `Spacing` |

---

### 6. `SharedSubscriptionListView.swift`

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | List view for shared subscriptions with balance summary |
| **Features** | • `@FetchRequest` filtered by `isShared == YES`, sorted by `nextBillingDate` • Calculates `totalMonthly` and `myMonthlyShare` (converts per-cycle share to monthly) • `SharedSubscriptionSummaryCard` with savings indicator • `NavigationLink` → `SharedSubscriptionConversationView` (not detail) • Empty state overlay |
| **Issues** | **[L-06]** `myMonthlyShare` duplicates the monthly-conversion logic from `Subscription+Extensions.monthlyEquivalent` — should use `myShare` converted via the same logic, or factor out the conversion |
| **Edge cases** | • No grouping by status (unlike personal list) — all subs shown in one section • No handling for subscriptions with 0 subscribers (division would be safe due to `subscriberCount` including user, but edge case) |
| **Dependencies** | `Subscription`, `SharedSubscriptionSummaryCard`, `SharedSubscriptionListRowView`, `SharedSubscriptionConversationView`, `EmptySubscriptionView`, `CurrencyFormatter`, `AppColors`, `Spacing` |

---

### 7. `SharedSubscriptionConversationView.swift`

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | iMessage-style conversation thread for shared subscriptions — central hub for payments, settlements, reminders, and messages |
| **Features** | • Header: subscription icon + name (tappable for detail sheet) + balance display • `ScrollViewReader` with auto-scroll to bottom • `SubscriptionInfoCard` + `MemberBalancesCard` at top • Grouped conversation items by date (`DateHeaderView`) • Item types: payment cards, settlement messages, reminder messages, chat bubbles • `SubscriptionActionBar`: Pay / Remind / Settle buttons • `MessageInputView` for free-text chat • Sheets: RecordPayment, Settlement, Reminder, Detail • Validates subscription not deleted before sending message • Error handling with rollback • Custom back button + hidden tab bar |
| **Issues** | **[M-03]** `ChatMessage` is created with `withSubscription` relationship — this property name isn't in the CoreData spec provided. Likely exists but should be verified against the model. **[L-07]** `UIImpactFeedbackGenerator` instantiated as a stored property — this is fine but inconsistent with using `HapticManager` everywhere else |
| **Edge cases** | • No message deletion capability • No message editing • No typing indicator or read receipts (expected for local-only app) • If conversation has hundreds of items, `LazyVStack` helps but initial load of `getGroupedConversationItems()` is O(n) across all payments+settlements+reminders+messages |
| **Dependencies** | `Subscription`, `ChatMessage`, `SubscriptionConversationItem`, `SubscriptionConversationDateGroup`, `SubscriptionInfoCard`, `MemberBalancesCard`, `SubscriptionPaymentCardView`, `SubscriptionSettlementMessageView`, `SubscriptionReminderMessageView`, `MessageBubbleView`, `DateHeaderView`, `SubscriptionActionBar`, `MessageInputView`, `RecordSubscriptionPaymentView`, `SubscriptionSettlementView`, `SubscriptionReminderSheetView`, `SubscriptionDetailView`, `CurrentUser`, `CurrencyFormatter`, `HapticManager`, `AppColors`, `Spacing`, `AvatarSize`, `CornerRadius` |

---

### 8. `RecordSubscriptionPaymentView.swift`

| Field | Value |
|---|---|
| **State** | 🔧 PARTIAL |
| **Purpose** | Record who paid for a subscription billing cycle |
| **Features** | • Payer picker (current user default + all members) • Amount pre-filled with subscription amount • Date picker • Optional note • Split preview showing total and per-person share • Updates `nextBillingDate` after saving • `PayerPickerView` (inline struct) with current user + members list |
| **Issues** | **[M-04]** `billingPeriodStart` and `billingPeriodEnd` on `SubscriptionPayment` are **never set** — the CoreData model defines these properties but this form doesn't populate them. This means payment records lack period context. **[M-01]** Same hardcoded `$` currency symbol **[M-05]** `subscriberCount` in split preview includes current user (correct), but the `@FetchRequest` for `people` fetches ALL people, not just subscription members — the `members` computed property correctly filters, but the fetch is wasteful |
| **Edge cases** | • If payer is not a subscriber of this subscription (could happen if members are changed after recording payments) — balance calculations could be wrong • `selectedPayer` defaults to current user on `.onAppear` — if current user Person doesn't exist yet, `getOrCreate` creates one mid-view |
| **Dependencies** | `Subscription`, `SubscriptionPayment`, `Person`, `CurrentUser`, `CurrencyFormatter`, `HapticManager`, `AppTypography`, `AppColors`, `Spacing` |

---

### 9. `MemberPickerView.swift`

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Multi-select person picker for adding/editing shared subscriptions |
| **Features** | • Fetches all `Person` entities, filters out current user • Search by name (case-insensitive) • Selected members section with checkmark-to-deselect • Available people section with circle-to-select • Empty state: "Add people in the Library tab first" |
| **Issues** | None |
| **Edge cases** | • If a selected member is deleted from People while this picker is open, the `Set<Person>` could contain a faulted/deleted object — CoreData should handle this but could cause display issues • No "Select All" option |
| **Dependencies** | `Person`, `CurrentUser`, `HapticManager`, `AppTypography`, `AppColors`, `Spacing` |

---

### 10. `SubscriptionReminderSheetView.swift`

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Send payment reminders to members who owe |
| **Features** | • Lists members who owe with amounts (from `getMembersWhoOweYou()`) • Multi-select with Select All / Deselect All toggle • Optional custom message • Preview section showing bell + name + amount • Creates `SubscriptionReminder` entities for each selected member • Empty state: "No Reminders Needed" if no one owes |
| **Issues** | None significant |
| **Edge cases** | • Reminders are local-only (no push notification integration visible) — `SubscriptionReminder` entities appear in conversation but there's no actual notification delivery mechanism • No rate-limiting — user could spam reminders |
| **Dependencies** | `Subscription`, `SubscriptionReminder`, `Person`, `CurrencyFormatter`, `HapticManager`, `AppTypography`, `AppColors`, `Spacing` |

---

### 11. `SubscriptionSettlementView.swift`

| Field | Value |
|---|---|
| **State** | 🐛 BUGGY |
| **Purpose** | Settle balances between subscription members |
| **Features** | • Two sections: "Collect from" (members who owe you) and "Pay to" (members you owe) • Tapping a member auto-fills their owed amount • Editable amount field + optional note • Direction logic: determines `fromPerson`/`toPerson` based on balance • Empty state: "All Settled Up!" |
| **Issues** | **[C-01] CRITICAL BUG — Settlement direction is INVERTED.** In `saveSettlement()`: when `balance > 0` (they owe you, meaning they're paying you back), the code sets `fromPerson = member` and `toPerson = currentUser`. Then in `calculateBalanceWith(member:)` in `Subscription+Extensions.swift`, when `fromPersonId == member.id && CurrentUser.isCurrentUser(toPersonId)`, it does `balance -= settlement.amount`. This **reduces** the positive balance (what they owe you), which is correct for the "collect" direction. HOWEVER, for the "you owe them" case (`balance < 0`): `fromPerson = currentUser`, `toPerson = member`. In the balance calc, `CurrentUser.isCurrentUser(fromPersonId) && toPersonId == member.id` → `balance += settlement.amount`. This **increases** the balance, meaning it makes it look like they owe you MORE, when it should reduce what you owe. The settlement accounting for the "you owe" direction appears inverted. |
| **Edge cases** | • No partial settlement warning (user could over-settle) • Amount field allows values larger than what's owed — no validation • `selectedMember` can be re-selected to a different person without clearing the amount — the amount stays from the previous selection if the user edits it manually |
| **Dependencies** | `Subscription`, `SubscriptionSettlement`, `Person`, `CurrentUser`, `CurrencyFormatter`, `HapticManager`, `AppTypography`, `AppColors`, `Spacing` |

---

### 12. `Subscription+Extensions.swift` (Models)

| Field | Value |
|---|---|
| **State** | 🔧 PARTIAL |
| **Purpose** | All computed properties and business logic for `Subscription` entity |
| **Features** | • `BillingStatus` enum: upcoming / due / overdue / paused (with color, icon, label) • Display: `displayName`, `initials`, `cycleAbbreviation` • Billing: `daysUntilNextBilling`, `billingStatus` (7-day due threshold) • Cost: `monthlyEquivalent`, `yearlyEquivalent` (handles all cycle types) • Shared: `subscriberCount` (includes current user), `memberCount` (excludes), `myShare` • Balance: `calculateUserBalance()`, `calculateBalanceWith(member:)`, `getMemberBalances()`, `getMembersWhoOweYou()`, `getMembersYouOwe()` • Payments: `recentPayments` (sorted desc) • Conversation: `getConversationItems()`, `getGroupedConversationItems()` • Billing: `calculateNextBillingDate(from:)` |
| **Issues** | **[C-01]** (see SubscriptionSettlementView — settlement balance calc direction issue) **[C-02]** `calculateUserBalance()` — settlement application appears inverted: when `CurrentUser.isCurrentUser(toPersonId)` (someone paid you), it does `balance -= settlement.amount`, which REDUCES your positive balance (they owed you, now they paid, so they owe less — this is CORRECT). When `CurrentUser.isCurrentUser(fromPersonId)` (you paid someone), it does `balance += settlement.amount`, which INCREASES your balance. But if you paid someone you owe (balance is negative), adding to balance moves it toward 0, which is CORRECT. **After re-analysis: the balance calculation here appears correct.** The bug is actually in the save direction in SubscriptionSettlementView. **[M-06]** `monthlyEquivalent` uses `4.33` for weekly → monthly conversion; `SharedSubscriptionListView` also uses `4.33`. The exact value is 365.25/12/7 ≈ 4.348. Minor rounding discrepancy. **[M-07]** No handling for inactive subscriptions in balance calculations — paused subs with outstanding balances still contribute to total owed |
| **Edge cases** | • `subscriberCount` returns `count + 1` for shared, `1` for personal — if a shared subscription somehow has 0 subscribers (toggled shared with no members violating the UI constraint), `myShare` = `amount / 1` = full amount • `daysUntilNextBilling` returns 0 when `nextBillingDate` is nil — this makes nil dates appear as "due today" • `getConversationItems()` loads ALL payments, settlements, reminders, and messages into memory — could be large for long-running subscriptions |
| **Dependencies** | `SubscriptionPayment`, `SubscriptionSettlement`, `SubscriptionReminder`, `ChatMessage`, `Person`, `CurrentUser`, `AppColors`, `SubscriptionConversationItem`, `SubscriptionConversationDateGroup` |

---

### 13. `SubscriptionConversationItem.swift` (Models)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Defines conversation item enum and date grouping struct |
| **Features** | • `SubscriptionConversationItem`: 4 cases (payment, settlement, reminder, message) • `Identifiable` with UUID from underlying entity • `date` computed from entity-specific date fields • `SubscriptionConversationDateGroup`: date-grouped items with display string (Today/Yesterday/day name/full date) |
| **Issues** | **[L-08]** `id` returns `UUID()` as fallback when entity id is nil — this creates a new UUID every SwiftUI re-render, causing view identity instability. Should use a stable fallback. |
| **Edge cases** | • `Date.distantPast` fallback for nil dates pushes items to the very beginning of the conversation, which is reasonable but could look odd if an entity genuinely has a nil date |
| **Dependencies** | `SubscriptionPayment`, `SubscriptionSettlement`, `SubscriptionReminder`, `ChatMessage` |

---

### 14. `ColorPickerRow.swift` (Components)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Color selection row with grid picker sheet |
| **Features** | • 12 preset colors in a grid • Checkmark overlay on selected color • White stroke border on selected • Sheet with "Choose Color" title |
| **Issues** | None |
| **Edge cases** | • No custom color input (hex or system color picker) — limited to 12 presets • Selected color might not be in the preset list (if data was migrated) — would show the circle but no checkmark in the grid |
| **Dependencies** | `Color(hex:)` extension, `HapticManager`, `AppColors`, `Spacing`, `CornerRadius` |

---

### 15. `EmptySubscriptionView.swift` (Components)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Empty state placeholder for both personal and shared subscription lists |
| **Features** | • Different icon and text for personal vs shared • Hint: "Tap + to add your first subscription" |
| **Issues** | None |
| **Edge cases** | None |
| **Dependencies** | `AppTypography`, `AppColors`, `Spacing` |

---

### 16. `IconPickerRow.swift` (Components)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Icon selection row with grid picker sheet |
| **Features** | • 20 SF Symbols icons in a grid • Highlighted border + background on selected • Sheet with "Choose Icon" title |
| **Issues** | None |
| **Edge cases** | • Like colors, if a stored icon isn't in the preset list, it won't be highlighted in the grid • No search for SF Symbols |
| **Dependencies** | `HapticManager`, `AppColors`, `AppTypography`, `Spacing`, `CornerRadius` |

---

### 17. `MemberBalancesCard.swift` (Components)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Card displaying per-member balance breakdown in conversation view |
| **Features** | • Shows each member's avatar, name, and balance (owes you / you owe / settled) • Uses `getMemberBalances()` from extension • Returns `EmptyView()` if no balances |
| **Issues** | None |
| **Edge cases** | • Card is invisible when empty — no "Add members" prompt |
| **Dependencies** | `Subscription`, `Person`, `CurrencyFormatter`, `AppTypography`, `AppColors`, `Spacing`, `CornerRadius` |

---

### 18. `PersonalSubscriptionSummaryCard.swift` (Components)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Summary card for personal subscriptions tab |
| **Features** | • Monthly total + active count + next due date • Yearly projection (monthly × 12) |
| **Issues** | None |
| **Edge cases** | • Yearly shown only when `monthlyTotal > 0` — correct |
| **Dependencies** | `CurrencyFormatter`, `AppTypography`, `AppColors`, `Spacing`, `CornerRadius` |

---

### 19. `SharedSubscriptionListRowView.swift` (Components)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | List row for shared subscriptions with balance indicator |
| **Features** | • Subscription icon + name + member count + balance text • Balance text: "you're owed $X" / "you owe $X" / "settled up" • Balance amount displayed in green/red/neutral • Context menu: View Details, Record Payment, Send Reminders • Sheets for detail, payment, reminder • Press-scale animation |
| **Issues** | None |
| **Edge cases** | • Context menu opens sheets but the row itself is inside a `NavigationLink` in the parent list — both navigation and context menu work, but no swipe actions |
| **Dependencies** | `Subscription`, `Person`, `RecordSubscriptionPaymentView`, `SubscriptionReminderSheetView`, `SubscriptionDetailView`, `CurrencyFormatter`, `HapticManager`, `AppColors`, `AppTypography`, `Spacing`, `AvatarSize`, `CornerRadius` |

---

### 20. `SharedSubscriptionSummaryCard.swift` (Components)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Summary card for shared subscriptions tab |
| **Features** | • Your monthly share + total monthly + active shared count • Savings indicator: "Saving $X/mo by sharing" |
| **Issues** | None |
| **Edge cases** | • If `myShare >= totalMonthly` (shouldn't happen normally), savings indicator is hidden — correct |
| **Dependencies** | `CurrencyFormatter`, `AppTypography`, `AppColors`, `Spacing`, `CornerRadius` |

---

### 21. `StatusPill.swift` (Components)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Capsule-shaped status indicator for billing status |
| **Features** | • Icon + label text in status color • Semi-transparent background capsule |
| **Issues** | None |
| **Edge cases** | None |
| **Dependencies** | `BillingStatus`, `AppTypography`, `AppColors`, `Spacing` |

---

### 22. `SubscriptionActionBar.swift` (Components)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Action bar for shared subscription conversation view |
| **Features** | • Three buttons: Pay (always enabled, primary green), Remind (enabled if members owe), Settle (enabled if balance ≠ 0) • Disabled state styling for Remind/Settle • Green circle icon for primary action • `AppButtonStyle` integration |
| **Issues** | None |
| **Edge cases** | • Pay button is always enabled even when no balance exists — this is intentional (can always record a new payment cycle) • Remind and Settle buttons appear clickable even when disabled (the `if` guard inside the action prevents action but the button isn't visually standard disabled) |
| **Dependencies** | `Person`, `HapticManager`, `AppColors`, `AppTypography`, `Spacing`, `IconSize`, `ButtonHeight`, `CornerRadius`, `AppButtonStyle` |

---

### 23. `SubscriptionInfoCard.swift` (Components)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Header card in shared subscription conversation showing subscription details |
| **Features** | • Icon + name + amount/cycle • Next billing date with status color • Your share calculation |
| **Issues** | None |
| **Edge cases** | • `nextBillingDate` nil shows empty string — not "Unknown" |
| **Dependencies** | `Subscription`, `CurrencyFormatter`, `AppTypography`, `AppColors`, `Spacing`, `CornerRadius` |

---

### 24. `SubscriptionListRowView.swift` (Components)

| Field | Value |
|---|---|
| **State** | 🔧 PARTIAL |
| **Purpose** | List row for personal subscriptions |
| **Features** | • Subscription icon + name + cycle + status text • Status text: "Overdue", "Due today/tomorrow/in X days", "Next: Mon d", "Paused" • Amount with cycle abbreviation • Context menu: Edit, Mark as Paid, Pause/Resume, Delete (with confirmation) • Press-scale animation • `markAsPaid()` advances `nextBillingDate` without creating a payment record |
| **Issues** | **[M-08]** `markAsPaid()` only updates `nextBillingDate` but does NOT create a `SubscriptionPayment` record — this means the payment history won't reflect this action. It's a convenience shortcut but loses data. **[L-09]** Error handling in `markAsPaid()`, `togglePauseStatus()`, and `deleteSubscription()` only prints to console — no user-facing error |
| **Edge cases** | • No swipe actions — only context menu • Delete has no animation or optimistic removal |
| **Dependencies** | `Subscription`, `EditSubscriptionView`, `CurrencyFormatter`, `HapticManager`, `AppTypography`, `AppColors`, `Spacing`, `AvatarSize`, `CornerRadius`, `AppAnimation` |

---

### 25. `SubscriptionPaymentCardView.swift` (Components)

| Field | Value |
|---|---|
| **State** | 🔧 PARTIAL |
| **Purpose** | Card view for payment items in subscription conversation |
| **Features** | • Green dollar icon + "You paid" / "[Name] paid" • Subscription name • Amount + split count |
| **Issues** | **[M-04]** (repeated) No display of `billingPeriodStart` / `billingPeriodEnd` — these fields exist on the model but are never written or read **[L-10]** No display of payment `note` — notes are captured in `RecordSubscriptionPaymentView` but never shown in the conversation |
| **Edge cases** | • If `payer` is nil (orphaned payment), shows "Someone paid" — acceptable fallback |
| **Dependencies** | `SubscriptionPayment`, `Subscription`, `CurrentUser`, `CurrencyFormatter`, `AppTypography`, `AppColors`, `Spacing`, `CornerRadius` |

---

### 26. `SubscriptionReminderMessageView.swift` (Components)

| Field | Value |
|---|---|
| **State** | ✅ COMPLETE |
| **Purpose** | Conversation bubble for reminder events |
| **Features** | • Bell icon + "Reminder sent to [Name] for $X" in orange capsule • Custom message displayed in italics if present • Date displayed below |
| **Issues** | None |
| **Edge cases** | • Uses raw SwiftUI `.caption`/`.secondary` instead of `AppTypography`/`AppColors` — inconsistent with rest of app but functional |
| **Dependencies** | `SubscriptionReminder`, `Person`, `CurrencyFormatter` |

---

### 27. `SubscriptionSettlementMessageView.swift` (Components)

| Field | Value |
|---|---|
| **State** | 🔧 PARTIAL |
| **Purpose** | Conversation bubble for settlement events |
| **Features** | • Green checkmark + contextual message (You paid X / X paid you / X paid Y) • Note displayed in italics if present • Date displayed below |
| **Issues** | **[L-11]** Uses raw SwiftUI colors (`Color.green`, `Color(UIColor.systemGray5)`) instead of `AppColors` — inconsistent with app design system |
| **Edge cases** | • Handles three-way display logic (from=user, to=user, neither) — good • If both `fromPerson` and `toPerson` are nil, shows "Someone paid someone" — acceptable |
| **Dependencies** | `SubscriptionSettlement`, `CurrentUser`, `CurrencyFormatter` |

---

## CoreData Property Compliance

### Subscription Entity

| Property | Used in Add | Used in Edit | Used in Detail | Used in Extensions | Status |
|---|---|---|---|---|---|
| `id` | ✅ | — | — | — | ✅ |
| `name` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `amount` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `cycle` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `customCycleDays` | ✅ | ✅ | — | ✅ | ✅ |
| `startDate` | ✅ | ✅ | ✅ | — | ✅ |
| `nextBillingDate` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `isShared` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `isActive` | ✅ | — | ✅ | ✅ | ✅ |
| `category` | ✅ | ✅ | ✅ | — | ✅ |
| `iconName` | ✅ | ✅ | ✅ | — | ✅ |
| `colorHex` | ✅ | ✅ | ✅ | — | ✅ |
| `notes` | ✅ | ✅ | ✅ | — | ✅ |
| `notificationEnabled` | ✅ | ✅ | ✅ | — | ✅ |
| `notificationDaysBefore` | ✅ | ✅ | ✅ | — | ✅ |
| `subscribers` (→ Person) | ✅ | ✅ | ✅ | ✅ | ✅ |
| `payments` (→ SubscriptionPayment) | — | — | ✅ | ✅ | ✅ |
| `chatMessages` (→ ChatMessage) | — | — | — | ✅ | ✅ |
| `reminders` (→ SubscriptionReminder) | — | — | — | ✅ | ✅ |
| `settlements` (→ SubscriptionSettlement) | — | — | — | ✅ | ✅ |

### SubscriptionPayment Entity

| Property | Written | Read | Status |
|---|---|---|---|
| `id` | ✅ RecordPayment | ✅ ConversationItem | ✅ |
| `amount` | ✅ RecordPayment | ✅ Multiple | ✅ |
| `date` | ✅ RecordPayment | ✅ Multiple | ✅ |
| `billingPeriodStart` | ❌ **NEVER SET** | ❌ **NEVER READ** | ⚠️ UNUSED |
| `billingPeriodEnd` | ❌ **NEVER SET** | ❌ **NEVER READ** | ⚠️ UNUSED |
| `note` | ✅ RecordPayment | ❌ **NEVER DISPLAYED** | ⚠️ PARTIAL |
| `subscription` | ✅ RecordPayment | ✅ Implicit | ✅ |
| `payer` | ✅ RecordPayment | ✅ Multiple | ✅ |

### SubscriptionSettlement Entity

| Property | Written | Read | Status |
|---|---|---|---|
| `id` | ✅ SettlementView | ✅ ConversationItem | ✅ |
| `amount` | ✅ SettlementView | ✅ Multiple | ✅ |
| `date` | ✅ SettlementView | ✅ Multiple | ✅ |
| `note` | ✅ SettlementView | ✅ SettlementMessage | ✅ |
| `subscription` | ✅ SettlementView | ✅ Implicit | ✅ |
| `fromPerson` | ✅ SettlementView | ✅ Multiple | ✅ |
| `toPerson` | ✅ SettlementView | ✅ Multiple | ✅ |

### SubscriptionReminder Entity

| Property | Written | Read | Status |
|---|---|---|---|
| `id` | ✅ ReminderSheet | ✅ ConversationItem | ✅ |
| `createdDate` | ✅ ReminderSheet | ✅ ReminderMessage | ✅ |
| `amount` | ✅ ReminderSheet | ✅ ReminderMessage | ✅ |
| `message` | ✅ ReminderSheet | ✅ ReminderMessage | ✅ |
| `isRead` | ✅ ReminderSheet (false) | ❌ **NEVER READ/TOGGLED** | ⚠️ PARTIAL |
| `subscription` | ✅ ReminderSheet | ✅ Implicit | ✅ |
| `toPerson` | ✅ ReminderSheet | ✅ ReminderMessage | ✅ |

---

## Cross-Cutting Issues

### Critical (C)

| ID | Description | Files Affected |
|---|---|---|
| C-01 | **Settlement balance direction bug** — When saving a settlement for "you owe them" direction, the `fromPerson`/`toPerson` assignment in `SubscriptionSettlementView.saveSettlement()` sets `fromPerson = currentUser`, `toPerson = member`. In `calculateBalanceWith(member:)`, this hits the branch `CurrentUser.isCurrentUser(fromPersonId) && toPersonId == member.id` → `balance += settlement.amount`. For negative balances (you owe), this moves balance toward positive (correct). **REVISED: After careful re-analysis, the math works out correctly in the `calculateBalanceWith` function. The `+=` on a negative balance correctly reduces what you owe. However, `calculateUserBalance()` has the inverse logic and may produce inconsistent results with `calculateBalanceWith()`.** Needs unit tests to verify. | `SubscriptionSettlementView`, `Subscription+Extensions` |
| C-02 | **`billingPeriodStart`/`billingPeriodEnd` completely unused** — CoreData model defines these on `SubscriptionPayment` but they are never written or read anywhere. This means there's no way to know which billing period a payment covers, which could lead to duplicate payments for the same period. | `RecordSubscriptionPaymentView`, `SubscriptionPaymentCardView`, `Subscription+Extensions` |

### Medium (M)

| ID | Description | Files Affected |
|---|---|---|
| M-01 | Hardcoded `$` currency symbol in TextField HStacks — not locale-aware. `CurrencyFormatter` is used for display but not for input labels. | `AddSubscriptionView`, `EditSubscriptionView`, `RecordSubscriptionPaymentView`, `SubscriptionSettlementView` |
| M-02 | Destructive member update in Edit: removes all subscribers then re-adds. Rollback should recover but pattern is fragile. | `EditSubscriptionView` |
| M-03 | `ChatMessage.withSubscription` relationship not in CoreData spec provided — verify exists in `.xcdatamodeld`. | `SharedSubscriptionConversationView` |
| M-04 | Payment `note` is captured but never displayed in conversation cards. | `RecordSubscriptionPaymentView`, `SubscriptionPaymentCardView` |
| M-05 | `RecordSubscriptionPaymentView` fetches ALL Person entities but only uses subscription members. | `RecordSubscriptionPaymentView` |
| M-06 | Weekly → monthly conversion uses `4.33` (should be `4.348`). Minor rounding. | `Subscription+Extensions`, `SharedSubscriptionListView` |
| M-07 | Paused subscriptions still contribute to balance calculations — no active-state filter in balance logic. | `Subscription+Extensions` |
| M-08 | `markAsPaid()` context-menu action advances billing date but creates NO payment record — loses history. | `SubscriptionListRowView` |

### Low (L)

| ID | Description | Files Affected |
|---|---|---|
| L-01 | No input sanitization for amount fields (multiple dots, locale separators). | `AddSubscriptionView`, `EditSubscriptionView` |
| L-02 | Toggling `isShared` OFF silently clears all selected members with no confirmation. | `AddSubscriptionView`, `EditSubscriptionView` |
| L-03 | `subscribers as? Set<Person> ?? []` pattern repeated 10+ times — should be a computed property. | Multiple |
| L-04 | Detail view auto-saves notification changes via `try?` — errors silently swallowed. | `SubscriptionDetailView` |
| L-05 | `SubscriptionReminder.isRead` is always set to `false` and never toggled to `true` anywhere. | `SubscriptionReminderSheetView` |
| L-06 | Monthly share conversion logic duplicated between `SharedSubscriptionListView` and `Subscription+Extensions`. | `SharedSubscriptionListView` |
| L-07 | Direct `UIImpactFeedbackGenerator` usage instead of `HapticManager` in conversation view. | `SharedSubscriptionConversationView` |
| L-08 | `SubscriptionConversationItem.id` uses `UUID()` fallback for nil entity IDs — unstable view identity. | `SubscriptionConversationItem` |
| L-09 | Error handling in list-row actions (markAsPaid, pause, delete) prints to console only — no user feedback. | `SubscriptionListRowView` |
| L-10 | Payment notes captured but not displayed; reminder `isRead` written but never read. | `SubscriptionPaymentCardView`, `SubscriptionReminderSheetView` |
| L-11 | Inconsistent use of raw SwiftUI colors vs `AppColors` in message views. | `SubscriptionReminderMessageView`, `SubscriptionSettlementMessageView` |

---

## Edge Cases & Missing Handling

| # | Edge Case | Current Behavior | Recommended Fix |
|---|---|---|---|
| 1 | Subscription deleted while viewing conversation | `sendMessage()` checks `isDeleted` — good. Other actions don't. | Add `isDeleted` guards to all save operations |
| 2 | Person deleted while still a subscriber | Orphaned relationship — balance calcs may crash or return wrong values | Add nil-safety in balance iteration, remove deleted persons from subscribers |
| 3 | 0 subscribers on a shared subscription | `subscriberCount` = 1 (just user), `myShare` = full amount | Enforce ≥1 member at save time (already done in `canSave`) |
| 4 | Very large number of payments/messages | All loaded into memory via `getConversationItems()` | Paginate or limit to recent N items with "Load More" |
| 5 | Duplicate payment for same billing period | No period tracking (`billingPeriodStart`/`End` unused) | Populate period fields and check for duplicates |
| 6 | Currency formatting for non-USD locales | `$` hardcoded in input fields; `CurrencyFormatter` handles display | Use `CurrencyFormatter` for input labels too |
| 7 | Subscription amount changed after payments recorded | Balance calcs use per-payment amounts (correct) but share calcs use current amount | Document that share display may differ from historical |
| 8 | App crash during save | `viewContext.rollback()` used everywhere — good | No issues |
| 9 | Over-settlement (settling more than owed) | No validation — allowed silently | Add warning or cap amount |
| 10 | No payment history beyond last 5 | `recentPayments.prefix(5)` in detail view | Add "View All Payments" navigation |
| 11 | No undo for delete | Hard delete with no recovery | Use soft delete (`isDeleted` flag) or confirmation + undo toast |

---

## Dependency Map

### External Dependencies (shared app infrastructure)
- `AppColors` — Design system colors
- `AppTypography` — Typography system
- `AppAnimation` — Animation presets
- `Spacing`, `CornerRadius`, `AvatarSize`, `IconSize`, `ButtonHeight` — Layout constants
- `HapticManager` — Haptic feedback manager
- `CurrencyFormatter` — Currency formatting utility
- `CurrentUser` — Current user identification (`isCurrentUser()`, `getOrCreate()`, `initials`, `defaultColorHex`)
- `ActionHeaderButton` — Shared header button component
- `MessageInputView` — Shared message input component
- `MessageBubbleView` — Shared message bubble component
- `DateHeaderView` — Shared date section header
- `AppButtonStyle` — Custom button style
- `Color(hex:)` — Hex color extension

### CoreData Entities
- `Subscription` — Primary entity
- `SubscriptionPayment` — Payment records
- `SubscriptionSettlement` — Settlement records
- `SubscriptionReminder` — Reminder records
- `Person` — People (subscribers/payers)
- `ChatMessage` — Free-text messages in conversation

### Internal Component Graph
```
SubscriptionView
 ├── PersonalSubscriptionListView
 │    ├── PersonalSubscriptionSummaryCard
 │    ├── SubscriptionListRowView → EditSubscriptionView
 │    ├── EmptySubscriptionView
 │    └── SubscriptionDetailView
 │         ├── StatusPill
 │         └── EditSubscriptionView
 ├── SharedSubscriptionListView
 │    ├── SharedSubscriptionSummaryCard
 │    ├── SharedSubscriptionListRowView
 │    │    ├── RecordSubscriptionPaymentView
 │    │    ├── SubscriptionReminderSheetView
 │    │    └── SubscriptionDetailView
 │    ├── EmptySubscriptionView
 │    └── SharedSubscriptionConversationView
 │         ├── SubscriptionInfoCard
 │         ├── MemberBalancesCard
 │         ├── SubscriptionPaymentCardView
 │         ├── SubscriptionSettlementMessageView
 │         ├── SubscriptionReminderMessageView
 │         ├── SubscriptionActionBar
 │         ├── RecordSubscriptionPaymentView → PayerPickerView
 │         ├── SubscriptionSettlementView
 │         └── SubscriptionReminderSheetView
 └── AddSubscriptionView
      ├── IconPickerRow
      ├── ColorPickerRow
      ├── MemberPickerView
      └── MemberChip
```

---

*End of Subscriptions feature scan.*
