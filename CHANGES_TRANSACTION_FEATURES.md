# Transaction Edit, Delete & Detail View Features

## Summary
Added transaction detail viewing, editing, and deletion capabilities to the Swiss Coin app. Previously, the app could only create transactions — now users can view full details, edit basic fields, and delete transactions with proper confirmation.

## Changes Made

### New Files

#### 1. `Swiss Coin/Features/Transactions/TransactionDetailView.swift`
- **Header section**: Large icon, transaction title, formatted amount (via `CurrencyFormatter.format()`), and date
- **Details section**: Payer name with avatar, split method display, participant count
- **Split Breakdown section**: Lists each split with person avatar, name, amount, and percentage of total. Colors indicate whether the current user owes or is owed
- **Group section**: Shows group name and icon if the transaction belongs to a group
- **Actions section**: Edit (opens `TransactionEditView` sheet) and Delete (shows confirmation alert)
- **Delete logic**: Deletes all associated `TransactionSplit` entities first, then the transaction itself, with `try/catch` and `context.rollback()` on failure
- Uses `@ObservedObject` for live CoreData updates, design system throughout (`AppColors`, `AppTypography`, `Spacing`, `CornerRadius`, `AvatarSize`)
- HapticManager feedback on all actions

#### 2. `Swiss Coin/Features/Transactions/TransactionEditView.swift`
- **Pre-populated form**: Title, amount, date, and payer loaded from existing transaction via `@State` properties initialized in `init()`
- **Payer picker**: Shows "Me" + all other people from CoreData (same pattern as `PayerPicker` in `AddTransactionView`)
- **Current splits display**: Read-only view of existing splits with amounts
- **Proportional recalculation**: When the total amount changes, all splits are proportionally recalculated (penny-safe with rounding)
- **Validation**: Title must be non-empty, amount must be > 0. Inline validation messages shown
- **Save logic**: Updates existing entity (no new creation), proper `try/catch` with `context.rollback()` on failure
- **Cancel**: Dismisses without saving, with `HapticManager.cancel()` feedback
- Warning footer when amount changes inform user that splits will be recalculated

### Modified Files

#### 3. `Swiss Coin/Features/Transactions/TransactionRowView.swift`
- **Navigation**: Wrapped row content in `NavigationLink` to `TransactionDetailView` (replaces the TODO stub in `showTransactionDetails()`)
- **Swipe actions** (trailing): Delete (destructive, red) and Edit (accent/green)
- **Context menu**: View Details → navigates via `navigationDestination(isPresented:)`, Edit Transaction → opens sheet, Share (existing), Delete Transaction (destructive, with divider separator)
- **Inline delete**: Self-contained delete with confirmation alert when no `onDelete` callback is provided
- **Edit sheet**: Self-contained edit via sheet when no `onEdit` callback is provided
- Preserved all existing amount logic, date formatting, share functionality

#### 4. `Swiss Coin/Features/Transactions/TransactionHistoryView.swift`
- **Changed `NavigationView` → `NavigationStack`**: Required for `NavigationLink` destinations and `navigationDestination` modifiers in child rows
- **Empty state view**: Shown when `transactions.isEmpty` — large icon (`arrow.left.arrow.right.circle`), "No Transactions Yet" title, descriptive subtitle
- **Delete confirmation**: Added alert-based confirmation for row-level deletion (via `transactionToDelete` state)
- **Refactored delete logic**: Extracted `deleteTransaction(_:)` method for reuse between swipe-to-delete and confirmation-based deletion
- Preserved `FinanceQuickActionView()` FAB overlay

## Design System Usage
- `AppColors`: textPrimary, textSecondary, textTertiary, accent, positive, negative, warning, backgroundSecondary, cardBackground
- `AppTypography`: title1, title3, headline, body, subheadline, subheadlineMedium, footnote, caption, amount, amountSmall, amountLarge
- `Spacing`: xxs, xs, sm, md, lg, xl, xxl
- `CornerRadius`: lg, md
- `AvatarSize`: xs, sm, xxl
- `ButtonHeight`, `PrimaryButtonStyle`, `SecondaryButtonStyle`
- `HapticManager`: tap, success, error, delete, cancel
- `CurrencyFormatter.format()` for all monetary amounts
- `CurrentUser.isCurrentUser()` for identity checks
- `Person` extensions: displayName, initials, avatarBackgroundColor, avatarTextColor

## CoreData Compliance
- `payer` (not `paidBy`) for transaction payer relationship
- `owedBy` (not `person`) for split person relationship
- `TransactionSplit` has NO `id` attribute — used `\.objectID` for ForEach identification
- All saves wrapped in `do/try/catch` with `context.rollback()` on failure
- Splits deleted before transactions (respecting relationship integrity)
