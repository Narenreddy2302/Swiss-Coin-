# Swiss Coin — UX Enhancement Proposals

> Generated from a full review of 12 key user-facing views (109 Swift files total).
> Proposals are prioritized by user value, grouped by category, and scoped to the existing SwiftUI + CoreData architecture.

---

## Table of Contents

1. [Data & Insights](#1-data--insights)
2. [Social & Communication](#2-social--communication)
3. [UX Improvements](#3-ux-improvements)
4. [Visual Polish](#4-visual-polish)
5. [Reliability & Infrastructure](#5-reliability--infrastructure)
6. [Priority Matrix](#priority-matrix)

---

## 1. Data & Insights

### 1.1 Monthly Spending Summary on Home Screen

**What:** Replace the current static "You Owe / You are Owed" summary cards with a richer section that includes a monthly total spent, a simple bar or ring chart showing this month vs. last month, and the net balance delta.

**Why it matters:** The Home screen currently shows only aggregate balances. Users have no sense of *velocity* — are they spending more this month? Are debts growing? A monthly summary turns the Home screen from a snapshot into a dashboard.

**Complexity:** Medium
- Need to aggregate `FinancialTransaction` by month (already have date field)
- Introduce a lightweight SwiftUI chart (Swift Charts framework, iOS 16+)
- Compute monthly deltas from existing CoreData fetches

**Files affected:**
- `Swiss Coin/Features/Home/HomeView.swift` — add new `MonthlySummarySection`
- New file: `Swiss Coin/Features/Home/Components/MonthlyChartView.swift`
- Possibly `Swiss Coin/Utilities/BalanceCalculator.swift` — add monthly aggregation helpers

**Priority:** 🔴 High — This is the #1 thing users see; making it more informative dramatically increases engagement.

---

### 1.2 Spending Trends Over Time

**What:** A dedicated "Insights" view accessible from Home (or a new tab) showing spending trends: line chart of monthly totals, top people you split with, average transaction size, and a "settling velocity" metric (how quickly debts get resolved).

**Why it matters:** Power users who track finances want to see patterns. This transforms Swiss Coin from a bill-splitting utility into a personal finance companion.

**Complexity:** High
- New view with multiple chart types (Swift Charts)
- Aggregation queries over `FinancialTransaction` and `Settlement` history
- Date range picker (this month, 3 months, 6 months, year)

**Files affected:**
- New file: `Swiss Coin/Features/Insights/InsightsView.swift`
- New file: `Swiss Coin/Features/Insights/Components/SpendingChartView.swift`
- New file: `Swiss Coin/Features/Insights/Components/TopPeopleView.swift`
- `Swiss Coin/Features/Home/HomeView.swift` — add "View Insights" link
- `Swiss Coin/Utilities/BalanceCalculator.swift` — add trend calculation helpers

**Priority:** 🟡 Medium — High value but substantial build; consider as a v2 feature.

---

### 1.3 Export Data (CSV/PDF)

**What:** Add an export button to TransactionHistoryView and ProfileView that generates a CSV or PDF summary of all transactions, filterable by date range and person/group.

**Why it matters:** Users need to reconcile with bank statements, file expenses for work, or simply keep records. Currently there is no way to get data out of the app.

**Complexity:** Medium
- CSV is straightforward (string concatenation → share sheet)
- PDF requires a basic `UIGraphicsPDFRenderer` or SwiftUI `Canvas` → `PDFDocument`
- Date range picker + person/group filter UI

**Files affected:**
- `Swiss Coin/Features/Transactions/TransactionHistoryView.swift` — add toolbar export button
- `Swiss Coin/Features/Profile/ProfileView.swift` — add "Export Data" row in settings
- New file: `Swiss Coin/Services/ExportManager.swift`
- New file: `Swiss Coin/Features/Transactions/ExportOptionsView.swift`

**Priority:** 🟡 Medium — Highly requested in finance apps; relatively self-contained to build.

---

### 1.4 Subscription Cost Summary

**What:** On the Subscriptions tab, show a total monthly cost at the top (sum of all personal + user's share of shared subscriptions), with a breakdown by billing cycle (monthly/yearly normalized to monthly).

**Why it matters:** The subscription list currently shows individual items with no aggregate view. Users can't answer "how much am I spending on subscriptions per month?" at a glance.

**Complexity:** Low
- Sum subscription amounts (already available in `Subscription.amount` and `.cycle`)
- Normalize yearly → monthly with simple division
- Display as a card above the list

**Files affected:**
- `Swiss Coin/Features/Subscriptions/SubscriptionView.swift` — add summary card above segment control
- New file: `Swiss Coin/Features/Subscriptions/Components/SubscriptionCostSummaryCard.swift`

**Priority:** 🔴 High — Low effort, high impact. Users will immediately appreciate this.

---

## 2. Social & Communication

### 2.1 Tab Badge Notifications

**What:** Show badge counts on the People and Subscriptions tabs in `MainTabView` — e.g., number of unsettled balances, pending reminders, or people who owe you money.

**Why it matters:** Currently `MainTabView` is bare — no badges, no visual cues. Users have to tap into each tab to discover if anything needs attention. Badges create a pull to engage.

**Complexity:** Low
- Compute badge counts from existing `@FetchRequest` data
- Apply `.badge()` modifier on `TabView` items
- Use `@FetchRequest` or computed properties in `MainTabView`

**Files affected:**
- `Swiss Coin/Views/MainTabView.swift` — add badge modifiers and fetch logic
- Possibly create a small `BadgeCalculator` utility

**Priority:** 🔴 High — Tiny implementation, massive UX signal improvement.

---

### 2.2 Quick Settle-Up from Home Screen

**What:** Add a "Settle Up" card or button on the Home screen that shows the person with the largest outstanding balance and offers a one-tap settle action.

**Why it matters:** Currently settling requires: Home → People tab → select person → conversation → tap Settle. That's 4+ taps for the most common financial action. A Home shortcut cuts this to 1–2 taps.

**Complexity:** Low-Medium
- Identify the person with the largest balance (already computed in `HomeView`)
- Add a prominent card with "Settle with [Name]" CTA
- Present `SettlementView` sheet directly from Home

**Files affected:**
- `Swiss Coin/Features/Home/HomeView.swift` — add `QuickSettleCard` section
- New file: `Swiss Coin/Features/Home/Components/QuickSettleCard.swift`

**Priority:** 🔴 High — Reduces friction on the most important user action.

---

### 2.3 Outstanding Balances List on Home

**What:** Below the summary cards, show a compact list of all people with non-zero balances (sorted by amount), each with inline "Remind" and "Settle" quick actions.

**Why it matters:** The Home screen currently shows only the last 5 transactions. Users who want to see *who* owes them have to go to the People tab and scan through the list. Surfacing balances on Home makes the app feel action-oriented.

**Complexity:** Medium
- Reuse `allPeople` fetch from `HomeView`
- Filter to non-zero balances, sort by absolute amount descending
- Compact row with person avatar, balance, and action buttons

**Files affected:**
- `Swiss Coin/Features/Home/HomeView.swift` — add outstanding balances section
- New file: `Swiss Coin/Features/Home/Components/OutstandingBalanceRow.swift`

**Priority:** 🔴 High — Turns Home from passive display into an action center.

---

### 2.4 Remind All / Settle All Batch Actions

**What:** In the People list, add a toolbar button "Remind All" that sends reminders to everyone who owes you, and "Settle All" to record settlements for all outstanding balances at once.

**Why it matters:** If a user has 5+ people who owe them, reminding each one individually is tedious. Batch operations respect the user's time.

**Complexity:** Medium
- Loop over all people with positive balances
- Reuse existing `ReminderSheetView` / `SettlementView` logic
- Confirmation dialog before batch action

**Files affected:**
- `Swiss Coin/Features/People/PeopleView.swift` — add batch action toolbar buttons
- New file: `Swiss Coin/Features/People/BatchSettleView.swift`
- New file: `Swiss Coin/Features/People/BatchReminderView.swift`

**Priority:** 🟡 Medium — Valuable for power users; less critical for new users.

---

## 3. UX Improvements

### 3.1 Sort & Filter on Transaction History

**What:** Add a filter bar to `TransactionHistoryView` with options: date range, amount range, person/group, type (expense vs. settlement), and sort by (date, amount, person).

**Why it matters:** The transaction list currently shows *everything* in reverse chronological order with no filtering. As the list grows beyond 20–30 items, finding specific transactions becomes painful. The search tab helps but requires knowing what to search for.

**Complexity:** Medium
- Add filter state variables and a filter sheet/bar
- Dynamic `NSPredicate` construction based on filters
- Sort descriptor toggling

**Files affected:**
- `Swiss Coin/Features/Transactions/TransactionHistoryView.swift` — add filter UI and dynamic predicate
- New file: `Swiss Coin/Features/Transactions/TransactionFilterView.swift`

**Priority:** 🔴 High — Essential for any list-based app as data grows.

---

### 3.2 Keyboard Dismiss on Tap Outside

**What:** In conversation views (`PersonConversationView`, `GroupConversationView`, `SharedSubscriptionConversationView`), tapping the scroll area should dismiss the keyboard. Currently the keyboard stays up until you explicitly tap elsewhere or hit Send.

**Why it matters:** This is standard iOS messaging behavior (iMessage, WhatsApp). Missing it feels broken.

**Complexity:** Low
- Add `.onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder)... }` to ScrollView, or use `.scrollDismissesKeyboard(.interactively)` (iOS 16+)

**Files affected:**
- `Swiss Coin/Features/People/PersonConversationView.swift`
- `Swiss Coin/Features/People/GroupConversationView.swift`
- `Swiss Coin/Features/Subscriptions/SharedSubscriptionConversationView.swift`
- `Swiss Coin/Features/People/Components/MessageInputView.swift`

**Priority:** 🔴 High — Trivial fix, removes constant friction.

---

### 3.3 Onboarding Walkthrough for First-Time Users

**What:** A 3–4 screen onboarding flow shown on first launch: (1) Welcome, (2) Add your first person, (3) Create an expense and split it, (4) Track who owes what. Use `@AppStorage("hasCompletedOnboarding")` to show only once.

**Why it matters:** The current empty state in `HomeView` says "Start by adding your first expense" but doesn't guide the user through the actual flow. New users might not discover the FAB (floating action button), the People tab, or the split workflow.

**Complexity:** Medium
- 3–4 SwiftUI pages with `TabView(.page)` style
- Illustrations or SF Symbol compositions
- `@AppStorage` flag to track completion

**Files affected:**
- New file: `Swiss Coin/Features/Onboarding/OnboardingView.swift`
- `Swiss Coin/App/ContentView.swift` — conditional display based on onboarding flag
- `Swiss Coin/App/Swiss_CoinApp.swift` — potentially

**Priority:** 🟡 Medium — Important for retention of new users, but existing users won't benefit.

---

### 3.4 Undo for Destructive Actions

**What:** When a user deletes a transaction, person, or group, show a snackbar/toast with "Undo" for ~5 seconds before the deletion is committed, instead of the current immediate delete + alert pattern.

**Why it matters:** The current flow uses a confirmation alert *before* deletion, which is standard but doesn't allow recovery after accidental confirmation. A post-action undo (like Gmail or iOS Mail) is more forgiving.

**Complexity:** Medium
- Implement a snackbar/toast overlay view
- Delay the `viewContext.save()` call by ~5 seconds
- If undo is tapped, rollback the context instead

**Files affected:**
- `Swiss Coin/Features/People/PeopleView.swift` (person delete)
- `Swiss Coin/Features/Transactions/TransactionHistoryView.swift` (transaction delete)
- `Swiss Coin/Features/Transactions/TransactionRowView.swift` (swipe delete)
- New file: `Swiss Coin/Components/UndoToastView.swift`

**Priority:** 🟡 Medium — Nice safety net; more forgiving than confirmation dialogs.

---

### 3.5 Pull-to-Refresh with Visual Feedback

**What:** The Home screen has `.refreshable` but it just calls `viewContext.refreshAllObjects()` with no visual indication that data was actually refreshed. Add a brief "Updated" toast or subtle animation confirming the refresh.

**Why it matters:** Without feedback, users don't know if the pull-to-refresh did anything. They'll pull again and again.

**Complexity:** Low
- Add a brief overlay or inline text that fades in/out after refresh
- Optionally add a timestamp "Last updated: just now"

**Files affected:**
- `Swiss Coin/Features/Home/HomeView.swift` — add refresh feedback

**Priority:** 🟢 Low — Minor polish but improves perceived responsiveness.

---

### 3.6 Search by Amount / Date Range

**What:** Extend `SearchView` to support searching by amount (e.g., typing "50" finds transactions around $50) and by date expressions (e.g., "January" or "last week").

**Why it matters:** Currently search only matches on `title`/`name` strings. Users often remember *how much* they spent, not the exact title. Amount-based search is a natural query pattern.

**Complexity:** Medium
- Parse search text for numeric patterns
- Add amount range matching to `filteredTransactions`
- Optionally parse date keywords

**Files affected:**
- `Swiss Coin/Features/Search/SearchView.swift` — extend filter logic

**Priority:** 🟡 Medium — Makes search genuinely useful for financial data.

---

### 3.7 Swipe Actions on People/Group Lists

**What:** Add swipe actions (quick settle, remind, add expense) directly on `PersonListRowView` and `GroupListRowView`, similar to how `TransactionRowView` has swipe-to-delete.

**Why it matters:** Context menus exist but require a long-press, which is less discoverable. Swipe actions are visible on first interaction and match iOS conventions.

**Complexity:** Low
- Add `.swipeActions` modifier to the list row ForEach
- Reuse existing sheet presentation logic

**Files affected:**
- `Swiss Coin/Features/People/PeopleView.swift` — add `.swipeActions` to `PersonListRowView` and `GroupListRowView`

**Priority:** 🟡 Medium — Improves discoverability of existing actions.

---

## 4. Visual Polish

### 4.1 Confetti / Celebration Animation on Settle-Up

**What:** When a user completes a settlement and a balance reaches zero, trigger a confetti particle animation and a "🎉 All settled up!" overlay.

**Why it matters:** Settling up is the emotional climax of the app — the debt is resolved! Celebrating this moment creates positive reinforcement and makes the app *delightful*. This is the kind of small touch that gets apps mentioned in conversations.

**Complexity:** Low-Medium
- Use a lightweight confetti library or custom `Canvas` + `TimelineView` particle system
- Trigger on successful settlement save when balance becomes zero

**Files affected:**
- `Swiss Coin/Features/People/SettlementView.swift` — trigger on save
- `Swiss Coin/Features/People/GroupSettlementView.swift` — trigger on save
- New file: `Swiss Coin/Components/ConfettiView.swift`

**Priority:** 🟡 Medium — Pure delight factor; low effort for outsized emotional impact.

---

### 4.2 Skeleton Loading States

**What:** Show animated placeholder shapes (skeleton screens) while CoreData fetches are loading, instead of empty views that flash briefly before content appears.

**Why it matters:** On first launch or with large datasets, there's a brief moment where the screen is blank before data loads. Skeleton screens communicate "content is coming" and feel faster than a blank screen.

**Complexity:** Low
- Create reusable `SkeletonRow` components with shimmer animation
- Show when `FetchedResults` is empty *and* data hasn't been loaded yet (use a `@State` flag)

**Files affected:**
- `Swiss Coin/Features/Home/HomeView.swift`
- `Swiss Coin/Features/People/PeopleView.swift`
- `Swiss Coin/Features/Transactions/TransactionHistoryView.swift`
- New file: `Swiss Coin/Components/SkeletonView.swift`

**Priority:** 🟢 Low — Polish item; CoreData local fetches are usually fast enough.

---

### 4.3 Animated Transitions Between Views

**What:** Add matched geometry transitions for navigating from a person row to their conversation view (avatar morphs into toolbar avatar) and from a transaction row to its detail view.

**Why it matters:** SwiftUI's default push transition is functional but generic. Matched geometry creates spatial continuity that helps users understand the navigation hierarchy.

**Complexity:** Medium-High
- `@Namespace` and `.matchedGeometryEffect` across navigation boundaries
- Requires careful coordination between list rows and destination views
- Can be fragile with `NavigationStack`

**Files affected:**
- `Swiss Coin/Features/People/PeopleView.swift`
- `Swiss Coin/Features/People/PersonConversationView.swift`
- `Swiss Coin/Features/Transactions/TransactionRowView.swift`
- `Swiss Coin/Features/Transactions/TransactionDetailView.swift`

**Priority:** 🟢 Low — Beautiful but complex and potentially buggy; save for polish phase.

---

### 4.4 Dark Mode Hardcoded Color Audit

**What:** Audit all views for hardcoded colors that don't adapt to dark/light mode. The `SharedSubscriptionConversationView` uses `Color.black` directly for backgrounds instead of `AppColors.background`. Other views use `Color(UIColor.systemGray6)` directly instead of the design system.

**Why it matters:** Inconsistent dark/light mode behavior makes the app feel unpolished. Users switching between modes will see jarring differences.

**Specific issues found:**
- `SharedSubscriptionConversationView.swift`: Uses `Color.black` for background (line: `.background(Color.black)`) — won't work in light mode
- `GroupConversationView.swift`: `GroupActionButton` uses `Color(UIColor.systemGray6)` and `Color(UIColor.systemGray4)` directly instead of `AppColors` equivalents
- `GroupSettlementMessageView` and `GroupReminderMessageView`: Use raw `Color(UIColor.systemGray5)` and `Color.orange.opacity(0.15)`
- `TransactionHistoryView.swift`: Uses `Color(uiColor: .secondarySystemBackground)` directly instead of `AppColors.backgroundSecondary`

**Complexity:** Low
- Find-and-replace raw color references with `AppColors` equivalents
- Ensure `AppColors.background` uses `Color(UIColor.systemBackground)` not `Color.black`

**Files affected:**
- `Swiss Coin/Features/Subscriptions/SharedSubscriptionConversationView.swift`
- `Swiss Coin/Features/People/GroupConversationView.swift`
- `Swiss Coin/Features/Transactions/TransactionHistoryView.swift`
- `Swiss Coin/Utilities/DesignSystem.swift` — verify `AppColors.background` is adaptive

**Priority:** 🔴 High — Bug-level issue. `AppColors.background = Color.black` in DesignSystem.swift means light mode is broken for any view using it.

---

### 4.5 Empty State Illustrations

**What:** Replace the SF Symbol-based empty states with custom illustrated empty states (or more expressive SF Symbol compositions with color and layering).

**Why it matters:** The current empty states are functional but feel generic. Custom illustrations (even simple ones) create personality and make the "zero data" state feel intentional rather than barren.

**Complexity:** Low (with existing assets) / Medium (creating new illustrations)

**Files affected:**
- `Swiss Coin/Features/Home/HomeView.swift` — `EmptyStateView`
- `Swiss Coin/Features/People/PeopleView.swift` — `PersonEmptyStateView`, `GroupEmptyStateView`
- `Swiss Coin/Features/Transactions/TransactionHistoryView.swift` — empty state
- `Swiss Coin/Features/Search/SearchView.swift` — `SearchEmptyPromptView`, `SearchNoResultsView`

**Priority:** 🟢 Low — Nice to have; doesn't affect functionality.

---

## 5. Reliability & Infrastructure

### 5.1 Data Backup & Restore (iCloud / File Export)

**What:** Add CloudKit sync for CoreData (using `NSPersistentCloudKitContainer`) or at minimum, a manual backup/restore to iCloud Drive as a JSON/SQLite file.

**Why it matters:** If a user loses their phone, all their financial data is gone. For a finance app, data loss is catastrophic. This is table-stakes functionality.

**Complexity:** High (CloudKit sync) / Medium (manual file backup)
- CloudKit: Change `NSPersistentContainer` → `NSPersistentCloudKitContainer`, handle merge policies
- Manual: Serialize CoreData to JSON, write to iCloud Drive via `FileManager.default.url(forUbiquityContainerIdentifier:)`

**Files affected:**
- `Swiss Coin/Services/Persistence.swift` — swap container type or add export methods
- `Swiss Coin/Features/Profile/ProfileView.swift` — add "Backup & Restore" settings row
- New file: `Swiss Coin/Services/BackupManager.swift`
- New file: `Swiss Coin/Features/Profile/BackupRestoreView.swift`

**Priority:** 🔴 High — Data loss is the #1 reason users abandon finance apps.

---

### 5.2 CoreData Migration Strategy

**What:** Implement lightweight migration support and a versioned data model with proper mapping models for schema changes.

**Why it matters:** As the app evolves (adding fields, renaming entities), existing users' data must survive app updates. Without migration handling, updates can crash on launch.

**Complexity:** Medium
- Enable lightweight migration options on the persistent store
- Create versioned `.xcdatamodel` files for future changes
- Add migration testing to the development workflow

**Files affected:**
- `Swiss Coin/Services/Persistence.swift` — add migration options to store description
- `Swiss Coin/Resources/Swiss_Coin.xcdatamodeld/` — versioned models

**Priority:** 🔴 High — Critical infrastructure; must be in place before any schema changes ship.

---

### 5.3 Offline-First Error Handling Improvements

**What:** Improve error handling across all save operations. Currently, errors are caught and printed to console (`print("Error...")`), but many don't show user-facing feedback. Add consistent error toasts.

**Specific issues found:**
- `PersonListRowView.deletePerson()`: Catches error, prints, but no user alert
- `GroupListRowView.deleteGroup()`: Same pattern
- `TransactionRowView.deleteTransaction()`: Same pattern
- `TransactionHistoryView.deleteTransaction()`: Same pattern
- Various settlement/reminder save operations

**Why it matters:** Silent failures leave users confused — they performed an action but nothing happened. Consistent error feedback builds trust.

**Complexity:** Low
- Create a reusable error toast/banner component
- Wire it into all save operations

**Files affected:**
- All views with `viewContext.save()` calls (approximately 10+ files)
- New file: `Swiss Coin/Components/ErrorBannerView.swift`
- Consider an `@EnvironmentObject` error handler for app-wide consistency

**Priority:** 🟡 Medium — Important for reliability perception; errors are rare but confusing when silent.

---

### 5.4 Transaction History Pagination

**What:** The `TransactionHistoryView` fetches ALL transactions with no limit. Add pagination (fetch 20 at a time, load more on scroll).

**Why it matters:** As transaction count grows to hundreds or thousands, fetching all at once will cause memory pressure and slow initial render.

**Complexity:** Low-Medium
- Use `fetchBatchSize` on the `@FetchRequest` (CoreData handles faulting)
- Or implement manual pagination with `fetchOffset` and `fetchLimit`
- Add "Load more" row or infinite scroll trigger

**Files affected:**
- `Swiss Coin/Features/Transactions/TransactionHistoryView.swift` — add `fetchBatchSize` or manual pagination

**Priority:** 🟡 Medium — Won't be noticeable until the app has significant data, but proactive optimization is wise.

---

## Priority Matrix

### 🔴 Do First (High Impact, Reasonable Effort)

| # | Enhancement | Effort | Impact |
|---|---|---|---|
| 4.4 | Dark Mode Color Audit | Low | Critical (bug fix) |
| 2.1 | Tab Badge Notifications | Low | High |
| 3.2 | Keyboard Dismiss on Tap | Low | High |
| 1.4 | Subscription Cost Summary | Low | High |
| 2.2 | Quick Settle from Home | Low-Med | High |
| 2.3 | Outstanding Balances on Home | Medium | High |
| 3.1 | Sort & Filter on History | Medium | High |
| 5.1 | Data Backup & Restore | Medium-High | Critical |
| 5.2 | CoreData Migration Strategy | Medium | Critical |
| 1.1 | Monthly Spending Summary | Medium | High |

### 🟡 Do Next (Good Value, Medium Effort)

| # | Enhancement | Effort | Impact |
|---|---|---|---|
| 1.3 | Export Data (CSV/PDF) | Medium | Medium-High |
| 3.6 | Search by Amount/Date | Medium | Medium |
| 3.7 | Swipe Actions on Lists | Low | Medium |
| 4.1 | Confetti on Settle-Up | Low-Med | Medium |
| 3.4 | Undo for Destructive Actions | Medium | Medium |
| 3.3 | Onboarding Walkthrough | Medium | Medium |
| 2.4 | Batch Remind/Settle All | Medium | Medium |
| 5.3 | Error Handling Improvements | Low | Medium |
| 5.4 | Transaction Pagination | Low-Med | Medium |

### 🟢 Polish Phase (Nice to Have)

| # | Enhancement | Effort | Impact |
|---|---|---|---|
| 1.2 | Spending Trends / Insights | High | Medium |
| 4.2 | Skeleton Loading States | Low | Low |
| 4.3 | Animated Transitions | Med-High | Low |
| 4.5 | Custom Empty State Illustrations | Low-Med | Low |
| 3.5 | Refresh Visual Feedback | Low | Low |

---

## Recommended Implementation Order

**Sprint 1 — Foundation & Quick Wins (1-2 weeks):**
1. Fix Dark Mode color audit (4.4) — this is a bug
2. Add keyboard dismiss (3.2)
3. Add tab badges (2.1)
4. Add subscription cost summary (1.4)

**Sprint 2 — Home Screen Transformation (1-2 weeks):**
5. Outstanding balances on Home (2.3)
6. Quick settle from Home (2.2)
7. Monthly spending summary (1.1)

**Sprint 3 — Data Integrity & Power Features (2 weeks):**
8. CoreData migration strategy (5.2)
9. Data backup/restore (5.1)
10. Sort & filter on transaction history (3.1)

**Sprint 4 — Delight & Growth (2 weeks):**
11. Confetti on settle-up (4.1)
12. Export data (1.3)
13. Onboarding walkthrough (3.3)
14. Search enhancements (3.6)

---

*Document generated 2026-02-02. Review and reprioritize as user feedback comes in.*
