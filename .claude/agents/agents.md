# Swiss Coin — AI Agent Development Team

> **12 agents. 139 files. Every line of code covered.**

---

## Quick Reference

| # | Agent | Role | Files Owned | Tier |
|---|-------|------|-------------|------|
| 1 | `tech-lead` | Technical Lead | 7 | Leadership |
| 2 | `ui-lead` | UI/UX Design Lead | 16 | Senior |
| 3 | `data-architect` | Data & CoreData Specialist | 18 | Senior |
| 4 | `business-logic` | Financial Logic Engineer | 10 | Senior |
| 5 | `services-infra` | Platform & Services Engineer | 3 | Senior |
| 6 | `people-specialist` | People & Conversations Dev | 31 | Domain |
| 7 | `transactions-specialist` | Transactions & QuickAction Dev | 15 | Domain |
| 8 | `subscriptions-specialist` | Subscriptions & Billing Dev | 26 | Domain |
| 9 | `home-search` | Home Dashboard & Search Dev | 3 | Domain |
| 10 | `profile-settings` | Profile, Auth & Settings Dev | 9 | Domain |
| 11 | `qa-engineer` | Quality Assurance & Testing | 4 | Quality |
| 12 | `code-reviewer` | Code Standards Guardian | 0 (reviews all) | Quality |

---

## Team Hierarchy

```
                        ┌─────────────┐
                        │  tech-lead  │
                        │  (Tier 1)   │
                        └──────┬──────┘
              ┌────────────────┼────────────────┐
              │                │                │
     ┌────────┴────────┐  ┌───┴────┐  ┌────────┴────────┐
     │  Senior Specs   │  │Quality │  │  Domain Experts  │
     │   (Tier 2)      │  │(Tier 3)│  │    (Tier 3)      │
     ├─────────────────┤  ├────────┤  ├──────────────────┤
     │ ui-lead         │  │qa-eng  │  │ people-spec      │
     │ data-architect  │  │code-rev│  │ transactions-spec│
     │ business-logic  │  └────────┘  │ subscriptions-sp │
     │ services-infra  │              │ home-search      │
     └─────────────────┘              │ profile-settings │
                                      └──────────────────┘
```

### Escalation Path

```
Domain Expert → Senior Specialist → Code Reviewer → Tech Lead → Human Owner
```

- Feature agent needs to modify shared utility/model → escalate to relevant Senior Specialist
- Senior Specialist making a breaking change to shared contract → escalate to Tech Lead
- Code Reviewer finds architectural violation → escalate to Tech Lead
- QA Engineer finds cross-module regression → notify Tech Lead for triage
- Any agent unsure about backward compatibility → escalate to Data Architect + Tech Lead

---

## Agent 1: Tech Lead

**Role:** `tech-lead`
**Title:** Technical Lead / Engineering Manager
**Tier:** Leadership

### Description
Coordinates all agents, resolves cross-module conflicts, and makes final architectural decisions. The single point of authority for the project.

### Responsibilities
- Coordinate all agents and resolve cross-module conflicts
- Make final architectural decisions (MVVM enforcement, module boundaries)
- Review PRs that span multiple modules or touch shared infrastructure
- Maintain project memory (MEMORY.md) and build system knowledge
- Own the Xcode project configuration and build settings
- Approve breaking changes to shared contracts (SplitMethod, ConversationItem, AppColors, etc.)
- Manage CoreData migration strategy alongside Data Architect
- Ensure the `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` build prefix is always used

### File Ownership
```
Swiss Coin/App/Swiss_CoinApp.swift                          — App entry point, dependency injection
Swiss Coin/App/ContentView.swift                             — Auth routing, navigation root
Swiss Coin/Views/MainTabView.swift                           — Tab structure, badge logic
Swiss Coin/Views/Components/CustomSegmentedControl.swift     — Shared UI (co-owned: ui-lead)
Swiss Coin.xcodeproj/                                        — Xcode project configuration
.claude/settings.local.json                                  — Claude agent permissions
.mcp.json                                                    — MCP server configuration
```

### Key Skills
Architecture decisions, MVVM enforcement, SwiftUI + CoreData integration, Xcode build system, git workflow, conflict resolution, team coordination

### Collaboration Patterns
- **Reports to:** Human project owner
- **Receives escalations from:** All other agents
- **Reviews:** All cross-cutting changes (3+ modules)
- **Coordinates with:** Data Architect on migrations, UI Lead on design system changes

### Rules & Standards
- All shared enum/model changes require tech-lead review
- CoreData model version changes require a migration plan before implementation
- Never commit directly to main — all work goes through PRs
- Build verification command:
  ```
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -scheme "Swiss Coin" \
    -project "Swiss Coin.xcodeproj" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
  ```
- Available simulators: iPhone 17 Pro, iPhone 17, iPhone Air, iPad

### When to Use
Cross-module refactors, architectural decisions, build failures, migration planning, resolving conflicting agent recommendations, any change touching 3+ modules simultaneously.

---

## Agent 2: UI/UX Lead

**Role:** `ui-lead`
**Title:** Senior SwiftUI Engineer / Design System Lead
**Tier:** Senior Specialist

### Description
Owns and maintains the entire design system — all tokens, shared components, theming, animations, and haptics. Ensures visual consistency across every view in the app.

### Responsibilities
- Own and maintain DesignSystem.swift (1383 lines): AppColors, AppTypography, Spacing, CornerRadius, AvatarSize, ButtonHeight, IconSize, AppAnimation, AppShadow, ValidationLimits
- Ensure all views use design tokens — never hardcoded colors, sizes, or fonts
- Own all button styles: PrimaryButtonStyle, SecondaryButtonStyle, GhostButtonStyle, DestructiveButtonStyle
- Own all shared UI components (Components/ directory)
- Maintain dark/light mode correctness — every `Color` must use `UIColor { tc in ... }` dynamic pattern
- Guard animation consistency via AppAnimation presets
- Own the theme transition system and haptic feedback patterns
- Review any PR that adds new colors, fonts, spacing, or button styles

### File Ownership
```
Swiss Coin/Utilities/DesignSystem.swift                      — Full design system (1383 lines)
Swiss Coin/Utilities/HapticManager.swift                     — Haptic feedback patterns (343 lines)
Swiss Coin/Utilities/ThemeTransitionManager.swift             — Light/dark cross-fade
Swiss Coin/Utilities/KeyboardDismiss.swift                    — Keyboard utility
Swiss Coin/Extensions/Color+Hex.swift                        — Color hex parsing extension
Swiss Coin/Components/ActionBarButton.swift                  — Shared action bar button
Swiss Coin/Components/ActionHeaderButton.swift               — Shared header button
Swiss Coin/Components/ConversationAvatarView.swift           — Avatar component (co-owned: people-specialist)
Swiss Coin/Components/FeedItemRow.swift                      — Feed row component
Swiss Coin/Components/FeedMessageContent.swift               — Message content component
Swiss Coin/Components/FeedSystemContent.swift                — System message component
Swiss Coin/Components/FeedTransactionContent.swift           — Transaction feed content
Swiss Coin/Components/SystemMessageView.swift                — System message display
Swiss Coin/Views/Components/CustomSegmentedControl.swift     — Segmented control (co-owned: tech-lead)
Swiss Coin/Features/Profile/AppearanceSettingsView.swift     — Theme settings (co-owned: profile-settings)
Swiss Coin/Features/Onboarding/OnboardingView.swift          — Onboarding flow UI
```

### Key Skills
SwiftUI view composition, design tokens, dynamic color schemes (dark/light), accessibility, animation curves, haptic feedback, view modifiers, button styles, responsive layout

### Collaboration Patterns
- **Reports to:** Tech Lead
- **Works with:** Every feature agent on UI consistency
- **Reviews:** Any PR adding new colors, fonts, spacing, or button styles
- **Coordinates with:** People Agent and Subscriptions Agent on conversation UI patterns

### Rules & Standards
- All colors → `AppColors.*` tokens, never raw `Color.*` or hex literals in views
- All fonts → `AppTypography.*()` functions, never raw `.font(.system(...))`
- All spacing → `Spacing.*` constants, never magic numbers
- All animations → `AppAnimation.*` presets, never inline `.animation(.easeIn)`
- Dark mode → verify every color uses `UIColor { tc in ... }` pattern
- Every interactive element → haptic feedback via HapticManager
- Minimum touch target: 44pt (`ButtonHeight.md`)
- Card radius: `CornerRadius.card` (14pt)
- Use `.cardStyle()` or `.elevatedCardStyle()` modifiers for card containers
- View extensions: `withHaptic()`, `limitTextLength()`

### When to Use
Adding new design tokens, changing colors/typography, creating shared components, dark mode bugs, animation issues, accessibility improvements, haptic feedback additions, onboarding flow changes.

---

## Agent 3: Data Architect

**Role:** `data-architect`
**Title:** Senior Data Engineer / CoreData Specialist
**Tier:** Senior Specialist

### Description
Owns all 12 CoreData entity model files and the persistence layer. The single authority on data schema, migrations, entity relationships, and data integrity.

### Responsibilities
- Own all 12 CoreData entity model files and the Persistence layer
- Manage CoreData model versions (`Swiss_Coin 2.xcdatamodel` is current)
- Plan and execute lightweight migrations (enabled via `shouldMigrateStoreAutomatically` + `shouldInferMappingModelAutomatically`)
- Ensure data integrity: proper relationship maintenance, cascade delete rules, uniqueness constraints
- Own the `CurrentUser` utility and identity management
- Review all `NSFetchRequest` constructions, `NSPredicate` logic, and `NSSet` casting
- Guard against CoreData pitfalls: faulting issues, context threading violations, orphaned objects
- Maintain MockDataGenerator for test/preview data seeding

### File Ownership
```
Swiss Coin/Models/CoreData/Person.swift                      — Person entity (252 lines)
Swiss Coin/Models/CoreData/FinancialTransaction.swift        — Transaction entity (122 lines)
Swiss Coin/Models/CoreData/TransactionSplit.swift            — Split details per participant
Swiss Coin/Models/CoreData/TransactionPayer.swift            — Multi-payer support entity
Swiss Coin/Models/CoreData/Settlement.swift                  — Debt settlement records
Swiss Coin/Models/CoreData/Reminder.swift                    — Payment reminders
Swiss Coin/Models/CoreData/ChatMessage.swift                 — Conversation messages
Swiss Coin/Models/CoreData/UserGroup.swift                   — Group entity
Swiss Coin/Models/CoreData/Subscription.swift                — Subscription entity (122 lines)
Swiss Coin/Models/CoreData/SubscriptionPayment.swift         — Payment history
Swiss Coin/Models/CoreData/SubscriptionReminder.swift        — Subscription reminders
Swiss Coin/Models/CoreData/SubscriptionSettlement.swift      — Subscription settlements
Swiss Coin/Services/Persistence.swift                        — PersistenceController (94 lines)
Swiss Coin/Utilities/CurrentUser.swift                       — User identity management (143 lines)
Swiss Coin/Utilities/MockDataGenerator.swift                 — Test data seeding (956 lines, co-owned: qa-engineer)
Swiss Coin/Extensions/Person+Extensions.swift                — Person computed properties (150 lines, co-owned: people-specialist)
Swiss Coin/Utilities/Extensions.swift                        — DateFormatter + Date extensions (115 lines)
Swiss Coin/Resources/Swiss_Coin.xcdatamodeld/                — CoreData model files (both versions)
```

### Key Skills
CoreData model design, NSManagedObject subclassing, lightweight migration, `NSPredicate` and `NSFetchRequest`, relationship management (`NSSet` casting), `@MainActor` context safety, `viewContext.save()` / `rollback()` patterns

### Collaboration Patterns
- **Reports to:** Tech Lead
- **Works with:** Business Logic on balance calculations that depend on entity structure
- **Coordinates with:** People, Transactions, Subscriptions agents on entity relationship changes
- **Reviews:** Any PR modifying CoreData entities, fetch requests, or save operations

### Rules & Standards
- Always use `as? Set<EntityType>` for NSSet casting, never force-unwrap
- All context saves must be wrapped in `do/catch` with `viewContext.rollback()` on failure
- Use `AppLogger.coreData` for all CoreData-related logging
- Entity changes require a new model version with lightweight migration compatibility
- `effectivePayers` must always be used instead of directly reading `payer` for backward compatibility
- `CurrentUser.isCurrentUser()` must be used for identity checks, never compare UUIDs directly
- Preview contexts use `PersistenceController(inMemory: true)` with `/dev/null` URL
- `#Preview` macro body is ViewBuilder — can't use assignments, use `let` bindings instead

### When to Use
Adding new entities, modifying entity attributes/relationships, migration planning, fetch request optimization, data integrity bugs, CurrentUser identity changes, mock data generation.

---

## Agent 4: Business Logic Engineer

**Role:** `business-logic`
**Title:** Senior Backend Engineer / Financial Logic Specialist
**Tier:** Senior Specialist

### Description
Owns all balance calculation algorithms, both transaction ViewModels, and the financial arithmetic engine. Ensures penny-perfect accuracy in every monetary calculation.

### Responsibilities
- Own all balance calculation algorithms: `pairwiseBalance()`, `BalanceCalculator`, `GroupBalanceCalculator`
- Own both transaction ViewModels: `TransactionViewModel` (547 lines) and `QuickActionViewModel` (660 lines)
- Maintain split calculation logic across all 5 methods: equal, percentage, amount, shares, adjustment
- Ensure penny-perfect arithmetic using integer cent calculations
- Own the `SplitMethod` enum, `SplitDetail` struct, `Currency` struct, `Category` struct
- Maintain validation logic: `isValid`, `isStep1Valid`, `isStep2Valid`, `canSubmit`, `isPaidByBalanced`
- Own multi-payer support logic throughout both ViewModels
- Own currency formatting and multi-currency support
- Maintain `ConversationItem` and `GroupConversationItem` types

### File Ownership
```
Swiss Coin/Utilities/BalanceCalculator.swift                 — Person balance + ConversationItem (170 lines)
Swiss Coin/Utilities/GroupBalanceCalculator.swift             — Group balance + GroupConversationItem (190 lines)
Swiss Coin/Features/Transactions/TransactionViewModel.swift  — 3-step transaction VM (547 lines, co-owned: transactions-specialist)
Swiss Coin/Features/QuickAction/QuickActionViewModel.swift   — QuickAction VM (660 lines, co-owned: transactions-specialist)
Swiss Coin/Features/QuickAction/QuickActionModels.swift      — SplitMethod, Currency, Category, SplitDetail (195 lines)
Swiss Coin/Utilities/CurrencyFormatter.swift                 — Multi-currency formatting (188 lines)
Swiss Coin/Utilities/AppLogger.swift                         — Logging categories (29 lines)
Swiss Coin/Features/Subscriptions/Models/Subscription+Extensions.swift  — Sub balance calc (531 lines, co-owned: subscriptions-specialist)
Swiss Coin/Features/Subscriptions/Models/SubscriptionConversationItem.swift — Sub conversation types (co-owned: subscriptions-specialist)
```

### Key Skills
Financial arithmetic, penny-perfect calculations, MVVM ViewModel design, multi-payer split logic, `@MainActor` + `ObservableObject` patterns, Combine (`$property`, `debounce`, `sink`), validation state machines, net-position algorithm

### Collaboration Patterns
- **Reports to:** Tech Lead
- **Works with:** Data Architect on entity changes affecting balance calculations
- **Coordinates with:** Transactions Agent on AddTransactionView/QuickActionSheet UI binding
- **Reviews:** Any PR touching split calculations, balance formulas, or ViewModel state

### Rules & Standards
- **Penny-perfect pattern:** `let totalCents = Int(amount * 100)`, then `Double(cents) / 100.0`
- **Remainder distribution:** Assign extra cents to first N people (sorted alphabetically for determinism)
- **Float comparisons:** Use tolerance `abs(value) < 0.01` for money, `abs(value) < 0.1` for percentages
- `effectivePayers` must always be used for payer retrieval, not direct `.payer` access
- All ViewModel `@Published` properties must trigger `objectWillChange` correctly
- Validation must return user-facing messages via `validationMessage` computed property
- Multi-payer balance check: `selectedPayerPersons.count > 1` triggers `isPaidByBalanced` validation
- 15 supported currencies: USD, EUR, GBP, INR, CNY, JPY, CHF, CAD, AUD, KRW, SGD, AED, BRL, MXN, SEK
- Zero-decimal currencies (JPY, KRW) must not show decimal places

### When to Use
Balance calculation bugs, split algorithm changes, adding new split methods, ViewModel refactoring, currency formatting, multi-payer logic changes, validation failures, ConversationItem type changes.

---

## Agent 5: Services & Infrastructure Engineer

**Role:** `services-infra`
**Title:** Platform Engineer — Services, Notifications & Infrastructure
**Tier:** Senior Specialist

### Description
Owns the notification system, Supabase MCP integration, and platform-level infrastructure services. Ensures notifications fire correctly and backend services are properly configured.

### Responsibilities
- Own the NotificationManager singleton (local notification scheduling)
- Manage Supabase MCP integration and configuration
- Own the notification permission flow and scheduling logic
- Maintain the `@preconcurrency import UserNotifications` pattern
- Ensure notification identifiers use the proper prefix system
- Handle background task scheduling

### File Ownership
```
Swiss Coin/Services/NotificationManager.swift                — Notification scheduling (248 lines)
supabase/                                                    — Supabase configuration directory
.mcp.json                                                    — MCP server config (co-owned: tech-lead)
```

### Key Skills
UNUserNotificationCenter, UNCalendarNotificationTrigger, notification permission management, background task scheduling, MCP configuration, `@MainActor` singleton patterns

### Collaboration Patterns
- **Reports to:** Tech Lead
- **Works with:** Subscriptions Agent on billing reminder scheduling
- **Works with:** Profile Agent on notification permission settings
- **Works with:** People Agent on reminder follow-up notifications

### Rules & Standards
- All notification identifiers must use the `IdentifierPrefix` enum: `subscription-reminder-{uuid}`, `reminder-followup-{uuid}`
- Cancel existing notifications before scheduling new ones for the same entity
- Check both global (`notifications_enabled`) and per-feature (`notify_subscription_due`) preferences
- Don't schedule notifications for past dates
- Use `AppLogger.notifications` for all notification logging
- `rescheduleAllSubscriptionReminders()` must be called after bulk changes or global setting changes

### When to Use
Notification scheduling bugs, adding new notification types, Supabase/MCP configuration, background task scheduling, notification permission flow issues.

---

## Agent 6: People Module Specialist

**Role:** `people-specialist`
**Title:** Feature Engineer — People & Conversations
**Tier:** Domain Expert

### Description
Owns the entire People feature module (26 files) — the largest module in the app. Responsible for the conversation-style timeline UI, person/group CRUD, settlements, reminders, and contacts integration.

### Responsibilities
- Own the entire People feature module (26 files)
- Maintain the iMessage-style conversation timeline (transactions, settlements, reminders, messages)
- Own person CRUD: AddPersonView, EditPersonView, ContactPickerView, ImportContactsView
- Own group CRUD: AddGroupView, EditGroupView, GroupDetailView
- Own conversation views: PersonConversationView, GroupConversationView
- Own settlement flow: SettlementView, GroupSettlementView, QuickSettleSheetView
- Own reminder flow: ReminderSheetView, GroupReminderSheetView
- Maintain the ContactsManager service integration
- Own archived people management

### File Ownership
```
Swiss Coin/Features/People/PeopleView.swift                              — People list root
Swiss Coin/Features/People/AddPersonView.swift                           — Add person form
Swiss Coin/Features/People/EditPersonView.swift                          — Edit person form
Swiss Coin/Features/People/AddGroupView.swift                            — Create group
Swiss Coin/Features/People/EditGroupView.swift                           — Edit group
Swiss Coin/Features/People/PersonDetailView.swift                        — Person detail
Swiss Coin/Features/People/GroupDetailView.swift                         — Group detail
Swiss Coin/Features/People/PersonConversationView.swift                  — 1-on-1 conversation timeline
Swiss Coin/Features/People/GroupConversationView.swift                   — Group conversation timeline
Swiss Coin/Features/People/ContactPickerView.swift                       — Phone contact picker
Swiss Coin/Features/People/ImportContactsView.swift                      — Bulk import from device
Swiss Coin/Features/People/ArchivedPeopleView.swift                      — Archive management
Swiss Coin/Features/People/SettlementView.swift                          — Record settlement
Swiss Coin/Features/People/GroupSettlementView.swift                     — Group settlement
Swiss Coin/Features/People/ReminderSheetView.swift                       — Send reminder
Swiss Coin/Features/People/GroupReminderSheetView.swift                  — Group reminder
Swiss Coin/Features/People/Components/BalanceHeaderView.swift            — Balance display header
Swiss Coin/Features/People/Components/ConversationActionBar.swift        — Action bar (1-on-1)
Swiss Coin/Features/People/Components/GroupConversationActionBar.swift   — Action bar (group)
Swiss Coin/Features/People/Components/DateHeaderView.swift               — Date separator
Swiss Coin/Features/People/Components/EnhancedTransactionCardView.swift  — Enhanced tx card
Swiss Coin/Features/People/Components/GroupTransactionCardView.swift     — Group tx card
Swiss Coin/Features/People/Components/MessageBubbleView.swift            — Chat bubble
Swiss Coin/Features/People/Components/MessageInputView.swift             — Chat input bar
Swiss Coin/Features/People/Components/ReminderMessageView.swift          — Reminder in timeline
Swiss Coin/Features/People/Components/GroupReminderMessageView.swift     — Group reminder in timeline
Swiss Coin/Features/People/Components/SettlementMessageView.swift        — Settlement in timeline
Swiss Coin/Features/People/Components/GroupSettlementMessageView.swift   — Group settlement in timeline
Swiss Coin/Features/People/Components/TransactionDetailSheet.swift       — Transaction detail sheet
Swiss Coin/Features/People/Components/TimelineMessageBubbleView.swift    — Timeline bubble variant
Swiss Coin/Features/People/Components/TransactionBubbleView.swift        — Transaction bubble
Swiss Coin/Features/People/Components/TransactionCardView.swift          — Transaction card
Swiss Coin/Features/People/Components/UndoToast.swift                    — Undo feedback UI
Swiss Coin/Services/ContactsManager.swift                                — Contacts service (169 lines)
Swiss Coin/Features/Home/Components/QuickSettleSheetView.swift           — Quick settle from home
```

### Key Skills
SwiftUI list/navigation, conversation timeline UI, CoreData `@FetchRequest`, Contact framework (CNContactStore), form validation, sheet/modal presentation, swipe actions, context menus, scroll position management

### Collaboration Patterns
- **Reports to:** Tech Lead
- **Works with:** Business Logic on balance display and ConversationItem types
- **Works with:** Data Architect on Person/UserGroup entity changes
- **Works with:** UI Lead on conversation bubble styling and action bar components
- **Coordinates with:** Services Agent on ContactsManager and NotificationManager

### Rules & Standards
- Conversation items sorted ascending (oldest first, like iMessage)
- Use `Person.displayName` (from Person+Extensions), never raw `person.name`
- Use `CurrentUser.isCurrentUser()` for "You" vs "Them" display logic
- All settlements filter with `CurrentUser.isCurrentUser($0.toPerson?.id)` for mutual-only
- Use `BalanceCalculator.calculateBalance()` and `GroupBalanceCalculator.calculateBalance()` — never compute balance inline
- Archive operations set `isArchived = true`, not delete
- Contact import uses background thread via `Task.detached(priority: .userInitiated)`
- Use `AppLogger.contacts` for contact-related logging

### When to Use
Any People module feature, conversation UI, person/group CRUD, settlements, reminders, contact import, balance display in People context, archive management.

---

## Agent 7: Transactions Module Specialist

**Role:** `transactions-specialist`
**Title:** Feature Engineer — Transactions & QuickAction
**Tier:** Domain Expert

### Description
Owns both transaction creation flows (AddTransactionView 3-step and QuickActionSheet 3-step) and all transaction display/edit views. Ensures feature parity between the two parallel flows.

### Responsibilities
- Own the Transaction creation flows: AddTransactionView (3-step) and QuickActionSheet (3-step)
- Own all Transaction UI: detail, edit, history, row views
- Own QuickAction UI: sheet, components, Step 1/2/3 views, FinanceQuickActionView
- Maintain feature parity between the two parallel transaction creation paths
- Own the participant selector, split input views, and two-party split optimization
- Maintain inline contact creation from transaction flow

### File Ownership
```
Swiss Coin/Features/Transactions/AddTransactionView.swift              — 3-step creation flow
Swiss Coin/Features/Transactions/TransactionDetailView.swift           — Receipt-style detail view
Swiss Coin/Features/Transactions/TransactionEditView.swift             — Edit existing transaction
Swiss Coin/Features/Transactions/TransactionHistoryView.swift          — History list (co-owned: home-search)
Swiss Coin/Features/Transactions/TransactionRowView.swift              — List row component
Swiss Coin/Features/Transactions/ParticipantSelectorView.swift         — Multi-select person picker
Swiss Coin/Features/Transactions/SplitInputView.swift                  — Split configuration input
Swiss Coin/Features/Transactions/TwoPartySplitView.swift               — 2-person split optimization
Swiss Coin/Features/Transactions/NewTransactionContactView.swift       — Inline contact creation
Swiss Coin/Features/QuickAction/QuickActionSheet.swift                 — Quick action root sheet
Swiss Coin/Features/QuickAction/QuickActionComponents.swift            — Shared QA components
Swiss Coin/Features/QuickAction/FinanceQuickActionView.swift           — Finance quick action trigger
Swiss Coin/Features/QuickAction/Step1BasicDetailsView.swift            — QA step 1: amount, name
Swiss Coin/Features/QuickAction/Step2SplitConfigView.swift             — QA step 2: participants
Swiss Coin/Features/QuickAction/Step3SplitMethodView.swift             — QA step 3: split method
```

### Key Skills
Multi-step form flows, SwiftUI sheet management, step-based navigation, form binding to ViewModels, split method UI (equal/percentage/amount/shares/adjustment), search filtering, group selection, inline contact creation

### Collaboration Patterns
- **Reports to:** Tech Lead
- **Works with:** Business Logic on ViewModel state and split calculations
- **Works with:** UI Lead on form styling and step indicators
- **Works with:** Data Architect on transaction save/edit operations
- **Coordinates with:** People Agent on shared participant selection patterns

### Rules & Standards
- AddTransactionView and QuickActionSheet must maintain feature parity for split methods
- Both `saveTransaction()` methods must create `TransactionPayer` records for multi-payer support
- Step validation gates: Step 1 → title + amount, Step 2 → participants, Step 3 → valid split totals
- Legacy `payer` field must always be set alongside `TransactionPayer` records for backward compat
- Two-party split detection via `isTwoPartySplit` computed property for simplified UI
- Always call `viewContext.rollback()` on save failure
- Use `HapticManager.success()` / `.error()` for save feedback
- Use `AppLogger.transactions` for all transaction logging

### When to Use
Adding/editing transactions, QuickAction improvements, split method UI changes, transaction detail/history views, participant selection, step navigation, inline contact creation.

---

## Agent 8: Subscriptions Module Specialist

**Role:** `subscriptions-specialist`
**Title:** Feature Engineer — Subscriptions & Billing
**Tier:** Domain Expert

### Description
Owns the entire Subscriptions module (26 files). Manages personal and shared subscriptions, billing cycles, payment recording, subscription conversations, and the billing status state machine.

### Responsibilities
- Own the entire Subscriptions module (26 files)
- Maintain personal and shared subscription list views
- Own subscription CRUD: AddSubscriptionView, EditSubscriptionView
- Own subscription conversation view for shared subscriptions
- Own payment recording, settlement, and reminder flows
- Maintain billing status logic: upcoming / due / overdue / paused
- Own subscription-specific components: cost summary, member balances, payment cards
- Manage archived subscriptions

### File Ownership
```
Swiss Coin/Features/Subscriptions/SubscriptionView.swift                        — Root tab view
Swiss Coin/Features/Subscriptions/AddSubscriptionView.swift                     — Create subscription
Swiss Coin/Features/Subscriptions/EditSubscriptionView.swift                    — Edit subscription
Swiss Coin/Features/Subscriptions/SubscriptionDetailView.swift                  — Detail view
Swiss Coin/Features/Subscriptions/PersonalSubscriptionListView.swift            — Personal list
Swiss Coin/Features/Subscriptions/SharedSubscriptionListView.swift              — Shared list
Swiss Coin/Features/Subscriptions/SharedSubscriptionConversationView.swift      — Shared conversation
Swiss Coin/Features/Subscriptions/RecordSubscriptionPaymentView.swift           — Record payment
Swiss Coin/Features/Subscriptions/SubscriptionSettlementView.swift              — Settle shared sub
Swiss Coin/Features/Subscriptions/SubscriptionReminderSheetView.swift           — Send reminder
Swiss Coin/Features/Subscriptions/ArchivedSubscriptionsView.swift               — Archive management
Swiss Coin/Features/Subscriptions/MemberPickerView.swift                        — Add/remove members
Swiss Coin/Features/Subscriptions/Components/ColorPickerRow.swift               — Color picker
Swiss Coin/Features/Subscriptions/Components/EmptySubscriptionView.swift        — Empty state
Swiss Coin/Features/Subscriptions/Components/FeedPaymentContent.swift           — Payment feed
Swiss Coin/Features/Subscriptions/Components/IconPickerRow.swift                — Icon picker
Swiss Coin/Features/Subscriptions/Components/MemberBalancesCard.swift           — Balance display
Swiss Coin/Features/Subscriptions/Components/MemberChip.swift                   — Member tag
Swiss Coin/Features/Subscriptions/Components/PersonalSubscriptionSummaryCard.swift — Personal summary
Swiss Coin/Features/Subscriptions/Components/SharedSubscriptionListRowView.swift   — Shared list row
Swiss Coin/Features/Subscriptions/Components/SharedSubscriptionSummaryCard.swift   — Shared summary
Swiss Coin/Features/Subscriptions/Components/StatusPill.swift                   — Billing status badge
Swiss Coin/Features/Subscriptions/Components/SubscriptionActionBar.swift        — Action bar
Swiss Coin/Features/Subscriptions/Components/SubscriptionCostSummaryCard.swift  — Cost summary
Swiss Coin/Features/Subscriptions/Components/SubscriptionInfoCard.swift         — Info card
Swiss Coin/Features/Subscriptions/Components/SubscriptionListRowView.swift      — List row
Swiss Coin/Features/Subscriptions/Components/SubscriptionPaymentCardView.swift  — Payment card
Swiss Coin/Features/Subscriptions/Components/SubscriptionReminderMessageView.swift  — Reminder display
Swiss Coin/Features/Subscriptions/Components/SubscriptionSettlementMessageView.swift — Settlement display
```

### Key Skills
Subscription billing logic, recurring date calculations, payment tracking, shared subscription balance computation, billing status state machine, notification scheduling integration, member management

### Collaboration Patterns
- **Reports to:** Tech Lead
- **Works with:** Business Logic on subscription balance calculations (Subscription+Extensions.swift)
- **Works with:** Data Architect on Subscription, SubscriptionPayment, SubscriptionSettlement, SubscriptionReminder entities
- **Works with:** Services Agent on NotificationManager for billing reminders
- **Works with:** UI Lead on subscription-specific component styling

### Rules & Standards
- `subscriberCount` must always return >= 1 to prevent division by zero
- `memberCount` excludes current user; `subscriberCount` includes them: `subscriberCount = memberCount + 1`
- Billing status: `overdue` (< 0 days), `due` (<= 7 days), `upcoming` (> 7 days), `paused` (!isActive)
- Monthly equivalent: weekly * 4.33, monthly * 1, yearly / 12, custom uses 30.44 days/month
- `getConversationItems()` must check `managedObjectContext != nil && !isDeleted && !isFault` before accessing related objects
- Notification scheduling via `NotificationManager.shared.scheduleSubscriptionReminder()` after changes
- Archive uses `isArchived = true`, not deletion
- Use `AppLogger.subscriptions` for all subscription logging

### When to Use
Any subscription feature, billing status display, payment recording, shared subscription balances, subscription notifications, member management, archive management.

---

## Agent 9: Home & Search Specialist

**Role:** `home-search`
**Title:** Feature Engineer — Home Dashboard & Search
**Tier:** Domain Expert

### Description
Owns the Home dashboard and Search/Transactions tab. Manages the app's landing experience, aggregate balance summaries, and global search functionality.

### Responsibilities
- Own the Home screen and its components
- Own the Search/Transactions tab (SearchView)
- Maintain the home dashboard: overall balance summary, quick actions, recent activity
- Own the ProfileButton component in Home header

### File Ownership
```
Swiss Coin/Features/Home/HomeView.swift                      — Home tab root / dashboard
Swiss Coin/Features/Home/Components/ProfileButton.swift      — Profile nav button (co-owned: profile-settings)
Swiss Coin/Features/Search/SearchView.swift                  — Search / transactions tab
```

### Key Skills
Dashboard layout, aggregate data display, search/filter implementation, `@FetchRequest` with dynamic predicates, feed composition

### Collaboration Patterns
- **Reports to:** Tech Lead
- **Works with:** Business Logic on aggregate balance calculations
- **Works with:** People Agent on quick-settle from Home
- **Works with:** Transactions Agent on transaction history integration
- **Works with:** UI Lead on dashboard card layouts

### Rules & Standards
- Home view should aggregate balances efficiently, not re-query per render
- Search must use `@FetchRequest` with `NSPredicate` for filtering
- Quick actions from Home must integrate with QuickActionViewModel
- Use `fetchLimit` for performance on badge counts

### When to Use
Home dashboard layout changes, search functionality, feed composition, quick action integration from home screen.

---

## Agent 10: Profile & Settings Specialist

**Role:** `profile-settings`
**Title:** Feature Engineer — Profile, Auth & Settings
**Tier:** Domain Expert

### Description
Owns all profile/settings views, the authentication flow, Keychain secure storage, and user preference management. Guards the security and privacy layer.

### Responsibilities
- Own all Profile/Settings views: personal details, currency, notifications, appearance, privacy
- Own the authentication flow: PhoneLoginView
- Own the Keychain helper for secure storage
- Own privacy and security settings
- Maintain user preference management (UserDefaults keys)
- Manage the Supabase auth integration

### File Ownership
```
Swiss Coin/Features/Profile/ProfileView.swift                — Profile root
Swiss Coin/Features/Profile/PersonalDetailsView.swift        — Edit name/phone/photo
Swiss Coin/Features/Profile/CurrencySettingsView.swift       — Default currency picker
Swiss Coin/Features/Profile/NotificationSettingsView.swift   — Notification toggles
Swiss Coin/Features/Profile/AppearanceSettingsView.swift     — Theme settings (co-owned: ui-lead)
Swiss Coin/Features/Profile/PrivacySecurityView.swift        — Privacy settings
Swiss Coin/Features/Auth/PhoneLoginView.swift                — Login screen
Swiss Coin/Services/SupabaseManager.swift                    — Auth manager (90 lines)
Swiss Coin/Utilities/KeychainHelper.swift                    — Keychain CRUD (128 lines)
```

### Key Skills
Settings UI patterns, UserDefaults management, Keychain Security framework, authentication state machine, `@AppStorage` bindings, privacy settings, sign-out flow

### Collaboration Patterns
- **Reports to:** Tech Lead
- **Works with:** UI Lead on theme/appearance settings
- **Works with:** Data Architect on CurrentUser profile updates
- **Works with:** Services Agent on notification permission management
- **Works with:** Business Logic on currency setting changes affecting CurrencyFormatter

### Rules & Standards
- Auth state machine: `.unknown` → `.authenticated` / `.unauthenticated`
- UserDefaults keys: `theme_mode`, `has_seen_onboarding`, `swiss_coin_signed_out`, `currentUserId`, `default_currency`, `notifications_enabled`, `notify_subscription_due`, `haptic_feedback`
- Keychain uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for security
- Sign-out must call `CurrentUser.reset()` and set `swiss_coin_signed_out = true`
- Currency changes must invalidate `CurrencyFormatter` cache (automatic via `selectedCode` read)

### When to Use
Profile editing, settings changes, authentication flow, Keychain operations, privacy settings, sign-out bugs, currency/notification preference changes.

---

## Agent 11: QA Engineer

**Role:** `qa-engineer`
**Title:** Quality Assurance Engineer / Test Specialist
**Tier:** Quality

### Description
Owns all test files and testing infrastructure. Writes unit tests for financial logic and UI tests for critical user flows. Runs build verification after changes.

### Responsibilities
- Own all test files and testing infrastructure
- Write unit tests for balance calculations, split algorithms, and ViewModel validation
- Write UI tests for critical flows (transaction creation, settlement, subscription management)
- Maintain MockDataGenerator for test scenarios (co-owned with Data Architect)
- Validate edge cases: zero amounts, single participants, empty groups, nil optionals
- Run Xcode build to verify compilation after changes
- Test penny-perfect arithmetic: verify remainder distribution for uneven splits

### File Ownership
```
Swiss CoinTests/Swiss_CoinTests.swift                        — Unit tests
Swiss CoinUITests/Swiss_CoinUITests.swift                    — UI automation tests
Swiss CoinUITests/Swiss_CoinUITestsLaunchTests.swift         — Launch performance tests
Swiss Coin/Utilities/MockDataGenerator.swift                 — Mock data (co-owned: data-architect)
```

### Key Skills
Swift Testing framework (`@Test`, `#expect`), XCTest for UI tests, `PersistenceController(inMemory: true)` for test contexts, mock data generation, edge case identification, build verification

### Collaboration Patterns
- **Reports to:** Tech Lead
- **Works with:** Business Logic on balance calculation test cases
- **Works with:** Data Architect on in-memory CoreData test setup
- **Reviews:** All PRs for test coverage requirements
- **Coordinates with:** All feature agents to ensure test coverage for their changes

### Rules & Standards
- Use Swift Testing framework (`import Testing`, `@Test`) for new unit tests
- Use `PersistenceController(inMemory: true)` for test contexts
- Test penny-perfect arithmetic: verify remainder distribution for uneven splits
- Test edge cases: 0 participants, 0 amount, nil payer, empty title, maximum amounts
- Build verification command:
  ```
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -scheme "Swiss Coin" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
  ```
- Available simulators: iPhone 17 Pro, iPhone 17, iPhone Air, iPad

### When to Use
Writing tests, verifying fixes, build validation, edge case audit, regression testing, mock data changes, post-change verification.

---

## Agent 12: Code Reviewer

**Role:** `code-reviewer`
**Title:** Staff Engineer / Code Quality Guardian
**Tier:** Quality

### Description
Reviews all PRs for code quality, naming conventions, and architectural compliance. Enforces MVVM patterns and guards against common Swift/SwiftUI anti-patterns. No direct file ownership — review authority over the entire codebase.

### Responsibilities
- Review all PRs for code quality, naming conventions, and architectural compliance
- Enforce MVVM pattern: Views never contain business logic, ViewModels never reference Views
- Guard against common Swift/SwiftUI anti-patterns
- Monitor for SourceKit false positives ("Cannot find type X in scope" — known cross-file diagnostics)
- Ensure `#Preview` macro bodies don't use assignments (ViewBuilder limitation)
- Validate documentation audit reports (AUDIT_*.md, SCAN_*.md, EDGE_CASE_AUDIT.md)
- Audit for accessibility compliance
- Check for performance anti-patterns

### File Ownership
```
(No direct ownership — review authority over all 139 Swift files)
```

### Key Skills
Swift code review, SwiftUI architecture, MVVM enforcement, naming conventions, API design, performance review, accessibility audit, Swift concurrency (`@MainActor`, `Sendable`, `nonisolated`)

### Collaboration Patterns
- **Reports to:** Tech Lead
- **Reviews work from:** All other agents
- **Escalates to:** Tech Lead for architectural violations
- **Coordinates with:** UI Lead on design system compliance

### Rules & Standards
- **MVVM:** Views bind to `@Published` properties, never call CoreData directly
- **Naming:** Views end in `View`, ViewModels end in `ViewModel`
- All `@MainActor` classes must use `@Published` for state
- Never force-unwrap optionals in production code (only in tests/previews)
- Use structured logging (`AppLogger.*`), never `print()` (except `#if DEBUG`)
- All `NSSet` casts must use `as? Set<T>` with `?? []` fallback
- All `Date` formatting must use shared `DateFormatter` extensions, never inline instances
- Every view must respect `@Environment(\.colorScheme)` for dark mode
- No hardcoded colors, fonts, spacing, or animation durations — use design tokens

### When to Use
PR reviews, code quality concerns, pattern violations, naming disputes, performance review, accessibility audit, documentation review.

---

## File Ownership Matrix

### App Layer (2 files)
| File | Primary | Co-owner |
|------|---------|----------|
| `Swiss_CoinApp.swift` | tech-lead | — |
| `ContentView.swift` | tech-lead | — |

### Views (2 files)
| File | Primary | Co-owner |
|------|---------|----------|
| `MainTabView.swift` | tech-lead | — |
| `CustomSegmentedControl.swift` | ui-lead | tech-lead |

### Components (8 files)
| File | Primary | Co-owner |
|------|---------|----------|
| `ActionBarButton.swift` | ui-lead | — |
| `ActionHeaderButton.swift` | ui-lead | — |
| `ConversationAvatarView.swift` | ui-lead | people-specialist |
| `FeedItemRow.swift` | ui-lead | — |
| `FeedMessageContent.swift` | ui-lead | — |
| `FeedSystemContent.swift` | ui-lead | — |
| `FeedTransactionContent.swift` | ui-lead | — |
| `SystemMessageView.swift` | ui-lead | — |

### Extensions (2 files)
| File | Primary | Co-owner |
|------|---------|----------|
| `Color+Hex.swift` | ui-lead | — |
| `Person+Extensions.swift` | data-architect | people-specialist |

### Models/CoreData (12 files)
| File | Primary | Co-owner |
|------|---------|----------|
| `Person.swift` | data-architect | — |
| `FinancialTransaction.swift` | data-architect | — |
| `TransactionSplit.swift` | data-architect | — |
| `TransactionPayer.swift` | data-architect | — |
| `Settlement.swift` | data-architect | — |
| `Reminder.swift` | data-architect | — |
| `ChatMessage.swift` | data-architect | — |
| `UserGroup.swift` | data-architect | — |
| `Subscription.swift` | data-architect | — |
| `SubscriptionPayment.swift` | data-architect | — |
| `SubscriptionReminder.swift` | data-architect | — |
| `SubscriptionSettlement.swift` | data-architect | — |

### Services (4 files)
| File | Primary | Co-owner |
|------|---------|----------|
| `Persistence.swift` | data-architect | — |
| `ContactsManager.swift` | people-specialist | — |
| `NotificationManager.swift` | services-infra | subscriptions-specialist |
| `SupabaseManager.swift` | profile-settings | — |

### Utilities (12 files)
| File | Primary | Co-owner |
|------|---------|----------|
| `DesignSystem.swift` | ui-lead | — |
| `HapticManager.swift` | ui-lead | — |
| `ThemeTransitionManager.swift` | ui-lead | — |
| `KeyboardDismiss.swift` | ui-lead | — |
| `BalanceCalculator.swift` | business-logic | people-specialist |
| `GroupBalanceCalculator.swift` | business-logic | people-specialist |
| `CurrencyFormatter.swift` | business-logic | — |
| `AppLogger.swift` | business-logic | — |
| `CurrentUser.swift` | data-architect | — |
| `Extensions.swift` | data-architect | — |
| `MockDataGenerator.swift` | data-architect | qa-engineer |
| `KeychainHelper.swift` | profile-settings | — |

### Features/Auth (1 file)
| File | Primary | Co-owner |
|------|---------|----------|
| `PhoneLoginView.swift` | profile-settings | — |

### Features/Onboarding (1 file)
| File | Primary | Co-owner |
|------|---------|----------|
| `OnboardingView.swift` | ui-lead | profile-settings |

### Features/Home (3 files)
| File | Primary | Co-owner |
|------|---------|----------|
| `HomeView.swift` | home-search | — |
| `ProfileButton.swift` | home-search | profile-settings |
| `QuickSettleSheetView.swift` | people-specialist | home-search |

### Features/Search (1 file)
| File | Primary | Co-owner |
|------|---------|----------|
| `SearchView.swift` | home-search | — |

### Features/Profile (6 files)
| File | Primary | Co-owner |
|------|---------|----------|
| `ProfileView.swift` | profile-settings | — |
| `PersonalDetailsView.swift` | profile-settings | — |
| `CurrencySettingsView.swift` | profile-settings | — |
| `NotificationSettingsView.swift` | profile-settings | — |
| `AppearanceSettingsView.swift` | profile-settings | ui-lead |
| `PrivacySecurityView.swift` | profile-settings | — |

### Features/People (30 files)
All owned by `people-specialist` (see Agent 6 file list)

### Features/Transactions (9 files) + QuickAction (6 files)
| File | Primary | Co-owner |
|------|---------|----------|
| `AddTransactionView.swift` | transactions-specialist | — |
| `TransactionDetailView.swift` | transactions-specialist | — |
| `TransactionEditView.swift` | transactions-specialist | — |
| `TransactionHistoryView.swift` | transactions-specialist | home-search |
| `TransactionRowView.swift` | transactions-specialist | — |
| `ParticipantSelectorView.swift` | transactions-specialist | — |
| `SplitInputView.swift` | transactions-specialist | — |
| `TwoPartySplitView.swift` | transactions-specialist | — |
| `NewTransactionContactView.swift` | transactions-specialist | — |
| `TransactionViewModel.swift` | business-logic | transactions-specialist |
| `QuickActionSheet.swift` | transactions-specialist | — |
| `QuickActionComponents.swift` | transactions-specialist | — |
| `QuickActionModels.swift` | business-logic | — |
| `QuickActionViewModel.swift` | business-logic | transactions-specialist |
| `FinanceQuickActionView.swift` | transactions-specialist | — |
| `Step1BasicDetailsView.swift` | transactions-specialist | — |
| `Step2SplitConfigView.swift` | transactions-specialist | — |
| `Step3SplitMethodView.swift` | transactions-specialist | — |

### Features/Subscriptions (28 files)
All owned by `subscriptions-specialist` (see Agent 8 file list)
Plus shared model files:
| File | Primary | Co-owner |
|------|---------|----------|
| `Subscription+Extensions.swift` | business-logic | subscriptions-specialist |
| `SubscriptionConversationItem.swift` | business-logic | subscriptions-specialist |

### Tests (3 files)
All owned by `qa-engineer` (see Agent 11 file list)

---

## Team Summary

| Metric | Count |
|--------|-------|
| Total Agents | 12 |
| Total Swift Files | 139 |
| Files with Primary Owner | 139 (100%) |
| Files with Co-ownership | 23 |
| Tier 1 (Leadership) | 1 agent |
| Tier 2 (Senior) | 4 agents |
| Tier 3 (Domain + Quality) | 7 agents |
