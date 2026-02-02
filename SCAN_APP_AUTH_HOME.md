# 🔍 SCAN: App / Auth / Home / Navigation

**Audit Date:** 2026-02-02  
**Auditor:** Claude (subagent scan-app-auth-home-v2)  
**Scope:** 7 files — App entry, Auth, Home, Navigation, Components  
**CoreData Reference:** 11 entities (Person, FinancialTransaction, TransactionSplit, Settlement, Reminder, ChatMessage, UserGroup, Subscription, SubscriptionPayment, SubscriptionSettlement, SubscriptionReminder)

---

## 🔑 CoreData Property Violation Summary

| Violation Pattern | Occurrences Found |
|---|---|
| `transaction.paidBy` (should be `transaction.payer`) | **0** ✅ |
| `split.person` (should be `split.owedBy`) | **0** ✅ |
| `split.id` (TransactionSplit has no `id`) | **0** ✅ |
| `transaction.createdAt` (should be `transaction.date`) | **0** ✅ |

**Result:** None of the 7 audited files contain CoreData property name violations. All references use the correct property names. HomeView correctly uses `\FinancialTransaction.date` in its sort descriptor and `\.id` on `FinancialTransaction` (which presumably has an `id` attribute — only `TransactionSplit` lacks one).

---

## File 1: `Swiss Coin/App/Swiss_CoinApp.swift`

### Status: ✅ COMPLETE

### Features / Functionality
- App entry point (`@main`)
- Initializes `PersistenceController.shared` (Core Data stack)
- Injects `managedObjectContext` into SwiftUI environment via `.environment(\.managedObjectContext, ...)`
- Launches `ContentView` as root view

### Issues Found
| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ Low | No error handling if Core Data container fails to load. `PersistenceController.shared` presumably handles this internally, but no fallback UI is shown here if it fails. |
| 2 | ℹ️ Info | No `@Environment(\.scenePhase)` observer — the app doesn't save context on backgrounding at this level. Relies on `PersistenceController` to handle saves. |

### Edge Cases Not Handled
- Core Data migration failure on app update (no lightweight migration error UI)
- Extremely low-memory situations where the persistent store might not load

### Dependencies
- `PersistenceController` (Core Data stack, must expose `.shared` and `.container`)
- `ContentView`

---

## File 2: `Swiss Coin/App/ContentView.swift`

### Status: ✅ COMPLETE

### Features / Functionality
- Root authentication router — switches UI based on `supabase.authState`
- States handled:
  - `.unknown` → `ProgressView("Loading...")`
  - `.authenticated` → `MainTabView()`
  - `.unauthenticated` / `.verifyingOTP` → `PhoneLoginView()`
- Animated transitions via `AppAnimation.standard`
- Injects Core Data context via preview

### Issues Found
| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ Medium | **`.verifyingOTP` routes to `PhoneLoginView`** — If OTP verification is a separate step, the user might expect a dedicated OTP input screen, not a re-render of the phone login screen. PhoneLoginView itself has no OTP input field. This means after requesting an OTP, the user is shown the same phone entry screen with no indication that an OTP was sent and needs to be entered. |
| 2 | ⚠️ Low | `SupabaseManager.shared` is used as `@StateObject` — if `ContentView` is ever recreated (unlikely as root), this could re-initialize. Should be fine given it's a singleton `.shared`, but `@StateObject` with a singleton is an antipattern; `@ObservedObject` or `@EnvironmentObject` would be more correct since the lifecycle isn't owned by this view. |
| 3 | ℹ️ Info | No timeout for the `.unknown` loading state. If auth check hangs, user sees infinite spinner. |
| 4 | ℹ️ Info | Hardcoded string `"Loading..."` — should be a localized constant. |

### Edge Cases Not Handled
- Network failure during auth state check (stuck on `.unknown` forever)
- Token refresh failure (what state does SupabaseManager transition to?)
- Deep link / Universal link handling (no `onOpenURL`)

### Dependencies
- `SupabaseManager` (must expose `.shared`, `.authState` as `@Published`, `.signInWithPhone()`)
- `MainTabView`
- `PhoneLoginView`
- `AppAnimation.standard`
- `PersistenceController.preview` (preview only)

---

## File 3: `Swiss Coin/Features/Auth/PhoneLoginView.swift`

### Status: 🔧 PARTIAL

### Features / Functionality
- Phone number input with country code picker
- Country code dropdown menu (10 hardcoded codes)
- Phone number field with keyboard type `.phonePad` and `.telephoneNumber` content type
- Input filtering: allows digits, dashes, spaces, parentheses
- Basic validation: ≥ 7 digits required
- Sign-in button with loading state
- Error alert display
- Legal terms text (non-interactive)
- Constructs full phone number: `countryCode + digits`

### Issues Found
| # | Severity | Issue |
|---|----------|-------|
| 1 | 🔴 High | **No OTP verification step.** The view calls `supabase.signInWithPhone()` but has no UI for entering the OTP code that Supabase sends. The `ContentView` routes `.verifyingOTP` back to this same view, but there's no OTP input field, no "Enter code" section, nothing. **Users cannot complete sign-in.** Either the OTP flow is handled entirely by `SupabaseManager` (auto-verify via push?) or this is a critical missing feature. |
| 2 | 🔴 High | **`SupabaseManager.shared` used as `@StateObject`** — This creates a NEW `@StateObject` wrapper each time. Since `SupabaseManager.shared` is a singleton, the view gets its own observation. If `ContentView` also observes the same singleton, the state should sync. However, this is still an antipattern — both views create independent `@StateObject` wrappers for the same object. |
| 3 | ⚠️ Medium | **Missing Switzerland country code `+41`** in `countryCodes` array — ironic for an app called "Swiss Coin". The hardcoded list is `["+1", "+44", "+91", "+61", "+81", "+86", "+49", "+33", "+39", "+34"]`. |
| 4 | ⚠️ Medium | **No maximum phone number length validation.** User can enter unlimited characters. |
| 5 | ⚠️ Medium | **Terms of Service and Privacy Policy text is non-tappable.** It says "By signing in, you agree to our Terms of Service and Privacy Policy" but these are plain text, not links. Users can't actually view the terms. |
| 6 | ⚠️ Low | **Input filter allows formatting characters** (`-`, `(`, `)`, space) but `fullPhoneNumber` strips them to digits only. The filter is inconsistent — why allow them in the display if they're stripped for submission? |
| 7 | ⚠️ Low | **Phone validation is simplistic.** Only checks ≥ 7 digits. No per-country validation (e.g., US numbers should be 10 digits, UK 10-11, etc.). |
| 8 | ⚠️ Low | **Country codes have no labels/flags.** The menu shows raw strings like "+1" without country names or flag emojis, making it difficult for users to find their country. |
| 9 | ℹ️ Info | All strings are hardcoded (not localized). |
| 10 | ℹ️ Info | `countryCode` defaults to `"+1"` (US). For a Swiss app, `"+41"` would be a better default. |

### Edge Cases Not Handled
- Rate limiting (user can spam the sign-in button rapidly despite `isLoading` guard — race condition possible on fast taps)
- Phone numbers with leading zeros after country code
- User pastes a full international number including country code into the phone field
- Keyboard dismissal (no `.onTapGesture` to dismiss keyboard on background tap)
- VoiceOver: country code picker accessibility could be improved

### Dependencies
- `SupabaseManager` (`.shared`, `.signInWithPhone(phoneNumber:)`)
- Design system: `AppColors`, `AppTypography`, `Spacing`, `CornerRadius`, `IconSize`

---

## File 4: `Swiss Coin/Features/Home/HomeView.swift`

### Status: ✅ COMPLETE (with minor issues)

### Features / Functionality
- **Summary Section:** Horizontal scroll with two `SummaryCard`s — "You Owe" (negative balances) and "You are Owed" (positive balances)
- **Balance Calculation:** Iterates all `Person` entities, filters out current user, calls `person.calculateBalance()`, partitions into owe/owed
- **Recent Activity:** Shows last 5 transactions via `recentTransactions` computed property
- **Empty State:** `EmptyStateView` when no transactions exist
- **Navigation:** "See All" links to `TransactionHistoryView`
- **Profile Access:** Toolbar button opens `ProfileView` sheet
- **Quick Action FAB:** `FinanceQuickActionView()` overlay for adding transactions
- **Core Data Integration:** Two `@FetchRequest`s — all transactions (sorted by date desc) and all people (sorted by name)
- **Sub-components:** `EmptyStateView`, `SummaryCard` (both defined in-file)

### Issues Found
| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ Medium | **Performance: Fetches ALL transactions** but only uses 5. The `@FetchRequest` has no `fetchLimit`. Comment says "limited at fetch level" but the predicate fetches everything, then `Array(allTransactions.prefix(5))` takes 5. With thousands of transactions, this wastes memory. Should add `fetchLimit = 5` to the `NSFetchRequest`. |
| 2 | ⚠️ Medium | **Balance calculation iterates ALL people on every render.** `totalYouOwe` and `totalOwedToYou` are computed properties recalculated on every view body evaluation. For large datasets, this could be slow. Consider caching or using `@State`. |
| 3 | ⚠️ Low | **`CurrentUser.isCurrentUser($0.id)`** — if `Person.id` is nil (optional UUID?), this could behave unexpectedly. No nil guard on person id. |
| 4 | ⚠️ Low | **`ForEach(recentTransactions, id: \.id)`** — uses `\.id` on `FinancialTransaction`. This is fine since `FinancialTransaction` presumably has an `id` attribute (unlike `TransactionSplit`). But if `id` is optional, ForEach could have issues with nil ids. |
| 5 | ℹ️ Info | `SummaryCard` has a fixed width of `160` — not adaptive to dynamic type or different screen sizes. |
| 6 | ℹ️ Info | Hardcoded strings: "Summary", "You Owe", "You are Owed", "Recent Activity", "See All", "No recent activity", "Transactions you add will appear here.", "Home" — none localized. |

### CoreData Property Check
- ✅ Uses `\FinancialTransaction.date` (correct, not `.createdAt`)
- ✅ Uses `\Person.name` (correct)
- ✅ No references to `paidBy`, `split.person`, `split.id`, or `createdAt`

### Edge Cases Not Handled
- What happens if `person.calculateBalance()` returns `NaN` or `infinity`?
- No pull-to-refresh
- No error state if Core Data fetch fails
- `CurrencyFormatter.format(amount)` — what if amount is extremely large?

### Dependencies
- **Core Data entities:** `FinancialTransaction`, `Person`
- **Helper classes:** `CurrentUser`, `CurrencyFormatter`
- **Views:** `TransactionRowView`, `TransactionHistoryView`, `ProfileView`, `FinanceQuickActionView`, `ProfileButton`
- **Design system:** `AppColors`, `AppTypography`, `Spacing`, `CornerRadius`, `IconSize`

---

## File 5: `Swiss Coin/Features/Home/Components/ProfileButton.swift`

### Status: ✅ COMPLETE

### Features / Functionality
- Circular profile button with SF Symbol `person.circle.fill`
- Custom `ProfileButtonStyle` with:
  - Scale-down effect on press (0.92)
  - `AppAnimation.quick` spring animation
  - Haptic feedback via `HapticManager.lightTap()` on press
- Accessibility label "Profile"
- Configurable action closure

### Issues Found
| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ Low | **Haptic fires on EVERY press start**, including cancelled taps (e.g., user presses then drags away). The `onChange(of: configuration.isPressed)` triggers `HapticManager.lightTap()` whenever `isPressed` becomes true, even if the button action never fires. Standard practice is to fire haptic on the action, not on press-down. |
| 2 | ℹ️ Info | `AvatarSize.xs - 2` for font size is a magic number adjustment. |
| 3 | ℹ️ Info | No dynamic user avatar — always shows generic person icon. Future feature: show user's profile photo. |

### Edge Cases Not Handled
- Dark mode: the two-tone `foregroundStyle` might not contrast well on all backgrounds
- Dynamic Type: fixed `AvatarSize.xs` dimensions don't scale with accessibility text sizes

### Dependencies
- `AppColors`, `AppAnimation`, `AvatarSize`
- `HapticManager` (must expose `.lightTap()`)

---

## File 6: `Swiss Coin/Views/MainTabView.swift`

### Status: ✅ COMPLETE

### Features / Functionality
- Bottom tab bar with 4 tabs:
  1. **Home** (`house.fill`) → `HomeView()`
  2. **People** (`person.2.fill`) → `PeopleView()`
  3. **Subscriptions** (`creditcard.fill`) → `SubscriptionView()`
  4. **History** (`clock.fill`) → `TransactionHistoryView()`
- Tint color set to `AppColors.accent`

### Issues Found
| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ Low | **No `@State` for selected tab.** SwiftUI `TabView` without explicit selection binding means programmatic tab switching (e.g., from deep links or notifications) is impossible. |
| 2 | ⚠️ Low | **Duplicate access to TransactionHistoryView.** Both `HomeView` (via "See All" NavigationLink) and the History tab show `TransactionHistoryView`. This is intentional but means the same view is navigable from two places, which could cause confusion if one has different navigation context. |
| 3 | ℹ️ Info | No badge support on tabs (e.g., unread count). |
| 4 | ℹ️ Info | Tab labels are hardcoded strings, not localized. |

### Edge Cases Not Handled
- State preservation when switching tabs (each tab's navigation state resets)
- iPad: no sidebar adaptation for larger screens
- No handling for deep link routing to specific tabs

### Dependencies
- `HomeView`, `PeopleView`, `SubscriptionView`, `TransactionHistoryView`
- `AppColors.accent`

---

## File 7: `Swiss Coin/Views/Components/CustomSegmentedControl.swift`

### Status: 🔧 PARTIAL

### Features / Functionality
- Custom segmented control replacing SwiftUI's `Picker` with `.segmented` style
- `@Binding var selection: Int` for current selection index
- `MatchedGeometryEffect` for smooth animated selection indicator
- Spring animation (response: 0.3, dampingFraction: 0.7)
- Shadow on selected segment
- Dark mode preview provided

### Issues Found
| # | Severity | Issue |
|---|----------|-------|
| 1 | ⚠️ Medium | **Does NOT use the app's design system.** Uses raw SwiftUI colors (`Color(uiColor: .tertiarySystemGroupedBackground)`, `.primary`, `.secondary`) and raw font modifiers (`.font(.subheadline)`, `.fontWeight(.medium)`) instead of `AppColors` and `AppTypography`. Every other file in this audit uses the design system consistently. This component is inconsistent. |
| 2 | ⚠️ Low | **Uses `Int` selection instead of a generic/enum type.** This means call sites need to do index-to-value mapping manually. A `Hashable` generic type would be more Swifty. |
| 3 | ⚠️ Low | **No accessibility support.** Missing `accessibilityLabel`, `accessibilityAddTraits(.isSelected)` for the active segment, and `accessibilityValue`. |
| 4 | ℹ️ Info | Uses deprecated `PreviewProvider` pattern instead of the modern `#Preview` macro used in other files. |
| 5 | ℹ️ Info | Hardcoded padding values (`4`, `8`) and corner radius (`8`, `10`) instead of using `Spacing` and `CornerRadius` constants. |
| 6 | ℹ️ Info | No haptic feedback on segment change (contrast with `ProfileButton` which has haptics). |

### Edge Cases Not Handled
- Empty `options` array → renders empty bar (should show nothing or assert)
- Single option → renders one segment with no visual purpose
- Very long option strings → no truncation, could overflow
- Dynamic Type: fixed padding doesn't scale
- RTL languages: `HStack` should work but not tested

### Dependencies
- None (fully self-contained, doesn't use app's design system)

---

## 📊 Cross-File Analysis

### Architecture Pattern
The app follows a clear pattern:
```
Swiss_CoinApp → ContentView (auth router) → MainTabView → [HomeView, PeopleView, SubscriptionView, TransactionHistoryView]
                                          → PhoneLoginView (when unauthenticated)
```

### Shared Singleton Antipattern
`SupabaseManager.shared` is used as `@StateObject` in **both** `ContentView` and `PhoneLoginView`. This means two independent `@StateObject` wrappers observe the same singleton. While functional, the correct pattern would be:
- One `@StateObject` at the top level (or `@ObservedObject` / `@EnvironmentObject`)
- Pass down via `.environmentObject()`

### Design System Compliance
| File | Uses AppColors | Uses AppTypography | Uses Spacing/CornerRadius |
|------|---------------|-------------------|---------------------------|
| Swiss_CoinApp.swift | N/A | N/A | N/A |
| ContentView.swift | N/A | N/A | N/A |
| PhoneLoginView.swift | ✅ | ✅ | ✅ |
| HomeView.swift | ✅ | ✅ | ✅ |
| ProfileButton.swift | ✅ | N/A | N/A |
| MainTabView.swift | ✅ (accent only) | N/A | N/A |
| **CustomSegmentedControl.swift** | ❌ Raw UIColors | ❌ Raw fonts | ❌ Raw values |

### Unresolved External Dependencies
These are referenced but not included in this audit:
- `SupabaseManager` — auth state machine, phone sign-in, session management
- `PersistenceController` — Core Data stack
- `CurrentUser` — current user identification
- `CurrencyFormatter` — amount formatting
- `HapticManager` — haptic feedback
- `TransactionRowView` — transaction list row
- `TransactionHistoryView` — full transaction list
- `ProfileView` — user profile screen
- `FinanceQuickActionView` — FAB for adding transactions
- `PeopleView` — people list screen
- `SubscriptionView` — subscriptions screen
- Design system: `AppColors`, `AppTypography`, `AppAnimation`, `Spacing`, `CornerRadius`, `IconSize`, `AvatarSize`

---

## 🚨 Priority Fix List

### 🔴 Critical (Blocks Core Functionality)
1. **No OTP verification UI** — `PhoneLoginView` sends OTP but has no field to enter it. Users cannot complete authentication unless `SupabaseManager` handles this automatically (e.g., via push notification auto-verify or magic link).

### 🟡 Important (Should Fix Before Release)
2. **Missing `+41` Swiss country code** in PhoneLoginView — a Swiss app without Switzerland's code.
3. **HomeView fetches ALL transactions** without `fetchLimit` — performance issue at scale.
4. **CustomSegmentedControl doesn't use design system** — visual inconsistency risk.
5. **No timeout/retry for auth loading state** — user can be stuck on spinner forever.
6. **Terms of Service not tappable** — potential legal/compliance issue.

### 🟢 Nice to Have (Post-Release)
7. Add `@State` selection to `MainTabView` for deep link / programmatic navigation.
8. Add pull-to-refresh to `HomeView`.
9. Cache balance calculations in `HomeView`.
10. Localize all hardcoded strings.
11. Add country names/flags to phone code picker.
12. Add accessibility traits to `CustomSegmentedControl`.
13. Migrate `CustomSegmentedControl` previews to `#Preview` macro.
14. Add user avatar support to `ProfileButton`.

---

*End of scan. 7 files audited. 0 CoreData property violations. 1 critical issue (OTP flow). 5 important issues. 8 nice-to-haves.*
