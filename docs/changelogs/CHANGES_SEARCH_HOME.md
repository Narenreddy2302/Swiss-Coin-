# Changes: Search Functionality & Home View Improvements

## Summary
Added a global search view, replaced the History tab with Search in the tab bar, improved the Home view with pull-to-refresh and a better empty state, and improved the TransactionHistoryView empty state.

---

## Files Changed

### 1. NEW — `Swiss Coin/Features/Search/SearchView.swift`
- **Global search view** with real-time filtering across all entity types:
  - **Transactions** — searched by `title`
  - **People** — searched by `name` (excludes current user)
  - **Groups** — searched by `name`
  - **Subscriptions** — searched by `name`
- Uses `@FetchRequest` for all 4 CoreData entity types with in-memory filtering based on `searchText`
- Uses `.searchable()` modifier with always-visible search bar in the navigation bar
- **Results grouped by category** with section headers showing icon, title, and result count
- Each result is **tappable** and navigates to the appropriate detail/conversation view:
  - Transactions → `TransactionRowView` (inline display)
  - People → `PersonConversationView`
  - Groups → `GroupConversationView`
  - Subscriptions → `SubscriptionDetailView`
- **Empty search state**: Shows "People" horizontal chips + "Recent Transactions" when search is empty
- **No results state**: Shows magnifying glass icon + "No Results" message
- **No data state**: Shows welcoming prompt to start searching
- Uses `HapticManager.selectionChanged()` on result taps
- Smooth animations on results appearing/disappearing via `.animation(.easeInOut)`
- Follows existing design system: `AppColors`, `AppTypography`, `Spacing`, `CornerRadius`, `IconSize`, `AvatarSize`

### 2. MODIFIED — `Swiss Coin/Views/MainTabView.swift`
- Tab 4 changed from `TransactionHistoryView` ("History" / `clock.fill`) → `SearchView` ("Search" / `magnifyingglass`)
- History remains accessible via HomeView's "See All" `NavigationLink`

### 3. MODIFIED — `Swiss Coin/Features/Home/HomeView.swift`
- Added `fetchLimit: 5` to the transactions `@FetchRequest` for performance
- Updated `recentTransactions` computed property to use the full (already limited) fetch results
- Added `.refreshable` pull-to-refresh support using `viewContext.refreshAllObjects()`
- **Improved empty state**: Changed from generic "No recent activity" to a welcoming "Welcome to Swiss Coin!" with sparkles icon, friendly copy, and accent-colored CTA hint

### 4. MODIFIED — `Swiss Coin/Features/Transactions/TransactionHistoryView.swift`
- Improved empty state design to match the consistent pattern used across the app:
  - Uses `IconSize.xxl` for icon size (consistent with other empty states)
  - Uses `AppTypography.title2()` for heading
  - Added accent-colored hint row with `plus.circle.fill` icon
  - Added `AppColors.backgroundSecondary` background

### 5. MODIFIED — `Swiss Coin/Utilities/DesignSystem.swift`
- Added `AppColors.surface` (`Color(UIColor.systemGray5)`) for search bar and input field backgrounds

---

## Design Patterns Followed
- All views use the existing design tokens (`Spacing`, `CornerRadius`, `AppColors`, `AppTypography`, `IconSize`, `AvatarSize`)
- Search result rows mirror the styling of `PersonListRowView` and `GroupListRowView` from PeopleView
- Empty states follow the same pattern as `PersonEmptyStateView`, `GroupEmptyStateView`, and `EmptySubscriptionView`
- Haptic feedback via `HapticManager` on all interactive elements
- Navigation uses existing `NavigationStack` / `NavigationLink` patterns

## CoreData Notes
- Used `payer` (not `paidBy`) for transaction relationships
- Used `owedBy` (not `person`) for TransactionSplit relationships
- TransactionSplit has no `id` — identified through relationship context
- `Person.calculateBalance()` used for balance display in search results
