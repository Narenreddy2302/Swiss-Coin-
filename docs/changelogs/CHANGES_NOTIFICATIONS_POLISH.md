# Changes: Local Notifications & Polish Fixes

## Date: 2026-02-02

---

## 1. Local Notification System — NEW FILE

**File:** `Swiss Coin/Services/NotificationManager.swift`

Created a singleton `NotificationManager.shared` service using `UNUserNotificationCenter`:

### Methods:
- **`requestPermission()`** — Requests notification authorization; returns `Bool`; updates published `permissionStatus`
- **`refreshPermissionStatus()`** — Queries the system for current authorization status and updates published property
- **`scheduleSubscriptionReminder(for:)`** — Schedules a local notification X days before the subscription's `nextBillingDate`. Respects:
  - Per-subscription `notificationEnabled` flag
  - Per-subscription `notificationDaysBefore` value
  - Global notification toggle (`notifications_enabled` in UserDefaults)
  - Subscription-specific global toggle (`notify_subscription_due` in UserDefaults)
  - Active status of the subscription
  - Cancels any existing reminder before scheduling to prevent duplicates
- **`cancelSubscriptionReminder(for:)`** — Cancels a pending notification by subscription ID
- **`rescheduleAllSubscriptionReminders(in:)`** — Bulk reschedule: cancels all existing subscription reminders, fetches active + enabled subscriptions, and reschedules each
- **`scheduleReminderFollowUp(...)`** — Schedules a follow-up notification for person-to-person reminders
- **`cancelReminderFollowUp(reminderId:)`** — Cancels a pending follow-up
- **`removeAllNotifications()`** — Clears all pending + delivered notifications
- **`pendingNotificationCount()`** — Async utility for debugging

### Properties:
- `@Published permissionStatus: UNAuthorizationStatus` — Observable permission state
- `isAuthorized: Bool` — Convenience computed property

---

## 2. NotificationSettingsView Wired Up

**File:** `Swiss Coin/Features/Profile/NotificationSettingsView.swift`

### Changes:
- ViewModel now uses `NotificationManager.shared` instead of calling `UNUserNotificationCenter` directly
- Added `@Published permissionStatus` to track system-level state
- **Permission status UI:**
  - `.denied` → Shows warning banner with "Settings" button to open system Settings app
  - `.notDetermined` → Shows friendly "Enable" banner that triggers permission request
  - `.authorized` → No banner shown
- Master "All Notifications" toggle now triggers permission request if status is `.notDetermined`
- `loadSettings()` refreshes permission status from NotificationManager on appear
- `requestNotificationPermission()` delegates to NotificationManager, shows Settings prompt if denied

---

## 3. Subscription Notifications Wired Up

### AddSubscriptionView
**File:** `Swiss Coin/Features/Subscriptions/AddSubscriptionView.swift`
- After successful save, calls `NotificationManager.shared.scheduleSubscriptionReminder(for:)` if notifications are enabled

### EditSubscriptionView
**File:** `Swiss Coin/Features/Subscriptions/EditSubscriptionView.swift`
- After successful save, reschedules notification if enabled, or cancels if disabled

### SubscriptionListRowView
**File:** `Swiss Coin/Features/Subscriptions/Components/SubscriptionListRowView.swift`
- **Delete:** Cancels pending notification before deleting the subscription
- **Mark as Paid:** Reschedules notification for the new (advanced) billing date
- **Pause/Resume:** Cancels notification on pause, reschedules on resume

### SubscriptionDetailView
**File:** `Swiss Coin/Features/Subscriptions/SubscriptionDetailView.swift`
- **Payment Reminders toggle:** Schedules or cancels notification in real-time when toggled
- **Days-before stepper:** Reschedules with updated interval when value changes
- **Pause/Resume:** Same logic as list row
- **Delete:** Cancels notification before deletion

---

## 4. Polish Fixes

### 4a. CustomSegmentedControl — Design System

**File:** `Swiss Coin/Views/Components/CustomSegmentedControl.swift`

| Before | After |
|--------|-------|
| `Color(uiColor: .tertiarySystemGroupedBackground)` | `AppColors.backgroundTertiary` |
| `Color(uiColor: .secondarySystemFill)` | `AppColors.backgroundSecondary` |
| `.font(.subheadline).fontWeight(.medium)` | `AppTypography.subheadlineMedium()` |
| `.foregroundColor(.primary / .secondary)` | `AppColors.textPrimary / .textSecondary` |
| `.cornerRadius(8)` | `CornerRadius.sm` |
| `.cornerRadius(10)` | `CornerRadius.md` |
| `.padding(4)` | `Spacing.xxs` |
| `.padding(.vertical, 8)` | `Spacing.sm` |
| `.spring(response: 0.3, ...)` | `AppAnimation.spring` |
| No haptics | `HapticManager.selectionChanged()` on selection |
| No accessibility | Added `accessibilityLabel` per segment + `.isSelected` trait |

### 4b. Default Color Inconsistency — Fixed

**Root cause:** ProfileView and PersonalDetailsView defaulted to `#34C759` (green) while CurrentUser defined `#007AFF` (blue).

**Solution:** Created `AppColors.defaultAvatarColorHex` = `"#007AFF"` as the single source of truth.

| File | Change |
|------|--------|
| `DesignSystem.swift` | Added `AppColors.defaultAvatarColorHex` and `AppColors.defaultAvatarColor` |
| `CurrentUser.swift` | `defaultColorHex` now references `AppColors.defaultAvatarColorHex` |
| `PersonalDetailsView.swift` | Default `profileColor` changed from `#34C759` → `AppColors.defaultAvatarColorHex` |
| `ProfileView.swift` | Fallback `userColor` changed from `#34C759` → `AppColors.defaultAvatarColorHex` |
| `Color+Hex.swift` | `toHex()` fallback uses `AppColors.defaultAvatarColorHex`; comment updated |
| `BalanceHeaderView.swift` | Fallback changed from `#34C759` → `AppColors.defaultAvatarColorHex` |
| `AddSubscriptionView.swift` | Default `selectedColor` uses `AppColors.defaultAvatarColorHex` |

### 4c. Phone Formatting — International Support

**File:** `Swiss Coin/Features/Profile/PersonalDetailsView.swift`

Replaced US-only `(XXX) XXX-XXXX` formatter with international-aware formatter:

| Country Code | Format | Example |
|-------------|--------|---------|
| +41 (Swiss) | `+41 XX XXX XX XX` | +41 79 123 45 67 |
| Swiss local | `0XX XXX XX XX` | 079 123 45 67 |
| +1 (US/CA) | `+1 (XXX) XXX-XXXX` | +1 (555) 123-4567 |
| US local | `(XXX) XXX-XXXX` | (555) 123-4567 |
| +44 (UK) | `+44 XXXX XXXXXX` | +44 7911 123456 |
| +91 (India) | `+91 XXXXX XXXXX` | +91 98765 43210 |
| Other | Groups of 4 digits | +86 1234 5678 9012 |

Auto-detects format based on country code prefix. Preserves `+` prefix for international numbers.

---

## Files Modified

| File | Type |
|------|------|
| `Swiss Coin/Services/NotificationManager.swift` | **NEW** |
| `Swiss Coin/Features/Profile/NotificationSettingsView.swift` | Modified |
| `Swiss Coin/Features/Subscriptions/AddSubscriptionView.swift` | Modified |
| `Swiss Coin/Features/Subscriptions/EditSubscriptionView.swift` | Modified |
| `Swiss Coin/Features/Subscriptions/Components/SubscriptionListRowView.swift` | Modified |
| `Swiss Coin/Features/Subscriptions/SubscriptionDetailView.swift` | Modified |
| `Swiss Coin/Views/Components/CustomSegmentedControl.swift` | Rewritten |
| `Swiss Coin/Utilities/DesignSystem.swift` | Modified |
| `Swiss Coin/Utilities/CurrentUser.swift` | Modified |
| `Swiss Coin/Features/Profile/PersonalDetailsView.swift` | Modified |
| `Swiss Coin/Features/Profile/ProfileView.swift` | Modified |
| `Swiss Coin/Extensions/Color+Hex.swift` | Modified |
| `Swiss Coin/Features/People/Components/BalanceHeaderView.swift` | Modified |

---

## Notes

- The `NotificationManager` respects both per-subscription settings and global notification preferences stored in `UserDefaults` via `AppStorage`
- No existing functionality was broken — all changes are additive or swapped to use design system constants
- The `Person+Extensions.swift` fallback `#808080` (gray) was kept as-is since it applies to contacts/other people, not the current user
- `AppearanceSettingsView` accent color `#34C759` (green) was kept as-is since it's the app's theme color, not an avatar default
