# Dark Mode / Light Mode Consistency Audit — Changes Summary

**Date:** 2026-02-02  
**Scope:** Complete codebase audit for hardcoded colors that break in light or dark mode

---

## Design System Changes (`Swiss Coin/Utilities/DesignSystem.swift`)

### Colors Updated to be Fully Adaptive

| Color Token | Before | After | Reason |
|---|---|---|---|
| `cardBackground` | `Color(UIColor.systemGray6).opacity(0.3)` | `Color(UIColor.secondarySystemBackground)` | Was too transparent and inconsistent; now uses proper semantic background |
| `cardBackgroundElevated` | `Color(UIColor.systemGray5)` | `Color(UIColor.tertiarySystemBackground)` | Now uses semantic elevation hierarchy |
| `textPrimary` | `Color.primary` | `Color(.label)` | Explicit UIKit semantic label color for maximum compatibility |
| `textSecondary` | `Color.secondary` | `Color(.secondaryLabel)` | Explicit UIKit semantic secondary label |
| `otherBubble` | `Color(UIColor.systemGray5)` | `Color(UIColor.secondarySystemBackground)` | Better semantic meaning for received message bubbles |
| `disabled` | `Color.secondary.opacity(0.4)` | `Color(.secondaryLabel).opacity(0.4)` | Matches updated textSecondary base |

### New Tokens Added

| Token | Value | Purpose |
|---|---|---|
| `groupedBackground` | `Color(.systemGroupedBackground)` | For grouped list/table backgrounds |
| `separator` | `Color(.separator)` | For dividers and borders |
| `shadow` | `Color(.label).opacity(0.08)` | Adaptive shadow color that works in both modes |

---

## Files Changed

### 1. `Swiss Coin/Features/Subscriptions/SharedSubscriptionConversationView.swift`
**Critical fix — worst offender with 3x `Color.black`**

| Line | Before | After |
|---|---|---|
| 87 | `.background(Color.black)` (ScrollView) | `.background(AppColors.background)` |
| 117 | `.background(Color.black)` (VStack) | `.background(AppColors.background)` |
| 120 | `.toolbarBackground(Color.black, for: .navigationBar)` | `.toolbarBackground(AppColors.backgroundSecondary, for: .navigationBar)` |
| 121 | `.tint(Color(UIColor.systemGray))` | `.tint(AppColors.textSecondary)` |
| 175 | `.foregroundColor(Color(UIColor.systemGray))` (back button) | `.foregroundColor(AppColors.textSecondary)` |
| 206 | `.foregroundColor(.white)` (subscription name) | `.foregroundColor(AppColors.textPrimary)` |
| 210 | `.foregroundColor(Color(UIColor.systemGray))` (member count) | `.foregroundColor(AppColors.textSecondary)` |
| 220 | `.foregroundColor(Color(UIColor.systemGray))` (balance label) | `.foregroundColor(AppColors.textSecondary)` |

### 2. `Swiss Coin/Features/People/Components/ConversationActionBar.swift`
| Line | Before | After |
|---|---|---|
| 94 | `.foregroundColor(.black)` (plus icon on green circle) | `.foregroundColor(.white)` |
| 115 | `.strokeBorder(AppColors.cardBackground, ...)` | `.strokeBorder(AppColors.separator, ...)` |

### 3. `Swiss Coin/Features/People/GroupConversationView.swift`
| Line | Before | After |
|---|---|---|
| 406 | `.foregroundColor(.black)` (plus icon on green circle) | `.foregroundColor(.white)` |
| 418-422 | `.fill(Color(UIColor.systemGray6))` / `.strokeBorder(Color(UIColor.systemGray4), ...)` | `.fill(AppColors.cardBackground)` / `.strokeBorder(AppColors.separator, ...)` |
| 476 | `.fill(Color(UIColor.systemGray5))` (settlement capsule) | `.fill(AppColors.backgroundSecondary)` |

### 4. `Swiss Coin/Features/Subscriptions/Components/SubscriptionActionBar.swift`
| Line | Before | After |
|---|---|---|
| 98 | `.foregroundColor(.black)` (icon on green circle) | `.foregroundColor(.white)` |
| 110-114 | `.fill(Color(UIColor.systemGray6))` / `.strokeBorder(Color(UIColor.systemGray4), ...)` | `.fill(AppColors.cardBackground)` / `.strokeBorder(AppColors.separator, ...)` |

### 5. `Swiss Coin/Features/Home/HomeView.swift`
| Line | Before | After |
|---|---|---|
| 238 | `.shadow(color: Color.black.opacity(0.05), ...)` | `.shadow(color: AppColors.shadow, ...)` |

### 6. `Swiss Coin/Features/Profile/NotificationSettingsView.swift`
| Line | Before | After |
|---|---|---|
| 521 | `Color.black.opacity(0.3)` (loading overlay) | `Color(.label).opacity(0.3)` |
| 527 | `.tint(.white)` (ProgressView) | removed (uses default tint) |
| 531 | `.foregroundColor(.white)` (loading text) | `.foregroundColor(AppColors.textPrimary)` |
| 536 | `.fill(Color(UIColor.systemGray5))` (overlay background) | `.fill(AppColors.cardBackgroundElevated)` |

### 7. `Swiss Coin/Features/Transactions/NewTransactionContactView.swift`
| Line | Before | After |
|---|---|---|
| 76 | `.fill(Color.gray.opacity(0.3))` (avatar placeholder) | `.fill(AppColors.backgroundSecondary)` |
| 79 | `.foregroundColor(.white)` (initials on gray) | `.foregroundColor(AppColors.textSecondary)` |

### 8. `Swiss Coin/Views/Components/CustomSegmentedControl.swift`
| Line | Before | After |
|---|---|---|
| 31 | `.shadow(color: .black.opacity(0.1), ...)` | `.shadow(color: AppColors.shadow, ...)` |

### 9. `Swiss Coin/Features/People/Components/BalanceHeaderView.swift`
| Line | Before | After |
|---|---|---|
| 58 | `.shadow(color: .black.opacity(0.1), ...)` | `.shadow(color: AppColors.shadow, ...)` |

### 10. `Swiss Coin/Features/Subscriptions/Components/ColorPickerRow.swift`
| Line | Before | After |
|---|---|---|
| 66 | `.strokeBorder(... Color.white : Color.clear, ...)` (selection ring) | `.strokeBorder(... AppColors.textPrimary : Color.clear, ...)` |

### 11. `Swiss Coin/Features/QuickAction/Step3SplitMethodView.swift`
| Line | Before | After |
|---|---|---|
| 100 | `.fill(Color(UIColor.systemGray6))` (back button bg) | `.fill(AppColors.cardBackground)` |
| 278, 299, 335, 356 | `.background(Color(UIColor.systemGray6))` (split input fields) | `.background(AppColors.surface)` |

### 12. `Swiss Coin/Features/Subscriptions/Components/SubscriptionSettlementMessageView.swift`
| Line | Before | After |
|---|---|---|
| 50 | `.fill(Color(UIColor.systemGray5))` (settlement capsule) | `.fill(AppColors.backgroundSecondary)` |

### 13. `Swiss Coin/Features/QuickAction/QuickActionComponents.swift`
| Line | Before | After |
|---|---|---|
| 182 | `.background(Color(UIColor.systemGray6))` (search bar) | `.background(AppColors.surface)` |

---

## Verified — No Changes Needed

These files were audited and confirmed correct:

| File | Status | Notes |
|---|---|---|
| `PersonConversationView.swift` | ✅ Already uses `AppColors.background`, `AppColors.backgroundSecondary` | Properly themed |
| `GroupConversationView.swift` (main view) | ✅ Uses AppColors throughout | Action bar sub-view was fixed |
| `MessageBubbleView.swift` | ✅ Sent=white on accent, Received=textPrimary on otherBubble | Perfect for both modes |
| `TransactionBubbleView.swift` | ✅ Uses AppColors for all text and bubble fills | Correct |
| `TransactionCardView.swift` | ✅ Uses AppColors.cardBackground, textPrimary, textSecondary | Correct |
| `GroupTransactionCardView.swift` | ✅ Same pattern as TransactionCardView | Correct |
| `PhoneLoginView.swift` | ✅ Uses gradient from accent to systemBackground, semantic colors | Recently rewritten correctly |
| `CustomSegmentedControl.swift` | ✅ (shadow fixed) | Uses AppColors for all other colors |
| `QuickActionSheet.swift` | ✅ Uses AppColors.backgroundSecondary | Correct |
| `Step1BasicDetailsView.swift` | ✅ White on accent button is correct | All other colors use AppColors |
| `Step2SplitConfigView.swift` | ✅ White on accent buttons is correct | Uses semantic grouped backgrounds |
| `ProfileView.swift` | ✅ Uses List with insetGrouped style (auto-themed) | White on colored SettingsRow icons is correct |
| `OnboardingView.swift` | ✅ White on accent buttons is correct | Uses AppColors for text |
| `SettlementView.swift` | ✅ White on green/accent buttons is correct | |
| `GroupSettlementView.swift` | ✅ Same pattern | |
| `ReminderSheetView.swift` | ✅ White on warning button is correct | |
| `GroupReminderSheetView.swift` | ✅ Same pattern | |
| `PersonDetailView.swift` | ✅ White on accent button is correct | |
| `AddGroupView.swift` | ✅ White on accent button is correct | |
| `SubscriptionPaymentCardView.swift` | ✅ Uses AppColors throughout | |
| `SubscriptionReminderMessageView.swift` | ✅ Uses SwiftUI adaptive `.secondary`, `.orange` | |
| `SettlementMessageView.swift` | ✅ Uses AppColors | |
| `ReminderMessageView.swift` | ✅ Uses AppColors | |
| `MessageInputView.swift` | ✅ Uses AppColors | |
| `DateHeaderView.swift` | ✅ Uses AppColors | |
| `AppearanceSettingsView.swift` | ✅ Intentionally uses `Color.black`/`Color.white` for theme preview thumbnails | This is by design |
| `PersonalDetailsView.swift` | ✅ White on accent/color backgrounds is correct | |
| `TransactionEditView.swift` | ✅ `.tint(.white)` on PrimaryButtonStyle is correct | |

---

## Intentionally Kept `.foregroundColor(.white)` (29 instances)

All remaining `.foregroundColor(.white)` are used on **explicitly colored backgrounds** (green accent, positive, warning, or hex-color fills). These provide proper contrast in both light and dark mode:

- **Green accent buttons:** "Continue", "Save", "Settle", "Send Reminder", "Get Started", etc.
- **Colored avatar overlays:** Initials/icons on filled `Color(hex:)` circles
- **Settings row icons:** White icons on colored square backgrounds
- **Paid badge:** "Paid" text on green background
- **Radio button dots:** White dot inside green accent circle
- **Color picker checkmarks:** White checkmark on filled color circles

---

## Design Principles Applied

1. **`AppColors` is the single source of truth** — views reference semantic tokens, not raw system colors
2. **No hardcoded `Color.black` or `Color.gray`** anywhere in the codebase (except intentional theme previews)
3. **White text is only used on solid colored backgrounds** where contrast is guaranteed
4. **Shadows use `Color(.label).opacity()`** which adapts automatically (darker shadow in light mode, subtler in dark)
5. **Chat bubbles:** Sent = white text on green accent; Received = label text on secondarySystemBackground
6. **Cards and surfaces** use the semantic hierarchy: background → secondarySystemBackground → tertiarySystemBackground
7. **Separators and borders** use `Color(.separator)` for system-consistent appearance
