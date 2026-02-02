# Feature Registry: Transactions + QuickAction Modules

**Audit Date:** 2026-02-02  
**Auditor:** Subagent scan-transactions  
**Project:** Swiss Coin iOS App  
**Scope:** 15 files across `Features/Transactions/` (7 files) and `Features/QuickAction/` (8 files)

---

## CoreData Property Reference (Ground Truth)

| Entity | Properties |
|---|---|
| **FinancialTransaction** | `id`, `payer` (not paidBy), `date` (not createdAt), `splits`, `title`, `amount`, `splitMethod`, `group` |
| **TransactionSplit** | `owedBy` (not person), `amount`, `rawAmount`, `transaction` — **NO `id` attribute** |
| **Person** | `id`, `name`, `phoneNumber`, `photoData`, `colorHex` |

---

## Module 1: Transactions (7 files)

---

### 1. AddTransactionView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Full transaction creation form with NavigationView + Form layout
- Title, total amount (decimal pad), date picker inputs
- `PayerPicker` sub-view: fetches all Person entities, filters out current user, nil = "Me"
- Participant selection via NavigationLink → `ParticipantSelectorView`
- Horizontal scroll preview of selected participants (pill badges)
- Split method picker (segmented, icon-based) using `SplitMethod.allCases`
- Per-participant `SplitInputView` rows when participants selected
- Real-time validation feedback section (total distributed vs expected, green/red coloring)
- Validation error message display
- Save button with `PrimaryButtonStyle`, disabled when invalid
- Cancel toolbar button dismisses sheet
- `onAppear`: pre-populates `initialParticipant` and `initialGroup` (loads group members)

**Issues Found:**
1. **Hardcoded `PersistenceController.shared`** in init — bypasses `@Environment(\.managedObjectContext)`. The comment acknowledges this as a workaround. If a different context is used elsewhere, data could write to the wrong store.
2. **`person.id ?? UUID()` fallback pattern** — the `ForEach(Array(viewModel.selectedParticipants), id: \.self)` uses `\.self` which relies on `Hashable` conformance of `Person` (NSManagedObject). This is technically fine but fragile if object identity changes across fetches.
3. **No error alert** — if `saveTransaction` fails, the view simply doesn't dismiss. No user-facing error message is shown in the UI (the viewModel's `validationMessage` only covers pre-save validation, not CoreData save errors).
4. **`$` hardcoded** in validation display — `String(format: "$%.2f", calculated)` doesn't respect user currency. Should use `CurrencyFormatter`.
5. **`presentationMode` is deprecated** — should use `@Environment(\.dismiss)` on iOS 15+.

**Edge Cases Not Handled:**
- User taps Save while keyboard is open (no explicit keyboard dismissal)
- Extremely large amounts (overflow potential in Double)
- User changes split method after entering values (raw inputs persist from previous method)
- Empty group (group with 0 members) pre-population

**Dependencies:**
- `TransactionViewModel`, `ParticipantSelectorView`, `SplitInputView`, `PayerPicker`
- `PersistenceController.shared`, `CurrentUser`, `SplitMethod`
- `AppTypography`, `AppColors`, `PrimaryButtonStyle`, `CurrencyFormatter`
- CoreData: `Person`, `UserGroup`, `FinancialTransaction`

---

### 2. NewTransactionContactView.swift

**State:** 🔧 PARTIAL

**Features/Functionality:**
- Contact picker screen styled after WhatsApp's "New Message" flow
- Links to `AddGroupView` and `AddPersonView` at top
- Device contacts integration via `ContactsManager` (async fetch)
- Contact search/filter (case-insensitive name matching)
- Three authorization states: authorized (show list), denied (settings link), not-determined (request prompt)
- Contact thumbnails with initials fallback
- On contact selection: checks CoreData for existing Person (by phone → by name), creates new if needed
- New Person creation includes: UUID, name, phone, random `colorHex` from hardcoded palette
- Navigation to `PersonDetailView` on selection (not `AddTransactionView` — seems intentional for chat-like flow)

**Issues Found:**
1. **Navigation destination mismatch** — the variable is named `selectedPersonForTransaction` and `navigateToAddTransaction`, but it navigates to `PersonDetailView`, not a transaction creation view. This is either intentional (view the person first) or a naming bug.
2. **Phone number matching is fragile** — uses exact string match (`phoneNumber == %@`). Different formats ("+1 555-1234" vs "5551234") will create duplicates.
3. **Name-only fallback matching** — if no phone number, matches by name. Multiple "John Smith" contacts would alias to the first match.
4. **No `photoData` saved** — contact's `thumbnailImageData` is available but not persisted to `Person.photoData`.
5. **Error handling is `print()` only** — no user-facing error on save failure.
6. **`presentationMode` deprecated** — should use `@Environment(\.dismiss)`.
7. **Hardcoded color palette** — 8 colors, no connection to a design system constant.

**Edge Cases Not Handled:**
- Contacts with no name (empty `fullName`)
- Multiple phone numbers per contact (only `first` is used)
- Contact permission revoked after initial grant
- Thread safety of CoreData operations in button handler (runs on main thread, should be fine but not explicit)

**Dependencies:**
- `ContactsManager` (custom manager, not audited here)
- `AddGroupView`, `AddPersonView`, `PersonDetailView`
- `AppTypography`, `AppColors`, `AvatarSize`, `IconSize`, `Spacing`
- `HapticManager`
- CoreData: `Person`

---

### 3. ParticipantSelectorView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Two-mode participant selection: People (individual) and Groups (bulk add)
- Segmented picker to switch between People/Groups tabs
- People tab: toggleable list with checkmark indicators, "Me" label for current user
- Groups tab: shows group name, member count, "+" icon to add all members
- Import contacts toolbar button → `ImportContactsView` sheet
- Group toggle adds all members (union), no toggle-off for groups

**Issues Found:**
1. **Group toggle is add-only** — tapping a group always inserts members, never removes them. There's no visual indicator that a group's members are already selected, and no way to bulk-remove a group.
2. **No search/filter** — for users with many contacts, the flat list is unscalable.
3. **`group.members as? Set<Person>` cast** — if the relationship is ordered (NSOrderedSet), this cast fails silently and returns nil, adding zero members.

**Edge Cases Not Handled:**
- Empty groups (0 members) — button is still shown but does nothing
- Person deleted while selected (stale reference in `Set<Person>`)
- Very large contact lists (no pagination/lazy loading beyond SwiftUI's built-in List virtualization)

**Dependencies:**
- `ImportContactsView` (not audited here)
- `CurrentUser`, `HapticManager`
- `AppTypography`, `AppColors`, `AvatarSize`, `IconSize`, `Spacing`
- CoreData: `Person`, `UserGroup`

---

### 4. SplitInputView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Dynamic per-person input row that adapts to the selected `SplitMethod`
- **Equal**: read-only calculated amount via `CurrencyFormatter`
- **Percentage**: text field with "%" suffix, decimal pad
- **Exact**: text field with "$" prefix, decimal pad
- **Adjustment**: text field with "+/- $" prefix, numbers+punctuation keyboard
- **Shares**: `Stepper` control (1–100 range), with pluralized label
- `onAppear` initializes default values per method (equal split of percentage, even dollar amount, "0" adjustment, "1" share)

**Issues Found:**
1. **`person.id ?? UUID()`** — if `person.id` is nil (shouldn't happen but defensive), a random UUID is generated each render, causing the input to never bind correctly. The value would be lost every re-render.
2. **"$" hardcoded** — exact split shows "$" prefix instead of using the user's currency.
3. **No input sanitization** — user can type "abc" into percentage/exact fields; `Double()` parsing returns nil → defaults to 0, but the text field still shows garbage.
4. **Default percentage calculation uses integer division** — `100 / viewModel.selectedParticipants.count` truncates. For 3 participants: 33, not 33.33. Total would be 99%, triggering validation error.
5. **Adjustment keyboard** — `.numbersAndPunctuation` allows letters on some locales. `.decimalPad` with negative sign would be better but iOS doesn't have one natively.

**Edge Cases Not Handled:**
- Split method changes while inputs are populated (stale `rawInputs` from previous method)
- Participant added/removed after inputs already set (no recalculation trigger)
- Locale-dependent decimal separators ("," vs ".")

**Dependencies:**
- `TransactionViewModel` (observed)
- `CurrencyFormatter`
- `AppTypography`, `AppColors`, `Spacing`
- CoreData: `Person` (read-only here)

---

### 5. TransactionHistoryView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Full transaction history list sorted by date descending
- `@FetchRequest` with `FinancialTransaction.date` sort descriptor — **correct property name** ✅
- Swipe-to-delete with cascade: deletes splits first, then transaction
- Error handling on delete: rollback + haptic error feedback
- Overlays `FinanceQuickActionView` (FAB) on top of the list
- Plain list style with secondary system background

**Issues Found:**
1. **No empty state** — when no transactions exist, user sees a blank list with just a FAB. Should show an onboarding/empty illustration.
2. **No confirmation on delete** — swipe-to-delete immediately removes without "Are you sure?" dialog.
3. **No search/filter** — no way to find a specific transaction by name, date, or amount.
4. **`NavigationView` not `NavigationStack`** — deprecated pattern on iOS 16+.

**Edge Cases Not Handled:**
- Large datasets (hundreds of transactions) — no pagination
- Concurrent edits (multi-device sync, if ever supported)
- Transaction with nil splits (defensive nil check is present via `as? Set<TransactionSplit>`)

**Dependencies:**
- `TransactionRowView`, `FinanceQuickActionView`
- `HapticManager`
- CoreData: `FinancialTransaction`, `TransactionSplit`

---

### 6. TransactionRowView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Rich transaction row with title, date, creator name, amount, split details
- Smart amount display: if user is payer → shows "lent to others" (green); if not → shows "what you owe" (red)
- `contextMenu` with Edit, Share, View Details, Delete actions
- Share via `UIActivityViewController` with iPad popover support
- Long-press scale animation with haptic feedback
- `CurrencyFormatter` for amount display
- Split count calculation: counts unique participants (payer + all split `owedBy` persons)

**Issues Found:**
1. **`showTransactionDetails()` is a TODO stub** — prints to console, no actual navigation.
2. **`onEdit` callback exists but never used** — no edit transaction flow is implemented anywhere.
3. **UIKit escape hatch for sharing** — `UIApplication.shared.connectedScenes` is fragile; could fail with multiple scenes (iPad multitasking).
4. **CoreData property usage is CORRECT** ✅:
   - `transaction.payer` ✅ (not paidBy)
   - `transaction.date` ✅ (not createdAt)
   - `transaction.splits` ✅
   - `transaction.title` ✅
   - `transaction.amount` ✅
   - `split.owedBy` ✅ (not person)
   - `split.amount` ✅
5. **`isPayer` computation** — `CurrentUser.isCurrentUser(transaction.payer?.id)` — relies on optional chaining; if payer is nil, returns false. Correct defensive behavior.

**Edge Cases Not Handled:**
- Transaction with 0 amount (divides display but doesn't crash)
- Transaction with no splits (returns 0 for myShare, shows $0.00)
- Very long titles (capped at 2 lines via `.lineLimit(2)`)
- Date formatting doesn't respect user locale (hardcoded "MMM d, yyyy")

**Dependencies:**
- `CurrencyFormatter`, `CurrentUser`, `HapticManager`
- `AppTypography`, `AppColors`, `AppAnimation`, `Spacing`, `IconSize`
- CoreData: `FinancialTransaction`, `TransactionSplit`, `Person`

---

### 7. TransactionViewModel.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- **`SplitMethod` enum**: 5 cases — equal, percentage, exact, adjustment, shares — with `systemImage` icons
- **Published state**: title, totalAmount (String), date, selectedPayer, selectedParticipants, splitMethod, rawInputs (UUID→String map)
- **Validation** (`isValid`): checks title non-empty, amount > 0.001, participants non-empty, method-specific rules (percentage sums to 100, exact sums to total, adjustment ≤ total, shares > 0)
- **`validationMessage`**: user-facing string explaining what's wrong
- **`calculateSplit(for:)`**: penny-perfect splitting with deterministic remainder distribution (sorted by name, first N people get +1¢)
- **`saveTransaction()`**: creates `FinancialTransaction` + `TransactionSplit` entities, sets payer, group, saves with rollback on error
- **`resetForm()`**: clears all state
- **CoreData property usage is CORRECT** ✅:
  - `transaction.payer = payer` ✅
  - `transaction.date = date` ✅
  - `transaction.splitMethod = splitMethod.rawValue` ✅
  - `transaction.group = group` ✅
  - `split.owedBy = person` ✅
  - `split.amount = ...` ✅
  - `split.rawAmount = rawVal` ✅
  - `split.transaction = transaction` ✅
  - No `split.id` assignment ✅ (correct — TransactionSplit has no id)

**Issues Found:**
1. **`person.id ?? UUID()` pattern throughout** — used in `rawInputs` dictionary lookups. If `person.id` is nil, a new random UUID is generated each call, making lookups always miss. This is a **silent data loss bug** in edge cases where Person.id is nil.
2. **Adjustment validation is wrong** — checks `totalAdjustments <= totalAmountDouble`, but adjustments can be negative (that's the point of "+/-"). A user with -$5 adjustment on one person should be valid. The validation should check that the *calculated* per-person amounts are all non-negative, not that raw adjustments sum ≤ total.
3. **Shares calculation rounding** — uses `Int(round(...))` which can cause off-by-one cent errors when shares don't divide evenly. Unlike the `equal` method which has explicit remainder distribution, `shares` doesn't.
4. **No `@Published` on `selectedGroup`** — declared as plain `var`, so SwiftUI won't react to changes.
5. **Completion handler pattern** — `saveTransaction(completion:)` is synchronous but uses a callback pattern, which is misleading. A `throws` or `Result` return would be cleaner.
6. **`SplitMethod` defined in ViewModel file** — should be in its own Models file for reuse. (QuickAction has its own `QuickActionSplitMethod` — duplication.)
7. **Amount stored as String** — `totalAmount` is String, parsed to Double via `totalAmountDouble`. Locale-dependent; "1,5" in German locale would parse as nil.

**Edge Cases Not Handled:**
- Concurrent saves (no locking)
- Person removed from participants after rawInputs set (stale entries in rawInputs dictionary)
- Split method changed mid-entry (rawInputs from previous method still present, may affect validation)
- Transaction with 1 participant (valid but semantically odd for a "split")

**Dependencies:**
- `CurrentUser`, `HapticManager`, `CurrencyFormatter`
- `PersistenceController` (indirect, context injected)
- CoreData: `FinancialTransaction`, `TransactionSplit`, `Person`, `UserGroup`

---

## Module 2: QuickAction (8 files)

---

### 8. QuickActionSheet.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- 3-step wizard container with step indicator dots
- Dynamic navigation title per step ("New Transaction" / "Split Options" / "Split Details")
- Cancel button dismisses via `viewModel.closeSheet()`
- Done button appears on step 3, OR step 2 if `!isSplit` (personal transaction shortcut)
- ScrollView for step content with consistent padding
- Uses `NavigationView` (comment notes `NavigationStack` was considered)

**Issues Found:**
1. **Done button on step 2 doesn't validate** — calls `viewModel.saveTransaction()` directly without checking `canSubmit`. The Step2 view's own Save button does validate, but the toolbar Done button bypasses it.
2. **No back gesture** — there's no swipe-back or hardware back button support between steps (the wizard is custom, not using NavigationLink).
3. **`NavigationView` deprecated** — should use `NavigationStack` for iOS 16+.

**Edge Cases Not Handled:**
- Step 4+ (default case returns `EmptyView` — safe but silent)
- Sheet dismissal while save is in progress (no loading state)

**Dependencies:**
- `QuickActionViewModel`, `Step1BasicDetailsView`, `Step2SplitConfigView`, `Step3SplitMethodView`
- `AppColors`, `Spacing`, `HapticManager`

---

### 9. FinanceQuickActionView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Entry point overlay: positions a FAB in bottom-right corner
- `@StateObject` for `QuickActionViewModel`
- Sheet presentation bound to `viewModel.isSheetPresented`
- Passes `managedObjectContext` into the sheet
- `onAppear` calls `viewModel.setup(context:)` to inject the environment's context

**Issues Found:**
1. **`QuickActionViewModel()` default init uses `PersistenceController.shared`** — the `setup(context:)` call in `onAppear` re-assigns it, but there's a window where the ViewModel has the shared context, not the environment one. If any action fires before `onAppear`, it uses the wrong context.
2. **No loading/error state** — if the sheet fails to present or save fails, no UI feedback at this level.
3. **Commented-out `.presentationCornerRadius(14)`** — minor, cosmetic.

**Edge Cases Not Handled:**
- FAB overlapping content (no safe area consideration for tab bars)
- Multiple rapid taps on FAB (could open multiple sheets — mitigated by SwiftUI's sheet binding)

**Dependencies:**
- `QuickActionViewModel`, `QuickActionSheet`, `FloatingActionButton`
- `PersistenceController`, `Spacing`
- CoreData context via Environment

---

### 10. QuickActionComponents.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- **`QuickActionSheetPresenter`** — wrapper for presenting QuickAction with pre-selected Person or Group (used from context menus)
- **`FloatingActionButton`** — 60×60 accent circle with "+" icon and shadow
- **`SectionHeader`** — uppercase, tracked section label
- **`SearchBarView`** — magnifying glass + text field + clear button, with `onFocus` callback
- **`PersonAvatar`** — circular avatar with initials or person icon, selected state coloring
- **`ContactSearchRow`** — person row with avatar + name + checkmark
- **`GroupSearchRow`** — group row with emoji icon + name + checkmark
- **`SelectedGroupBadge`** — pill badge with group name + dismiss button
- **`CurrencyPickerView`** — vertical list of currencies with flags, checkmark for selected
- **`CategoryPickerView`** — 4-column grid of category icons with selection border
- **`SplitMethodChip`** — selectable chip with icon + label for split methods
- **`SplitOptionRow`** — radio-button-style row for Personal/Split toggle

**Issues Found:**
1. **`QuickActionSheetPresenter` duplicates `QuickActionSheet`** — the body manually recreates the same step indicator + step content + toolbar structure instead of reusing `QuickActionSheet`. This is a **DRY violation** and a maintenance hazard (changes to one must be mirrored in the other).
2. **`QuickActionSheetPresenter` calls `dismiss()` after `saveTransaction()`** — but `saveTransaction()` also calls `closeSheet()` which sets `isSheetPresented = false`. Double-dismiss could cause issues.
3. **`ContactSearchRow` hardcodes `isCurrentUser: false`** — the comment acknowledges this limitation. If the current user's Person entity appears in the list, it won't be styled as "Me".
4. **`PersonAvatar` doesn't use `photoData`** — Person entity has `photoData` but the avatar component only shows initials/icon. Photos are never displayed.
5. **Hardcoded magic numbers** in `QuickActionSheetPresenter` — spacing values (6, 8, 12, 20, 40) instead of using the `Spacing` design tokens.
6. **`Person.initials` and `Person.displayName`** — these are computed properties presumably defined in a Person extension. Not part of the CoreData schema. If the extension is missing, this file won't compile.
7. **`GroupSearchRow` uses hardcoded emoji "👥"** and `Color.orange` — comment mentions `group.icon` and `group.color` but those properties don't exist on `UserGroup`.

**Edge Cases Not Handled:**
- Very long person/group names (no `.lineLimit`)
- Empty currency list
- Category grid with non-multiple-of-4 items (last row will have gaps — acceptable with LazyVGrid)

**Dependencies:**
- `QuickActionViewModel`, `Step1BasicDetailsView`, `Step2SplitConfigView`, `Step3SplitMethodView`
- `PersistenceController.shared`
- `AppColors`, `AppTypography`, `Spacing`, `CornerRadius`, `ButtonHeight`
- `HapticManager`
- CoreData: `Person`, `UserGroup`
- Models: `Currency`, `Category`, `QuickActionSplitMethod`

---

### 11. QuickActionModels.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- **`TransactionType`** enum: `.expense` / `.income` (raw String values)
- **`QuickActionSplitMethod`** enum: 5 cases (equal, amounts, percentages, shares, adjustment) with `displayName` and `icon` computed properties
- **`Currency`** struct: 6 currencies (USD, EUR, GBP, INR, JPY, AUD) with code, symbol, name, flag
- **`Category`** struct: 8 categories (Food, Transport, Shopping, Entertainment, Bills, Health, Travel, Other) with icon (emoji) and color
- **`SplitDetail`** struct: holds `amount`, `percentage`, `shares`, `adjustment` per participant

**Issues Found:**
1. **Duplicate split method enum** — `QuickActionSplitMethod` duplicates `SplitMethod` from `TransactionViewModel.swift`. Same 5 split types with different enum names and slightly different raw values (e.g., `"amounts"` vs `"Exact Amount"`, `"percentages"` vs `"Percentage"`). This means the same transaction could be saved with different `splitMethod` strings depending on which flow created it. **This is a data integrity bug.**
2. **`TransactionType` not persisted** — the enum exists but `FinancialTransaction` entity has no `transactionType` property. Income vs expense is never saved to CoreData.
3. **`Category` not persisted** — same issue. `selectedCategory` is collected in UI but never saved to the transaction entity.
4. **`Currency` not persisted** — `selectedCurrency` is collected but `FinancialTransaction` has no currency field. All amounts are implicitly in a single currency.
5. **CHF missing** — app is called "Swiss Coin" but Swiss Franc is not in the currency list.
6. **`SplitDetail.shares` defaults to `1`** — but `SplitDetail.amount` defaults to `0`. Inconsistent defaults could cause confusion in calculations.

**Edge Cases Not Handled:**
- Currency conversion (multi-currency splits)
- Custom categories (user-defined)

**Dependencies:**
- `SwiftUI` (for `Color` in Category)
- `CoreData` imported but not used directly

---

### 12. QuickActionViewModel.swift

**State:** 🔧 PARTIAL

**Features/Functionality:**
- Full 3-step wizard state management
- Sheet open/close with auto-reset on dismiss
- Step 1 state: transaction type, amount (String), currency, name, category
- Step 2 state: isSplit toggle, paidByPerson, participantIds (UUID set), selectedGroup, search states
- Step 3 state: splitMethod, splitDetails (UUID→SplitDetail map)
- Data fetching: loads all Person and UserGroup entities
- Participant management: toggle, add from search, select group
- Payer selection with auto-add to participants
- Split calculation engine (`calculateSplits()`) for all 5 methods
- Validation: `canProceedStep1`, `canProceedStep2`, `canSubmit`
- **`saveTransaction()`**: creates `FinancialTransaction` + splits, handles payer, error rollback
- Error state: `showingError` + `errorMessage` (but never displayed in UI!)

**Issues Found:**
1. **`showingError`/`errorMessage` never shown** — `@Published var showingError` is set on error but no view reads it. No `.alert(isPresented: $viewModel.showingError)` exists anywhere. **User gets silent failures.**
2. **`selectGroup()` has member-adding code commented out** — the method sets `selectedGroup` but the block that adds group members to `participantIds` is wrapped in `/* ... */`. Selecting a group does NOT add its members. **This is a functional bug.**
3. **Duplicate `splitMethod` raw values** — `QuickActionSplitMethod.equal.rawValue` = `"equal"` but `SplitMethod.equal.rawValue` = `"Equal"` (capitalized). Transactions saved from QuickAction flow vs AddTransaction flow will have different `splitMethod` strings. **Data inconsistency.**
4. **`currentUserUUID` computed property** — calls `CurrentUser.currentUserId ?? UUID()`. If `currentUserId` is nil, a new random UUID is generated EACH TIME the property is accessed. This would break all participant matching. Critical if `CurrentUser` isn't initialized.
5. **Non-split transaction creates a self-split** — when `isSplit == false`, a single `TransactionSplit` is created where `owedBy` = payer. This means the payer "owes themselves" the full amount, which is semantically odd and could confuse balance calculations.
6. **`calculateSplits()` equal method has no penny-perfect rounding** — uses simple `total / count` division. Unlike `TransactionViewModel.calculateSplit()` which distributes remainder cents, this implementation loses cents to floating-point truncation.
7. **Two initializers create context confusion** — `init()` uses `PersistenceController.shared` and doesn't call `fetchData()`. `init(context:)` calls `fetchData()`. The `setup(context:)` is called later from `onAppear`. Multiple init paths make the context source unpredictable.
8. **`convenience init` calls `self.init(context:)` then mutates** — this is fine in Swift but the `fetchData()` call happens before `initialPerson`/`initialGroup` is processed. If fetch is slow, there's a timing issue (unlikely with CoreData but worth noting).
9. **`TransactionType` not saved** — `saveTransaction()` never sets a `transactionType` on the entity. The expense/income selection is lost.
10. **`Category` not saved** — `selectedCategory` is never persisted.
11. **`Currency` not saved** — `selectedCurrency` is never persisted.

**Edge Cases Not Handled:**
- Amount = 0 with isSplit = false (validation passes `canSubmit` returns true since `!isSplit`)
- All participants removed (participantIds empty) — `calculateSplits()` returns empty dict, save creates transaction with no splits
- Person deleted from CoreData while referenced in `participantIds` — `getPerson(byId:)` returns nil, split creation skips with `continue`
- Rapid double-tap on Save (no debounce/loading state)
- `closeSheet()` called from `saveTransaction()` triggers `resetForm()` via `didSet` — form reset happens while save is still in the `do` block. The `isSheetPresented = false` triggers `resetForm()` synchronously, which clears state. Since the save already happened, this is functionally OK but structurally fragile.

**Dependencies:**
- `PersistenceController.shared`, `CurrentUser`
- `HapticManager`
- Models: `TransactionType`, `QuickActionSplitMethod`, `Currency`, `Category`, `SplitDetail`
- CoreData: `FinancialTransaction`, `TransactionSplit`, `Person`, `UserGroup`

---

### 13. Step1BasicDetailsView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Expense/Income segmented picker with haptic on change
- Currency selector button (flag + symbol + chevron) → toggles currency picker
- Large amount input (48pt rounded font, decimal pad, right-aligned)
- Description text field ("What's this for?")
- Category selector row → toggles category grid picker
- Continue button: validates `canProceedStep1`, disabled + dimmed when invalid
- Mutually exclusive pickers (opening currency closes category and vice versa)

**Issues Found:**
1. **`onChange(of:)` uses new iOS 17 syntax** — `{ _, _ in }` two-parameter closure. Won't compile on iOS 16. If minimum target is iOS 16, this is a **compilation error**.
2. **No input validation feedback** — Continue is disabled but there's no message telling the user what's missing (unlike AddTransactionView which has validationMessage).
3. **Amount field allows empty submission attempts** — button is disabled but no shake/highlight animation to guide user.
4. **No character limit on description** — user could enter a very long title.

**Edge Cases Not Handled:**
- Paste non-numeric content into amount field
- Very long currency symbol display
- Dynamic Type / accessibility (hardcoded font sizes like `48`)

**Dependencies:**
- `QuickActionViewModel`
- `CurrencyPickerView`, `CategoryPickerView` (from QuickActionComponents)
- `AppColors`, `AppTypography`, `Spacing`, `CornerRadius`, `ButtonHeight`, `IconSize`
- `HapticManager`
- Models: `TransactionType`, `Currency`, `Category`

---

### 14. Step2SplitConfigView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Personal/Split toggle via `SplitOptionRow` radio buttons
- **Split mode expands to show:**
  - "Paid By" section with selected payer card or search interface
  - "Split With" section with participant count, search bar, group badge, participant list
- Payer search: "You" always at top, filtered contacts below, cancel button
- Split-with search: groups section + contacts section with "No results" empty state
- Participant list: "You" at top with toggle, then up to 50 contacts with checkbox toggles
- Navigation: Back button + Continue/Save button (Save if personal, Continue if split)
- Validation: Continue disabled when `!canProceedStep2` (needs ≥2 participants for split)

**Issues Found:**
1. **50-person hard cap** — `viewModel.allPeople.prefix(50)` silently truncates the contact list. Users with 51+ contacts can't select the 51st person unless they use search. No indication that the list is truncated.
2. **`SplitWithSearchResultsView` group selection calls `selectGroup()`** — but as noted above, `selectGroup()` has the member-adding code commented out. Selecting a group from search does nothing useful.
3. **`ParticipantsListView` doesn't filter out current user from `allPeople`** — "You" is shown both as the explicit top row AND potentially in the `allPeople` list if the current user has a Person entity. This could cause duplicate display and double-counting.
4. **Hardcoded magic numbers** — many pixel values (12, 16, 24, 40, 44, 68, 72) not using design tokens.
5. **`PaidBySearchView` empty state is empty** — the `if` block for no search results has no content. No "No results" message is shown.
6. **Step2 Save button (personal mode) calls `saveTransaction()` directly** — this bypasses the toolbar Done button flow. If the sheet is presented from `QuickActionSheetPresenter`, both the toolbar Done and the in-body Save could be visible simultaneously.

**Edge Cases Not Handled:**
- Payer removed from participants after being set as payer (validation doesn't catch this)
- All participants deselected then trying to proceed
- Group with duplicate members across multiple groups (members would just be in the set, so OK)
- Very long person names truncation in the compact list layout

**Dependencies:**
- `QuickActionViewModel`
- `SplitOptionRow`, `SectionHeader`, `SearchBarView`, `PersonAvatar`, `ContactSearchRow`, `GroupSearchRow`, `SelectedGroupBadge` (all from QuickActionComponents)
- `AppColors`, `AppTypography`, `Spacing`, `CornerRadius`, `ButtonHeight`
- `HapticManager`
- CoreData: `Person`, `UserGroup`

---

### 15. Step3SplitMethodView.swift

**State:** ✅ COMPLETE

**Features/Functionality:**
- Horizontal scrolling split method chips (equal, amounts, percentages, shares, adjustment)
- Method change resets `splitDetails` to empty
- `SplitSummaryBar`: shows total amount + validation indicator (percentage total or amount total, green/red)
- Per-person `SplitPersonRow` with:
  - Avatar, name, "Paid" badge for payer
  - Calculated amount display
  - Method-specific input control (read-only % for equal, $ text field, % text field, +/- stepper, ± text field)
- `OwesSummaryView`: "X owes Y" lines for non-payer participants with amounts
- Navigation: Back + Save Transaction buttons with `canSubmit` validation
- Participants sorted: "Me" first, then alphabetical

**Issues Found:**
1. **`onChange(of:)` uses iOS 17 syntax** — `{ }` single-parameter trailing closure without `oldValue, newValue`. On iOS 17 this is fine, but mixed with the two-parameter version in Step1 suggests inconsistent minimum deployment target.
2. **`SplitPersonRow` state management is fragile** — it has local `@State` vars (`amountText`, `percentageText`, `shares`, `adjustmentText`) that are derived from `currentDetail` via `updateDerivedState()`. Changes flow: local @State → onChange → onUpdate callback → viewModel.splitDetails → recalculate. This two-way binding through callbacks can cause infinite update loops if not carefully managed.
3. **Equal split shows truncated percentage** — `"%.0f"` format rounds 33.33% to 33%. Misleading for 3-way splits.
4. **`OwesSummaryView` uses `Array(nonPayerParticipants)`** — `Set` iteration order is non-deterministic. The "owes" summary lines will appear in random order each render.
5. **No keyboard dismissal** — multiple text fields but no tap-to-dismiss or "Done" accessory.
6. **`SplitPersonRow.amountText` onChange fires on every keystroke** — parses `Double(amountText)` and calls `onUpdate`, which triggers `calculateSplits()` on the parent. Could cause performance issues with many participants.
7. **Hardcoded `specifier: "%.2f"`** — doesn't respect locale decimal separator for display.
8. **Save button in Step3 body AND toolbar Done button** — two save buttons visible simultaneously. User might be confused or accidentally double-save.

**Edge Cases Not Handled:**
- Zero participants (guard in `calculateSplits()` returns empty, rows wouldn't render)
- Negative adjustment making a person's share negative (no floor/clamp)
- Shares method with all 0 shares entered manually (guard catches totalShares == 0, falls back to equal)
- Very large number of participants overflowing the vertical scroll

**Dependencies:**
- `QuickActionViewModel`
- `SplitMethodChip`, `PersonAvatar` (from QuickActionComponents)
- `AppColors`, `AppTypography`, `Spacing`, `CornerRadius`
- Models: `QuickActionSplitMethod`, `SplitDetail`, `Currency`

---

## Cross-Module Issues

### 🔴 Critical

| # | Issue | Files Affected | Impact |
|---|---|---|---|
| 1 | **Duplicate SplitMethod enums with different raw values** | `TransactionViewModel.swift` (`SplitMethod`) vs `QuickActionModels.swift` (`QuickActionSplitMethod`) | Transactions saved from different flows have inconsistent `splitMethod` strings in CoreData (e.g., `"Equal"` vs `"equal"`). Querying/filtering by method will miss results. |
| 2 | **`selectGroup()` member-adding commented out** | `QuickActionViewModel.swift` | Selecting a group in QuickAction flow doesn't add its members. Group selection is non-functional. |
| 3 | **Error states never displayed** | `QuickActionViewModel.swift` (`showingError`) | Save failures are silent. User loses data with no feedback. |
| 4 | **`currentUserUUID` generates random UUID if CurrentUser not set** | `QuickActionViewModel.swift` | All participant matching breaks. "You" becomes a different person each property access. |

### 🟡 Important

| # | Issue | Files Affected | Impact |
|---|---|---|---|
| 5 | **TransactionType, Category, Currency not persisted** | `QuickActionModels.swift`, `QuickActionViewModel.swift` | User selects these in UI but they're lost on save. Wasted UX effort. |
| 6 | **No `photoData` usage** | `QuickActionComponents.swift`, `TransactionRowView.swift` | Person entity has `photoData` but no view displays actual photos. |
| 7 | **Two parallel transaction creation flows** | `AddTransactionView` + `TransactionViewModel` vs `QuickActionSheet` + `QuickActionViewModel` | Duplicated logic, inconsistent behavior, maintenance burden. |
| 8 | **`person.id ?? UUID()` pattern** | `SplitInputView.swift`, `TransactionViewModel.swift` | If Person.id is nil, random UUIDs cause silent data loss / lookup failures. |
| 9 | **QuickActionSheetPresenter duplicates QuickActionSheet** | `QuickActionComponents.swift` | DRY violation — two copies of the wizard container. |
| 10 | **Non-split transaction creates self-owed split** | `QuickActionViewModel.swift` | Payer "owes themselves" — skews balance calculations. |
| 11 | **iOS 17 `onChange` syntax** | `Step1BasicDetailsView.swift`, `Step3SplitMethodView.swift` | Won't compile on iOS 16 if that's the minimum target. |

### 🟢 Minor / Polish

| # | Issue | Files Affected | Impact |
|---|---|---|---|
| 12 | Hardcoded "$" in split validation display | `AddTransactionView.swift` | Wrong symbol for non-USD users |
| 13 | `presentationMode` deprecated | `AddTransactionView.swift`, `NewTransactionContactView.swift` | Warning noise; use `@Environment(\.dismiss)` |
| 14 | `NavigationView` deprecated | `TransactionHistoryView.swift`, `QuickActionSheet.swift` | Should use `NavigationStack` on iOS 16+ |
| 15 | No empty state for transaction history | `TransactionHistoryView.swift` | Poor first-run experience |
| 16 | No transaction edit flow | `TransactionRowView.swift` (onEdit is unused) | Feature gap |
| 17 | No transaction detail view | `TransactionRowView.swift` (TODO stub) | Feature gap |
| 18 | Phone number matching is exact-string | `NewTransactionContactView.swift` | Duplicate Person creation likely |
| 19 | CHF missing from currency list | `QuickActionModels.swift` | Ironic for "Swiss Coin" |
| 20 | Integer division for default percentages | `SplitInputView.swift` | 3-way split defaults to 99% total |
| 21 | Date formatting not locale-aware | `TransactionRowView.swift` | Hardcoded "MMM d, yyyy" |
| 22 | `showTransactionDetails()` is a TODO | `TransactionRowView.swift` | Dead context menu item |

---

## Dependency Graph

```
TransactionHistoryView
  ├── TransactionRowView
  │     └── CurrencyFormatter, CurrentUser, HapticManager
  └── FinanceQuickActionView
        ├── FloatingActionButton
        └── QuickActionSheet
              ├── Step1BasicDetailsView
              │     ├── CurrencyPickerView
              │     └── CategoryPickerView
              ├── Step2SplitConfigView
              │     ├── SplitOptionRow
              │     ├── SelectedPayerCard → PersonAvatar
              │     ├── PaidBySearchView → SearchBarView, ContactSearchRow
              │     ├── SplitWithSearchResultsView → GroupSearchRow, ContactSearchRow
              │     └── ParticipantsListView → PersonAvatar
              └── Step3SplitMethodView
                    ├── SplitMethodChip
                    ├── SplitSummaryBar
                    ├── SplitPersonRow → PersonAvatar
                    └── OwesSummaryView

AddTransactionView
  ├── PayerPicker
  ├── ParticipantSelectorView → ImportContactsView
  ├── SplitInputView
  └── TransactionViewModel

NewTransactionContactView
  ├── ContactsManager
  ├── AddGroupView
  ├── AddPersonView
  └── PersonDetailView

QuickActionSheetPresenter (duplicate of QuickActionSheet)
  └── (same children as QuickActionSheet)
```

---

## Summary Statistics

| Metric | Count |
|---|---|
| Files audited | 15 |
| ✅ COMPLETE | 12 |
| 🔧 PARTIAL | 2 (NewTransactionContactView, QuickActionViewModel) |
| ❌ MISSING | 0 |
| 🐛 BUGGY | 0 (bugs found in PARTIAL/COMPLETE files) |
| Critical issues | 4 |
| Important issues | 7 |
| Minor issues | 11 |
| Total issues | 22 |
| CoreData property violations | **0** ✅ (all files use correct property names) |
| TODO stubs | 1 (showTransactionDetails) |
| Deprecated API usage | 3 (presentationMode ×2, NavigationView ×2+) |
