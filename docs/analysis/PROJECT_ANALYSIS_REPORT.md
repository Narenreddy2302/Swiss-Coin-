# 📋 PROJECT ANALYSIS REPORT — Swiss Coin iOS App
**Date:** 2026-02-02
**Analyst:** Nana (AI Development Agent)
**Source:** 5 parallel deep-scan agents covering 103 Swift files + CoreData schema

---

## 1. Tech Stack Summary

| Component | Technology |
|-----------|-----------|
| **Platform** | iOS (SwiftUI) |
| **Language** | Swift |
| **UI Framework** | SwiftUI (NavigationView/NavigationStack mixed) |
| **Data Layer** | CoreData (`NSPersistentContainer` named "Swiss_Coin") |
| **Backend** | Supabase (placeholder credentials — not connected) |
| **Auth** | Supabase Phone OTP (partially implemented) |
| **Package Manager** | None (no SPM/CocoaPods dependencies) |
| **Build System** | Xcode 16 (PBXFileSystemSynchronizedRootGroup) |
| **Frameworks Used** | SwiftUI, CoreData, Combine, UIKit, LocalAuthentication, Security, Contacts, ContactsUI, PhotosUI, CryptoKit, UserNotifications |
| **Total Swift Files** | 103 |
| **Total Lines of Code** | ~21,238 |
| **CoreData Entities** | 11 |

---

## 2. Architecture Overview

```
Swiss_CoinApp (entry point)
  └── ContentView (auth router)
        ├── PhoneLoginView (unauthenticated)
        └── MainTabView (authenticated)
              ├── Tab 1: HomeView
              │     ├── SummaryCards (You Owe / You Are Owed)
              │     ├── Recent Transactions (last 5)
              │     ├── → TransactionHistoryView
              │     ├── → ProfileView (sheet)
              │     └── FinanceQuickActionView (FAB overlay)
              ├── Tab 2: PeopleView
              │     ├── People segment → PersonConversationView → Settlement/Reminder
              │     └── Groups segment → GroupConversationView → Settlement/Reminder
              ├── Tab 3: SubscriptionView
              │     ├── Personal → SubscriptionDetailView
              │     └── Shared → SharedSubscriptionConversationView
              └── Tab 4: TransactionHistoryView
```

**Design System:** Centralized in `DesignSystem.swift` — AppColors, AppTypography, Spacing, CornerRadius, IconSize, AvatarSize, ButtonHeight, AppAnimation, PrimaryButtonStyle, AppButtonStyle

**Data Flow:** CoreData (local) ←→ SupabaseManager (sync, currently placeholder)

---

## 3. Feature Registry

### ✅ COMPLETE (82 files)
Core functionality is built and working for: Home dashboard, People list, Group management, Person/Group conversation views, Transaction creation (two flows), Split calculations (5 methods), Subscription management (personal + shared), Settlement recording, Reminder sending, Chat messages, Profile settings, Design system, CoreData models, Balance calculations, Currency formatting, Contact import

### 🔧 PARTIAL (13 files)
| File | What's Missing |
|------|---------------|
| PhoneLoginView | No OTP verification UI — users can't complete sign-in |
| NewTransactionContactView | Navigation goes to PersonDetail instead of AddTransaction |
| QuickActionViewModel | Group member-adding commented out; error states never shown; currentUserUUID generates random UUIDs |
| CustomSegmentedControl | Doesn't use design system; no accessibility |
| PersonalDetailsView | US phone formatting in Swiss app |
| CurrencySettingsView | Selection not connected to CurrencyFormatter |
| SubscriptionSettlementView | Balance direction may be inconsistent |
| RecordSubscriptionPaymentView | billingPeriodStart/End never populated |
| Step2SplitConfigView | Group selection non-functional (commented out) |
| PrivacySecurityView | Unsalted PIN hash |
| SupabaseManager | Infinite 401 retry loop; placeholder creds; unstable UUID generation |
| CurrencyFormatter | Hardcoded CHF, ignores user currency preference |
| MockDataGenerator | Test utility only |

### ❌ MISSING (Not Built)
| Feature | Evidence |
|---------|---------|
| OTP verification screen | No UI exists for entering OTP code after phone submit |
| Transaction edit/detail view | `showTransactionDetails()` is a TODO stub |
| Transaction delete | No delete flow exists |
| Person/Group edit | No edit capability after creation |
| Person/Group delete | No delete flow |
| Search functionality | Tab 4 is TransactionHistory, no global search |
| Push notifications | NotificationSettingsView is UI-only, no actual notification scheduling |
| Supabase sync | All CRUD is local CoreData only |
| Onboarding flow | No first-run experience |

### 🐛 BUGGY (3 files)
| File | Bug |
|------|-----|
| SupabaseManager | Infinite retry loop on 401; `String.hashValue` for UUID is non-deterministic |
| CurrencyFormatter | Hardcoded CHF ignores user's currency selection |
| QuickActionViewModel | `currentUserUUID` generates random UUID per access if CurrentUser not initialized |

---

## 4. Identified Bugs & Technical Debt

### 🔴 CRITICAL (9 issues — would crash or break core functionality)

| # | Issue | Location | Impact |
|---|-------|----------|--------|
| C1 | **No OTP verification UI** | PhoneLoginView | Users cannot complete authentication |
| C2 | **Duplicate SplitMethod enums with different raw values** | TransactionViewModel vs QuickActionModels | Transactions saved with inconsistent splitMethod strings in CoreData |
| C3 | **Group member-adding commented out** | QuickActionViewModel.selectGroup() | Group selection in QuickAction does nothing |
| C4 | **currentUserUUID generates random UUID** | QuickActionViewModel | Participant matching breaks; "You" is different person each access |
| C5 | **Infinite 401 retry loop** | SupabaseManager | Stack overflow when refresh token is also expired |
| C6 | **Unsalted SHA256 for PIN** | PrivacySecurityView | 6-digit PIN trivially brute-forceable |
| C7 | **CurrencyFormatter hardcoded to CHF** | CurrencyFormatter | Ignores user's currency selection entirely |
| C8 | **`String.hashValue` for UUID generation** | SupabaseManager | Not stable across app launches — sessions break on restart |
| C9 | **Error states never displayed** | QuickActionViewModel | Save failures are silent — user loses data with no feedback |

### 🟡 IMPORTANT (18 issues — should fix before release)

| # | Issue | Location |
|---|-------|----------|
| I1 | Missing Swiss +41 country code | PhoneLoginView |
| I2 | HomeView fetches ALL transactions (no fetchLimit) | HomeView |
| I3 | TransactionType/Category/Currency collected but never persisted | QuickAction flow |
| I4 | Two parallel transaction flows with duplicated logic | AddTransactionView vs QuickAction |
| I5 | `billingPeriodStart`/`End` completely unused | SubscriptionPayment |
| I6 | `markAsPaid()` advances billing date but creates no payment record | SubscriptionListRowView |
| I7 | Paused subscriptions still contribute to balance calculations | Subscription+Extensions |
| I8 | Phone formatting inconsistency (US vs Swiss) | PersonalDetailsView vs Person+Extensions |
| I9 | HapticManager ignores user's disable preference | HapticManager + AppearanceSettingsView |
| I10 | Default color inconsistencies (5 different defaults) | Multiple files |
| I11 | Terms of Service not tappable | PhoneLoginView |
| I12 | Hardcoded "$" in multiple input fields | AddSubscription, EditSubscription, etc. |
| I13 | Non-split transaction creates self-owed split | QuickActionViewModel |
| I14 | `SubscriptionReminder.isRead` never toggled to true | SubscriptionReminderSheetView |
| I15 | Duplicate contact import (no dedup check) | ImportContactsView, AddPersonView |
| I16 | Stub context menu actions (Share/View Details) | PeopleView |
| I17 | No auth loading timeout | ContentView |
| I18 | Settlement over-payment allowed with no validation | SubscriptionSettlementView |

### 🟢 MINOR (20+ issues — polish items)

Deprecated APIs (`NavigationView`, `presentationMode`), missing accessibility labels, hardcoded strings not localized, missing empty states, missing CHF in currency list, integer division for percentages, inconsistent design system usage in CustomSegmentedControl, DateFormatter created per-render, magic numbers throughout, etc.

---

## 5. Proposed Execution Plan

### PRIORITY 1 — Critical Path (Blocks Core Usage)
| # | Task | Complexity | Est. Effort |
|---|------|-----------|-------------|
| 1.1 | Fix OTP verification flow (add code input UI) | Medium | ~200 lines |
| 1.2 | Unify SplitMethod enums (single source of truth) | Low | ~50 lines |
| 1.3 | Fix QuickAction group member-adding | Low | ~20 lines (uncomment + verify) |
| 1.4 | Fix currentUserUUID to use stable identifier | Low | ~10 lines |
| 1.5 | Add recursion guard to SupabaseManager 401 retry | Low | ~15 lines |
| 1.6 | Fix CurrencyFormatter to respect user selection | Medium | ~80 lines |
| 1.7 | Surface error states in QuickActionViewModel | Low | ~30 lines |

### PRIORITY 2 — Core Feature Completion
| # | Task | Complexity | Est. Effort |
|---|------|-----------|-------------|
| 2.1 | Connect currency selection to CurrencyFormatter | Medium | ~100 lines |
| 2.2 | Add +41 Swiss country code + flags to phone picker | Low | ~30 lines |
| 2.3 | Fix PIN security (add salt + PBKDF2) | Medium | ~60 lines |
| 2.4 | Populate billingPeriodStart/End on payments | Low | ~20 lines |
| 2.5 | Fix markAsPaid to create payment record | Low | ~30 lines |
| 2.6 | Filter paused subscriptions from balance calcs | Low | ~10 lines |
| 2.7 | Fix HapticManager to check user preference | Low | ~15 lines |
| 2.8 | Unify default colors to single source | Low | ~20 lines |

### PRIORITY 3 — Supporting Features
| # | Task | Complexity | Est. Effort |
|---|------|-----------|-------------|
| 3.1 | Add HomeView fetchLimit for performance | Low | ~5 lines |
| 3.2 | Fix phone formatting to Swiss standard | Low | ~20 lines |
| 3.3 | Add dedup check on contact import | Medium | ~40 lines |
| 3.4 | Fix self-owed split on non-split transactions | Low | ~15 lines |
| 3.5 | Replace "$" hardcoded symbols with CurrencyFormatter | Low | ~30 lines |
| 3.6 | Add settlement amount validation (cap at balance) | Low | ~20 lines |
| 3.7 | Toggle SubscriptionReminder.isRead on view | Low | ~10 lines |

### PRIORITY 4 — Polish & Optimization
| # | Task | Complexity | Est. Effort |
|---|------|-----------|-------------|
| 4.1 | Migrate deprecated NavigationView → NavigationStack | Medium | ~100 lines |
| 4.2 | Replace deprecated presentationMode → dismiss | Low | ~20 lines |
| 4.3 | Add accessibility labels across all views | Medium | ~200 lines |
| 4.4 | Update CustomSegmentedControl to use design system | Low | ~30 lines |
| 4.5 | Add empty states where missing | Low | ~50 lines |
| 4.6 | Cache balance calculations in HomeView | Medium | ~40 lines |

### PRIORITY 5 — Edge Cases & Hardening
| # | Task | Complexity | Est. Effort |
|---|------|-----------|-------------|
| 5.1 | Add auth loading timeout with retry | Low | ~20 lines |
| 5.2 | Add Terms of Service tappable links | Low | ~15 lines |
| 5.3 | Handle subscription deleted while viewing | Low | ~20 lines |
| 5.4 | Add over-settlement warning | Low | ~15 lines |
| 5.5 | Fix String.hashValue UUID generation | Low | ~10 lines |

---

## 6. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Auth flow broken** (no OTP UI) | 🔴 HIGH | P1 fix — users literally cannot sign in |
| **Data inconsistency** (dual SplitMethod enums) | 🔴 HIGH | P1 fix — unify enums before any data is created |
| **Silent data loss** (QuickAction errors hidden) | 🟡 MEDIUM | P1 fix — surface error alerts |
| **Supabase not connected** | 🟡 MEDIUM | Out of scope per Naren — app works offline-first |
| **PIN security weak** | 🟡 MEDIUM | P2 fix — low risk if device is locked anyway |
| **Currency display wrong** | 🟡 MEDIUM | P1-P2 fix — cosmetic but confusing |
| **No tests** | 🟡 MEDIUM | Can't be addressed without Xcode build capability |
| **No CI/CD** | 🟢 LOW | Out of scope for now |
| **Deprecated APIs** | 🟢 LOW | P4 polish — works but generates warnings |

---

## 7. Questions for Product Owner

1. **Auth flow:** Is Supabase OTP supposed to auto-verify (e.g., via deep link/push), or do we need to build an OTP input screen? This is the #1 blocker.

2. **Currency:** The app is called "Swiss Coin" but CHF isn't in the currency picker, CurrencyFormatter is hardcoded to CHF, and the phone picker doesn't include +41. Should we standardize everything to Swiss defaults, or is this a multi-currency app?

3. **Two transaction flows:** There's `AddTransactionView` (form-based) AND the QuickAction wizard (step-by-step). Do you want both, or should we consolidate into one?

4. **Supabase:** Credentials are placeholder. Is backend sync planned for this release, or is offline-first (CoreData only) the target?

5. **Missing features:** Transaction edit/delete, Person/Group edit/delete, push notifications — are any of these expected for v1?

---

*Based on my analysis, here is the current state of the project and my proposed plan. Do you have any priorities, constraints, or context I should factor in before I begin execution?*
