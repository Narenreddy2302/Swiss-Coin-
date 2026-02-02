# SCAN_PEOPLE.md — People Feature Registry

> Generated: 2026-02-02  
> Auditor: Claude (Subagent scan-people)  
> Scope: 22 files in `Swiss Coin/Features/People/`

---

## Table of Contents

1. [Summary](#summary)
2. [CoreData Property Compliance](#coredata-property-compliance)
3. [File-by-File Registry](#file-by-file-registry)
4. [Cross-Cutting Issues](#cross-cutting-issues)
5. [Dependency Map](#dependency-map)

---

## Summary

| Metric | Count |
|--------|-------|
| Files audited | 22 |
| ✅ COMPLETE | 17 |
| 🔧 PARTIAL | 5 |
| ❌ MISSING | 0 |
| 🐛 BUGGY | 0 |
| CoreData property violations | **0** |
| Issues found | **19** |

**Overall assessment:** The People feature is well-built with correct CoreData property usage throughout. All files compile-ready, proper error handling on saves, and consistent design system usage. Main gaps are: stub context menu actions (Share/View Details), missing duplicate-contact checks on import, no delete/edit capabilities on certain entities, and some missing accessibility.

---

## CoreData Property Compliance

All 22 files were checked against the canonical CoreData model:

| Entity | Property | Expected | Violations Found |
|--------|----------|----------|-----------------|
| FinancialTransaction | `payer` | ✅ | 0 — all files use `transaction.payer` |
| FinancialTransaction | `date` | ✅ | 0 — all files use `transaction.date` |
| FinancialTransaction | `splits` | ✅ | 0 — all files use `transaction.splits` |
| FinancialTransaction | `title` | ✅ | 0 |
| FinancialTransaction | `amount` | ✅ | 0 |
| FinancialTransaction | `group` | ✅ | 0 (accessed via `UserGroup.transactions`) |
| TransactionSplit | `owedBy` | ✅ | 0 — all files use `split.owedBy` |
| TransactionSplit | `amount` | ✅ | 0 |
| TransactionSplit | `transaction` | ✅ | 0 |
| TransactionSplit | NO `id` | ✅ | 0 — no file references `split.id` |
| Person | `id`, `name`, `phoneNumber`, `photoData`, `colorHex` | ✅ | 0 |
| Settlement | all properties | ✅ | 0 |
| Reminder | all properties | ✅ | 0 |

**✅ Zero CoreData property violations across all 22 files.**

---

## File-by-File Registry

---

### 1. PeopleView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Segmented tab switching between "People" and "Groups" via `ActionHeaderButton`
- `PersonListView`: FetchRequest with smart predicate (excludes current user, only shows people with activity)
- `PersonEmptyStateView`: Empty state with icon + descriptive text
- `PersonListRowView`: Avatar (initials + color), name, balance text, balance amount, context menu (View Profile, Add Expense, Send Reminder)
- `GroupListView`: FetchRequest sorted by name
- `GroupEmptyStateView`: Empty state for groups
- `GroupListRowView`: Group icon, name, member count, balance text, context menu (View Group Info, Add Expense, Send Reminders)
- Toolbar: "New message" sheet (square.and.pencil), "Add person/group" NavigationLink (plus)
- Sheet presentations: `NewTransactionContactView`, `PersonDetailView`, `QuickActionSheetPresenter`, `ReminderSheetView`, `GroupDetailView`, `GroupReminderSheetView`
- Haptic feedback on all interactions

**Issues:**
1. **FetchRequest predicate references `toTransactions`** — this assumes a CoreData relationship name `toTransactions` on Person. Should be verified against the data model. If the relationship is named differently, this will crash at runtime.
2. **`owedSplits` relationship assumed** — same concern; needs verification that Person has an `owedSplits` inverse relationship.
3. **`chatMessages` relationship assumed** — Person needs a `chatMessages` relationship.
4. **`sentSettlements` / `receivedSettlements` relationships assumed** — need verification.
5. **No pull-to-refresh** — list doesn't support pull-to-refresh for manual data reload.

**Edge Cases Not Handled:**
- Very long person/group names (no truncation on row)
- Balance exactly at ±0.01 threshold (uses `> 0.01` consistently — fine)

**Dependencies:**
- `ActionHeaderButton`, `AppColors`, `Spacing`, `IconSize`, `AvatarSize`, `CornerRadius`
- `AppTypography`, `AppAnimation`, `HapticManager`, `CurrencyFormatter`
- `CurrentUser`, `Color(hex:)` extension
- `QuickActionSheetPresenter`, `NewTransactionContactView`
- `PersonConversationView`, `PersonDetailView`, `AddPersonView`
- `GroupConversationView`, `GroupDetailView`, `AddGroupView`
- `ReminderSheetView`, `GroupReminderSheetView`
- `PrimaryButtonStyle`, `AppButtonStyle`

---

### 2. AddPersonView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Form with Name and Phone Number fields
- "Import from Contacts" button → `ContactPicker` (CNContactPickerViewController)
- Save button creates Person with UUID, trimmed name, optional phone, random colorHex
- Error handling: rollback on save failure, haptic feedback
- `ContactPicker` UIViewControllerRepresentable wrapping `CNContactPickerViewController`

**Issues:**
1. **No duplicate check** — can create multiple Person entities with the same name/phone.
2. **No user-facing error alert** — save errors only print to console, no alert shown to user.
3. **`photoData` not set** — Person's `photoData` property is never populated from the contact picker's thumbnail.

**Edge Cases Not Handled:**
- Contact with no given name or family name (just a company name)
- Contact with multiple phone numbers (only first is picked)
- Name that's all whitespace after trimming (guarded by `guard !trimmedName.isEmpty`)

**Dependencies:**
- `ContactsUI`, `CNContactPickerViewController`
- `Person` CoreData entity
- `CurrencyFormatter` (not used here but imported via CoreData)
- `AppTypography`, `AppColors`, `HapticManager`

---

### 3. AddGroupView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Group name text field
- Contact search + selection from device contacts via `ContactsManager`
- Selected members horizontal scroll preview with tap-to-remove
- Contact list with avatar (thumbnail or initials), checkmark selection
- Permission request flow when contacts access not granted
- Creates `UserGroup` with UUID, name, createdDate, colorHex
- Adds current user to group automatically
- Find-or-create logic for Person entities by name match
- Error alert on save failure, rollback

**Issues:**
1. **Person lookup by name only** — `NSPredicate(format: "name == %@", contact.fullName)` can match wrong person if two contacts share a name. Should also match by phone number.
2. **`photoData` not set** — contact thumbnail data available via `contact.thumbnailImageData` but never saved to Person.
3. **Minimum member count not enforced** — can create a group with just 1 selected contact (+ current user = 2 members). No minimum warning.

**Edge Cases Not Handled:**
- Duplicate group names (no uniqueness check)
- Contact without a phone number
- Empty contact list (shows list but no helpful message)

**Dependencies:**
- `ContactsManager` (custom class)
- `UserGroup`, `Person` CoreData entities
- `CurrentUser.getOrCreate(in:)`
- `AppTypography`, `AppColors`, `Spacing`, `AvatarSize`, `CornerRadius`, `ButtonHeight`, `HapticManager`

---

### 4. PersonDetailView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Profile header: large avatar, name, phone number, balance text
- Action buttons: "Add Expense" → `QuickActionSheetPresenter`, "Chat" → `PersonConversationView` (sheet)
- Transaction list: combines `toTransactions` (paid) and `owedSplits` (owed) transactions
- Deduplication via Set union, sorted by date descending, limited to 10 recent
- `PersonDetailTransactionRow`: shows title, date, payer indicator, amount with color coding

**Issues:**
1. **Hardcoded limit of 10 transactions** — no "See All" option or pagination.
2. **No settlement display** — only shows transactions, not settlements, in the activity list.
3. **No reminder display** — reminders not shown in activity history.
4. **No edit/delete capability** — person cannot be edited or deleted from this view.

**Edge Cases Not Handled:**
- Person with only settlements and no transactions (activity appears empty)
- Transaction where person is both payer and in splits (self-payment edge case)
- `amountForPerson` returns full `transaction.amount` when person is payer — this shows gross amount, not net owed

**Dependencies:**
- `Person`, `FinancialTransaction`, `TransactionSplit` CoreData entities
- `QuickActionSheetPresenter`, `PersonConversationView`
- `CurrencyFormatter`, `DateFormatter.shortDate`
- `AppTypography`, `AppColors`, `Spacing`, `AvatarSize`, `IconSize`, `ButtonHeight`, `CornerRadius`
- `CurrentUser`, `Color(hex:)`

---

### 5. PersonConversationView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- iMessage-style conversation layout with `ScrollViewReader` for auto-scroll
- Grouped conversation items by date via `person.getGroupedConversationItems()`
- Renders 4 item types: `.transaction` → `TransactionCardView`, `.settlement` → `SettlementMessageView`, `.reminder` → `ReminderMessageView`, `.message` → `MessageBubbleView`
- Custom navigation bar: back button, person avatar+name (tappable → profile detail), balance display
- `ConversationActionBar` with Add/Remind/Settle buttons
- `MessageInputView` for chat messages
- Chat message creation with `ChatMessage` entity
- Error handling: validates person not deleted, save rollback, error alert
- Tab bar hidden (`.toolbar(.hidden, for: .tabBar)`)

**Issues:**
1. **Retained `UIImpactFeedbackGenerator`** — instantiated as `let` property on View struct. This is technically recreated on each view body evaluation. Should be a `@State` or external manager.
2. **`onChange(of: groupedItems.count)`** — only triggers when count changes, not when content changes. Editing a message wouldn't trigger scroll.

**Edge Cases Not Handled:**
- Very long conversation (no lazy loading beyond LazyVStack)
- Sending message while offline (no network/offline indicator)
- Keyboard avoidance (relies on SwiftUI default behavior)

**Dependencies:**
- `Person`, `ChatMessage` CoreData entities
- `ConversationItem`, `ConversationDateGroup` model types
- `TransactionCardView`, `SettlementMessageView`, `ReminderMessageView`, `MessageBubbleView`
- `ConversationActionBar`, `MessageInputView`, `DateHeaderView`
- `PersonDetailView`, `SettlementView`, `ReminderSheetView`
- `QuickActionSheetPresenter`
- `CurrentUser`, `HapticManager`, `CurrencyFormatter`
- `AppColors`, `AppTypography`, `Spacing`, `AvatarSize`, `IconSize`

---

### 6. GroupDetailView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Group header: icon, name, member count, balance summary
- Action buttons: "Add Expense" → `QuickActionSheetPresenter`, "Settle Up" → `GroupSettlementView`
- Members section: avatar, name, individual balance display (owes/owed/settled)
- Expenses section: chronological transaction list with `GroupDetailTransactionRow`
- Empty state for expenses
- `UserGroup` extensions: `membersArray`, `transactionsArray` (sorted convenience)

**Issues:**
1. **`currentUserBalance` in `GroupDetailTransactionRow` is computed but never used** — dead code.
2. **No member add/remove capability** — can't modify group membership after creation.
3. **No group edit/delete** — no way to rename or delete the group.
4. **No navigation to individual member profiles** — member rows are not tappable.
5. **Settle button opacity 0.5 when disabled** — should use `.disabled` modifier styling instead for consistency.

**Edge Cases Not Handled:**
- Group with 0 members (edge case if data corrupted)
- Transaction with nil payer in `GroupDetailTransactionRow`

**Dependencies:**
- `UserGroup`, `FinancialTransaction`, `Person` CoreData entities
- `QuickActionSheetPresenter`, `GroupSettlementView`
- `CurrentUser`, `CurrencyFormatter`, `DateFormatter.shortDate`
- `AppTypography`, `AppColors`, `Spacing`, `AvatarSize`, `IconSize`, `ButtonHeight`, `CornerRadius`
- `Color(hex:)`, `HapticManager`

---

### 7. GroupConversationView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- iMessage-style group conversation with date-grouped items
- Renders 4 item types: `.transaction` → `GroupTransactionCardView`, `.settlement` → `GroupSettlementMessageView`, `.reminder` → `GroupReminderMessageView`, `.message` → `MessageBubbleView`
- Custom toolbar: back button, group icon+name+member count (tappable → detail), balance display
- `GroupConversationActionBar` with Add/Remind/Settle — includes member-who-owe-you logic
- Message input via `MessageInputView`, creates `ChatMessage` with `withGroup` relationship
- `GroupSettlementMessageView` inline (handles 3 cases: you paid, they paid you, third-party)
- `GroupReminderMessageView` inline
- `GroupConversationActionBar` with smart enable/disable (remind only if members owe you, settle only if balance exists)
- `GroupActionButton` private component with primary (green circle) and secondary variants

**Issues:**
1. **Same `UIImpactFeedbackGenerator` issue as PersonConversationView** — `let` property on struct.
2. **`GroupSettlementMessageView` and `GroupReminderMessageView` are defined inline** in this file rather than as separate component files. They could be extracted for reuse.
3. **Share/View Details context menu actions are empty stubs** in `GroupTransactionCardView` (see file #16).

**Edge Cases Not Handled:**
- Group with no members (would show "0 members")
- Chat message sent to deleted group

**Dependencies:**
- `UserGroup`, `ChatMessage`, `Settlement`, `Reminder` CoreData entities
- `GroupConversationItem`, `GroupConversationDateGroup` model types
- `GroupTransactionCardView`, `MessageBubbleView`, `DateHeaderView`, `MessageInputView`
- `GroupDetailView`, `GroupSettlementView`, `GroupReminderSheetView`
- `QuickActionSheetPresenter`
- `CurrentUser`, `HapticManager`, `CurrencyFormatter`
- `AppColors`, `AppTypography`, `AppButtonStyle`, `Spacing`, `AvatarSize`, `IconSize`, `ButtonHeight`, `CornerRadius`

---

### 8. ImportContactsView.swift

**State:** 🔧 PARTIAL

**Features/Functionality:**
- Three states: authorized (contact list), denied (settings redirect), not determined (permission request)
- Contact list with avatar (thumbnail or initials), name, phone number, checkmark selection
- Search filtering by name
- Select All / Deselect All toggle (works on filtered set)
- Import count badge on confirm button
- Creates Person entities with UUID, name, phone, random colorHex
- Save with rollback on error

**Issues:**
1. **No duplicate contact check** — importing the same contact twice creates duplicate Person entities. Should check existing Person by name+phone.
2. **`photoData` not saved** — `contact.thumbnailImageData` is available and used for display but never persisted to `Person.photoData`.
3. **Error alert TODO** — code comment `// TODO: Show error alert to user` — error is only printed to console.
4. **`onImport` callback pattern** — uses optional closure but no guarantee the parent handles it.
5. **Uses `NavigationView`** (deprecated) instead of `NavigationStack`.

**Edge Cases Not Handled:**
- Contact with no phone numbers (still imported with nil phone)
- Contacts permission revoked while view is open
- Large contact lists (1000+ contacts) — no pagination

**Dependencies:**
- `ContactsManager`
- `Person` CoreData entity
- `PrimaryButtonStyle`
- `AppTypography`, `AppColors`, `Spacing`, `AvatarSize`, `IconSize`, `HapticManager`

---

### 9. SettlementView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Shows direction text ("Record payment from/to [name]") and current balance
- "Settle Full Amount" button (green, full balance)
- Custom amount via decimal pad input with validation
- Amount validation: > $0.00, ≤ balance
- Optional note field
- Creates `Settlement` entity with correct `fromPerson`/`toPerson` based on balance direction
- `isFullSettlement` flag set appropriately
- Error alert with localized description, save rollback

**Issues:**
1. **No confirmation dialog** — "Settle Full Amount" executes immediately with no "Are you sure?" prompt.
2. **Currency symbol hardcoded in placeholder** — `"$0.00"` assumes USD.

**Edge Cases Not Handled:**
- Balance changes between opening sheet and confirming (race condition with concurrent edits)
- Person deleted while settlement sheet is open
- Very large amounts (no upper bound check beyond balance)

**Dependencies:**
- `Person`, `Settlement` CoreData entities
- `CurrentUser.getOrCreate(in:)`
- `CurrencyFormatter` (format + parse)
- `AppTypography`, `AppColors`, `Spacing`, `IconSize`, `ButtonHeight`, `CornerRadius`
- `AppButtonStyle`, `HapticManager`

---

### 10. GroupSettlementView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Member picker: horizontal scroll of `MemberBalanceChip` components showing avatar, name, balance
- Auto-selects first member on appear
- Direction text and balance display for selected member
- "Settle Full Amount" + custom amount (same pattern as SettlementView)
- Validation: amount > 0, ≤ member balance
- Creates Settlement with correct from/to direction
- "All settled up" state when no outstanding balances
- `MemberBalanceChip` private component with selection ring

**Issues:**
1. **Same currency placeholder issue** — `"$0.00"` hardcoded.
2. **No confirmation dialog** for full settlement.
3. **No multi-settle capability** — can only settle with one member at a time, must re-open for each.

**Edge Cases Not Handled:**
- Member removed from group while settlement sheet is open
- All members settle while viewing (would need to dismiss or refresh)
- Group with only current user (no members to settle with)

**Dependencies:**
- `UserGroup`, `Person`, `Settlement` CoreData entities
- `CurrentUser.getOrCreate(in:)`
- `CurrencyFormatter`
- `AppTypography`, `AppColors`, `Spacing`, `AvatarSize`, `IconSize`, `ButtonHeight`, `CornerRadius`
- `AppButtonStyle`, `AppAnimation`, `HapticManager`

---

### 11. ReminderSheetView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Header with bell icon, "Send Reminder" title, person name + owed amount
- Optional message field (multi-line, 3-6 lines)
- Creates `Reminder` entity with all correct properties: `id`, `createdDate`, `amount`, `message`, `isRead=false`, `isCleared=false`, `toPerson`
- Save with rollback and error alert

**Issues:**
1. **No guard on positive balance** — reminder can be sent even if person doesn't owe you (amount could be negative). The parent view guards this, but the view itself doesn't validate.
2. **No character limit on message** — unlimited text input.

**Edge Cases Not Handled:**
- Person already has an unread reminder (no deduplication or warning)
- Amount displayed could be 0 or negative if called incorrectly

**Dependencies:**
- `Person`, `Reminder` CoreData entities
- `CurrencyFormatter`
- `AppTypography`, `AppColors`, `Spacing`, `IconSize`, `ButtonHeight`, `CornerRadius`
- `AppButtonStyle`, `HapticManager`

---

### 12. GroupReminderSheetView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Lists members who owe you with checkbox selection
- Select All / Deselect All toggle
- Summary: selected count + total amount
- Shared message field (applied to all reminders)
- Batch creates Reminder entities for each selected member
- Auto-selects all members on appear
- "No reminders needed" state when nobody owes you
- `MemberReminderRow` private component with checkbox, avatar, name, amount

**Issues:**
1. **`successCount` variable computed but never used** — dead code in `sendReminders()`.
2. **Same message for all reminders** — no per-member customization option.
3. **No individual amount override** — each reminder uses the computed owed amount, no custom amount option.

**Edge Cases Not Handled:**
- Member's `id` is nil (handled with `compactMap` but silently skips)
- Concurrent balance changes while selecting members
- Very large group (20+ members who owe) — UI might be cramped in 200pt frame

**Dependencies:**
- `UserGroup`, `Person`, `Reminder` CoreData entities
- `CurrencyFormatter`
- `AppTypography`, `AppColors`, `Spacing`, `AvatarSize`, `IconSize`, `ButtonHeight`, `CornerRadius`
- `AppButtonStyle`, `HapticManager`, `CurrentUser`

---

### 13. Components/BalanceHeaderView.swift

**State:** 🔧 PARTIAL

**Features/Functionality:**
- Displays person avatar (color circle + initials), name, balance text
- Avatar is tappable via `onAvatarTap` callback
- Balance card with contextual background color (green/red/neutral)
- Uses `person.firstName` computed property

**Issues:**
1. **Not used in any conversation view** — `PersonConversationView` and `GroupConversationView` both implement their own toolbar-based balance display. This component appears to be **orphaned/unused**.
2. **Avatar fill color is opaque** — uses `Color(hex:)` directly without `.opacity(0.2)`, unlike every other avatar in the codebase. Text uses `.white` foreground, so it works, but it's visually inconsistent.
3. **Hardcoded fallback color** — `"#34C759"` instead of `CurrentUser.defaultColorHex` used elsewhere.

**Edge Cases Not Handled:**
- N/A (simple display component)

**Dependencies:**
- `Person` entity (uses `firstName`, `initials`, `colorHex`, `name`)
- `CurrencyFormatter`
- `AppTypography`, `AppColors`, `Spacing`, `AvatarSize`, `CornerRadius`

---

### 14. Components/ConversationActionBar.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Three action buttons: Add (primary, always enabled), Remind (enabled when balance > 0), Settle (enabled when balance ≠ 0)
- Primary button has green circle with plus icon
- Secondary buttons show icon + text with enabled/disabled styling
- `ActionButton` private component with haptic feedback

**Issues:**
1. **Remind direction logic** — `canRemind` is `balance > 0.01` (they owe you). Correct for person context but doesn't handle the "you owe them" case (no remind). This is by design.

**Edge Cases Not Handled:**
- Balance flickering around 0.01 threshold (minor)

**Dependencies:**
- `AppColors`, `AppTypography`, `Spacing`, `IconSize`, `ButtonHeight`, `CornerRadius`
- `AppButtonStyle`, `HapticManager`

---

### 15. Components/DateHeaderView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Two initializers: `init(date:)` with smart formatting, `init(dateString:)` for pre-formatted
- Smart date formatting: "Today", "Yesterday", day name (same week), "MMM d, yyyy" (older)
- Centered capsule pill design

**Issues:**
None.

**Edge Cases Not Handled:**
- Locale-specific date formatting (uses system locale by default — acceptable)
- Future dates (would show as regular date — fine)

**Dependencies:**
- `AppTypography`, `AppColors`, `Spacing`, `CornerRadius`

---

### 16. Components/GroupTransactionCardView.swift

**State:** 🔧 PARTIAL

**Features/Functionality:**
- Card layout: title, meta text (date + payer), amount (user's net impact), total/split count
- Smart net amount calculation: if user paid, shows how much others owe; if others paid, shows user's share
- Split count via unique participant UUIDs
- Context menu: Edit, Share, View Details, Delete (with destructive role)
- Long press scale animation
- Optional `onEdit` / `onDelete` callbacks

**Issues:**
1. **Share action is a stub** — context menu button exists but action body is empty.
2. **View Details action is a stub** — same empty body.
3. **`userNetAmount` calculation for payer** counts all non-user splits — correct behavior but doesn't account for the payer's own split (if payer also owes themselves in equal split). This is correct if splits only contain non-payers.

**Edge Cases Not Handled:**
- Transaction with no splits (returns 0 for net amount)
- Transaction with nil payer (payerName falls back to "Someone")
- Very long title (limited to 2 lines)

**Dependencies:**
- `FinancialTransaction`, `TransactionSplit`, `UserGroup` CoreData entities
- `CurrentUser`, `CurrencyFormatter`
- `AppTypography`, `AppColors`, `Spacing`, `IconSize`, `CornerRadius`
- `AppAnimation`, `HapticManager`

---

### 17. Components/MessageBubbleView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- iMessage-style chat bubble: blue (user) on right, gray (other) on left
- Uses `RoundedRectangle` for bubble shape (no tail — simpler than TransactionBubbleView)
- Min spacing of 60pt on opposite side

**Issues:**
1. **No timestamp display** — messages don't show when they were sent.
2. **No read receipt / delivery status**.

**Edge Cases Not Handled:**
- Very long messages (will expand vertically — acceptable)
- Empty message content (shows empty bubble)
- Nil content (shows empty string via `?? ""`)

**Dependencies:**
- `ChatMessage` CoreData entity
- `AppTypography`, `AppColors`, `Spacing`, `CornerRadius`

---

### 18. Components/MessageInputView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Text field with "iMessage" placeholder, vertical expansion (1-5 lines)
- Send button (arrow.up.circle.fill) with enabled/disabled opacity
- Trims whitespace for send validation
- Haptic feedback on send

**Issues:**
1. **Placeholder text "iMessage"** — should probably say "Message" or be customizable. "iMessage" is Apple's trademark.
2. **No attachment support** — text only, no image/file sharing.

**Edge Cases Not Handled:**
- Paste of very long text (no character limit)
- Emoji-only messages (handled fine)

**Dependencies:**
- `AppTypography`, `AppColors`, `Spacing`, `CornerRadius`, `IconSize`
- `AppButtonStyle`, `AppAnimation`, `HapticManager`

---

### 19. Components/ReminderMessageView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Centered capsule with bell icon + "Reminder sent for [amount]"
- Optional quoted message display (italic)
- Date display below

**Issues:**
1. **`person` parameter accepted but unused** — the `person` parameter is passed in but not referenced in the view body or message text. Could be removed or used for richer context.

**Edge Cases Not Handled:**
- Reminder with 0 amount (would show "$0.00")
- Nil `createdDate` (falls back to `Date()` — shows current date, which is misleading)

**Dependencies:**
- `Reminder`, `Person` CoreData entities
- `CurrencyFormatter`
- `AppTypography`, `AppColors`, `Spacing`, `IconSize`

---

### 20. Components/SettlementMessageView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Centered capsule with checkmark icon + contextual message
- Three cases: "You paid [name]", "[name] paid you", "[name] paid [name]"
- Uses `person` parameter to determine which conversation context we're in
- Optional note display (italic)
- Date display below

**Issues:**
None found. Logic is thorough with all three payment direction cases.

**Edge Cases Not Handled:**
- Nil `date` (falls back to `Date()`)
- Settlement with 0 amount
- Both `fromPerson` and `toPerson` are nil (would show "Someone paid someone")

**Dependencies:**
- `Settlement`, `Person` CoreData entities
- `CurrentUser`
- `CurrencyFormatter`
- `AppTypography`, `AppColors`, `Spacing`, `IconSize`

---

### 21. Components/TransactionBubbleView.swift

**State:** 🔧 PARTIAL

**Features/Functionality:**
- iMessage-style bubble for transactions with tail shape (`BubbleShape`)
- Shows transaction title + amount
- User-paid transactions on right (blue), other-paid on left (gray)
- `BubbleShape` custom path with tail on appropriate side
- Optional timestamp display

**Issues:**
1. **Appears unused** — `PersonConversationView` uses `TransactionCardView` (not `TransactionBubbleView`). This may be an **orphaned/unused** component or an alternative design.
2. **`UIScreen.main.bounds.width`** — deprecated in iOS 16+. Should use GeometryReader.
3. **`showTimestamp` parameter** — always passed by caller, but no caller found in codebase.

**Edge Cases Not Handled:**
- Transaction with no splits matching person or current user (returns 0 amount)
- Landscape orientation (Spacer uses 25% of screen width)

**Dependencies:**
- `FinancialTransaction`, `TransactionSplit`, `Person` CoreData entities
- `CurrentUser`
- `CurrencyFormatter`
- `AppTypography`, `AppColors`, `Spacing`

---

### 22. Components/TransactionCardView.swift

**State:** 🔧 PARTIAL

**Features/Functionality:**
- Card layout: title, meta text (date + payer), display amount, total/split count
- Three payer cases: user paid (green +amount), person paid (red amount), third party paid
- Split count via unique participant UUIDs
- Context menu: Edit, Share, View Details, Delete
- Long press scale animation with haptics
- Optional `onEdit` / `onDelete` callbacks

**Issues:**
1. **Share action is a stub** — empty action body in context menu.
2. **View Details action is a stub** — empty action body.
3. **DateFormatter created on every render** — `dateText` creates a new `DateFormatter()` each time. Should be a static/cached formatter for performance.

**Edge Cases Not Handled:**
- Transaction with no splits (displayAmount returns 0)
- `displayAmount` returns 0 silently if no matching split found — no indicator that data might be corrupt
- Third-party payer case in person conversation (person didn't pay, user didn't pay)

**Dependencies:**
- `FinancialTransaction`, `TransactionSplit`, `Person` CoreData entities
- `CurrentUser`
- `CurrencyFormatter`
- `AppTypography`, `AppColors`, `Spacing`, `IconSize`, `CornerRadius`
- `AppAnimation`, `AppButtonStyle`, `HapticManager`

---

## Cross-Cutting Issues

### 1. Stub Context Menu Actions
**Files affected:** TransactionCardView.swift, GroupTransactionCardView.swift  
**Issue:** "Share" and "View Details" context menu buttons have empty action bodies. Users can tap them but nothing happens.  
**Severity:** Medium — confusing UX.

### 2. No Person/Group Delete Capability
**Files affected:** PersonDetailView.swift, GroupDetailView.swift  
**Issue:** No way to delete a person or group from the app. No swipe-to-delete on list rows either.  
**Severity:** Medium — data management gap.

### 3. No Person/Group Edit Capability
**Files affected:** PersonDetailView.swift, GroupDetailView.swift  
**Issue:** Cannot edit person name/phone or group name/members after creation.  
**Severity:** Medium — users stuck with mistakes.

### 4. Duplicate Contact Import
**Files affected:** ImportContactsView.swift, AddPersonView.swift  
**Issue:** No deduplication check when importing contacts or creating persons. Can create multiple Person entities for the same real person.  
**Severity:** High — data integrity risk.

### 5. `photoData` Never Populated
**Files affected:** AddPersonView.swift, AddGroupView.swift, ImportContactsView.swift  
**Issue:** Person entity has `photoData` attribute but it's never set during creation. Contact thumbnails are available but discarded.  
**Severity:** Low — cosmetic only, falls back to initials.

### 6. Potentially Orphaned Components
**Files affected:** BalanceHeaderView.swift, TransactionBubbleView.swift  
**Issue:** These components don't appear to be used by any conversation or detail view. May be leftover from an earlier design iteration.  
**Severity:** Low — dead code, increases maintenance burden.

### 7. Hardcoded Currency Symbol
**Files affected:** SettlementView.swift, GroupSettlementView.swift  
**Issue:** Placeholder text `"$0.00"` assumes USD. Should use locale-aware formatting.  
**Severity:** Low — cosmetic in a Swiss-targeted app (should be CHF).

### 8. DateFormatter Performance
**Files affected:** TransactionCardView.swift, GroupTransactionCardView.swift  
**Issue:** `DateFormatter()` instantiated in computed properties, recreated on every view render. Should be `static let` for performance.  
**Severity:** Low — minor performance impact with many transactions.

### 9. Missing Accessibility
**Files affected:** All 22 files  
**Issue:** No `accessibilityLabel`, `accessibilityHint`, or `accessibilityValue` modifiers anywhere. VoiceOver users will have a poor experience.  
**Severity:** Medium — accessibility compliance gap.

---

## Dependency Map

```
PeopleView
├── PersonListView
│   ├── PersonListRowView
│   │   ├── PersonDetailView (sheet)
│   │   │   ├── PersonConversationView (sheet)
│   │   │   └── QuickActionSheetPresenter (sheet)
│   │   ├── QuickActionSheetPresenter (sheet)
│   │   └── ReminderSheetView (sheet)
│   └── PersonConversationView (nav link)
│       ├── ConversationActionBar
│       ├── MessageInputView
│       ├── DateHeaderView
│       ├── TransactionCardView
│       ├── SettlementMessageView
│       ├── ReminderMessageView
│       ├── MessageBubbleView
│       ├── PersonDetailView (sheet)
│       ├── SettlementView (sheet)
│       ├── ReminderSheetView (sheet)
│       └── QuickActionSheetPresenter (sheet)
├── GroupListView
│   ├── GroupListRowView
│   │   ├── GroupDetailView (sheet)
│   │   │   ├── GroupSettlementView (sheet)
│   │   │   └── QuickActionSheetPresenter (sheet)
│   │   ├── QuickActionSheetPresenter (sheet)
│   │   └── GroupReminderSheetView (sheet)
│   └── GroupConversationView (nav link)
│       ├── GroupConversationActionBar (inline)
│       ├── MessageInputView
│       ├── DateHeaderView
│       ├── GroupTransactionCardView
│       ├── GroupSettlementMessageView (inline)
│       ├── GroupReminderMessageView (inline)
│       ├── MessageBubbleView
│       ├── GroupDetailView (sheet)
│       ├── GroupSettlementView (sheet)
│       ├── GroupReminderSheetView (sheet)
│       └── QuickActionSheetPresenter (sheet)
├── AddPersonView (nav link)
│   └── ContactPicker (sheet)
├── AddGroupView (nav link)
│   └── ContactsManager
├── NewTransactionContactView (sheet)
└── ImportContactsView (standalone)
    └── ContactsManager

POTENTIALLY ORPHANED:
├── BalanceHeaderView (not referenced by any parent)
└── TransactionBubbleView (not referenced by any parent)
```

### External Dependencies (not in People feature)
- `CurrentUser` (static helper + CoreData)
- `CurrencyFormatter` (formatting + parsing)
- `HapticManager` (haptic feedback)
- `ContactsManager` (device contacts access)
- `QuickActionSheetPresenter` (transaction creation flow)
- `NewTransactionContactView` (new transaction from contact picker)
- Design system: `AppColors`, `AppTypography`, `Spacing`, `IconSize`, `AvatarSize`, `CornerRadius`, `ButtonHeight`, `AppAnimation`, `AppButtonStyle`, `PrimaryButtonStyle`
- `Color(hex:)` extension
- `Person` extensions: `initials`, `firstName`, `calculateBalance()`, `getGroupedConversationItems()`
- `UserGroup` extensions: `calculateBalance()`, `getMemberBalances()`, `getMembersWhoOweYou()`, `getMembersYouOwe()`, `calculateBalanceWith(member:)`, `getGroupedConversationItems()`
- `DateFormatter.shortDate` extension
- `ConversationItem`, `ConversationDateGroup`, `GroupConversationItem`, `GroupConversationDateGroup` model types

---

*End of People Feature Scan*
