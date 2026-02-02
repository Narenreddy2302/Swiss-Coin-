# Supabase Removal — Change Summary

**Date:** 2026-02-02  
**Scope:** Complete removal of Supabase backend dependency; replaced with local-only auth and storage.

---

## Overview

All Supabase-related code (network calls, API models, session management, token refresh, cloud sync) has been removed. The app now operates fully offline with local authentication and local data persistence.

---

## Files Changed

### 1. `Swiss Coin/Services/SupabaseManager.swift` — **Complete Rewrite**

**Before:** ~1,800 lines — Supabase REST client with URL session, auth (OTP/phone), token refresh, session management, profile/settings CRUD, photo upload, data export, account deletion, and dozens of Codable response/update model types.

**After:** ~90 lines — `AuthManager` class with:
- `AuthState` enum: `.unknown`, `.authenticated`, `.unauthenticated` (removed `.verifyingOTP`)
- `@Published authState`, `isLoading`, `currentUserId`
- `authenticate()` — sets state to `.authenticated` using `CurrentUser`
- `signOut()` — clears state, resets `CurrentUser`, sets flag in `UserDefaults`
- `restoreSession()` — on launch, checks sign-out flag; auto-authenticates or shows welcome
- `typealias SupabaseManager = AuthManager` for backward compatibility

**Removed:** `SupabaseConfig`, `SupabaseError`, all HTTP request infrastructure, all Codable response/update models (`AuthResponse`, `UserProfile`, `ProfileDetails`, `UserSessionInfo`, `LoginHistoryEntry`, `BlockedUserInfo`, `UserSecuritySettings`, `UserPrivacySettings`, `UserNotificationSettings`, `UserAppearanceSettings`, `UserSettingsUpdate`, `NotificationSettingsUpdate`, `PrivacySettingsUpdate`, `SecuritySettingsUpdate`, `ProfileDetailsUpdate`, `EmptyResponse`, `TransactionCategory`, `SystemTransactionCategory`, `DataExportResponse`, `PINVerificationResult`, `TerminateSessionsResponse`, etc.)

---

### 2. `Swiss Coin/App/ContentView.swift` — **Simplified**

- Changed `@StateObject` from `SupabaseManager.shared` to `AuthManager.shared`
- Removed `.verifyingOTP` case from switch
- Auth flow: `.unknown` → loading spinner → auto-transitions to `.authenticated` (main app) or `.unauthenticated` (welcome screen)

---

### 3. `Swiss Coin/Features/Auth/PhoneLoginView.swift` — **Complete Rewrite**

**Before:** Phone number input form with country code picker, OTP-based Supabase sign-in.

**After:** Polished welcome/onboarding screen with:
- Animated "Swiss Coin" logo with subtle pulse effect
- Tagline: "Split expenses effortlessly with friends and groups"
- Three feature highlights (Group Expenses, Smart Insights, Reminders)
- "Get Started" button that calls `authManager.authenticate()`
- Footer: "Your data stays on this device. No account required."
- Uses the app's design system (AppColors, AppTypography, Spacing, etc.)

---

### 4. `Swiss Coin/Features/Profile/ProfileView.swift` — **Minor Update**

- Removed `@StateObject private var supabase = SupabaseManager.shared`
- `logOut()` now calls `AuthManager.shared.signOut()` directly (synchronous, no Task/await)
- All other functionality preserved (settings navigation, share, support links, etc.)

---

### 5. `Swiss Coin/Features/Profile/PersonalDetailsView.swift` — **Major Cleanup**

- Removed all Supabase sync (`loadFromSupabase()`, `updateProfileDetails()`, `uploadProfilePhoto()`, `deleteProfilePhoto()`)
- Photo management is now local-only: images saved as JPEG data to CoreData's `Person.photoData`
- Email and full name stored in `UserDefaults` (lightweight local store)
- Removed `avatarUrl` / `AsyncImage` remote photo loading
- Removed `phoneVerified` / `emailVerified` status badges
- Removed `SupabaseError` references
- `saveChanges()` is now synchronous (no async/await needed)
- `ImagePicker` simplified — resize handled in `didSelectImage()` callback

---

### 6. `Swiss Coin/Features/Profile/NotificationSettingsView.swift` — **Major Cleanup**

- Removed Supabase `loadSettings()` and `saveSettings()` network calls
- Removed `isSaving` state and "Syncing..." UI indicator
- Removed `lastSyncedAt` and "Last synced" display
- Removed `SupabaseError` handling
- All settings load from and auto-save to `AppStorage` only
- `loadSettings()` now just loads from `AppStorage` + checks system notification status
- Auto-save debounce reduced from 500ms to 300ms (no network overhead)

---

### 7. `Swiss Coin/Features/Profile/AppearanceSettingsView.swift` — **Major Cleanup**

- Removed Supabase `loadSettings()` and `saveSettings()` network calls
- Removed `isSaving`, `showError`, `errorMessage`, `lastSyncedAt` state
- Removed "Syncing..." UI, error alerts, loading overlay, "Last synced" section
- `loadSettings()` is now synchronous (loads from `AppStorage`)
- All settings auto-save to `AppStorage` only via Combine debounce
- View uses `.onAppear` instead of `.task` (no async needed)

---

### 8. `Swiss Coin/Features/Profile/PrivacySecurityView.swift` — **Major Cleanup**

- Removed all Supabase API calls from `PrivacySecurityViewModel`
- **Security:** Biometric and PIN remain fully functional (local-only via Keychain + UserDefaults)
- **Privacy toggles:** Save directly to `UserDefaults` on change
- **Removed entirely:**
  - `DevicesSection` (Active Sessions, Sign Out All Devices — no remote sessions exist)
  - `ActiveSessionsView`, `ActiveSessionsViewModel`, `SessionRowView`
  - `LoginHistoryView`, `LoginHistoryViewModel`, `LoginHistoryRowView`
  - `BlockedUsersView`, `BlockedUsersViewModel`
  - "Export Data" feature (was Supabase-dependent)
- **Changed:**
  - "Delete Account" → "Clear All Data & Sign Out" — clears Keychain, resets CurrentUser, signs out
  - All ViewModel methods are now synchronous (no async/await)
- **Kept:** `PINSetupView`, `PINVerifyView` (fully local, use KeychainHelper + CryptoKit)

---

### 9. `Swiss Coin/Utilities/CurrentUser.swift` — **No Changes**

Already fully local (CoreData + UserDefaults). No Supabase references found. Confirmed working as-is.

---

## Auth Flow (After Changes)

```
App Launch
    ↓
AuthManager.restoreSession()
    ↓
[0.4s loading spinner]
    ↓
Was user signed out? ──Yes──→ Show Welcome Screen (PhoneLoginView)
    │                              ↓
    No                        User taps "Get Started"
    ↓                              ↓
Auto-authenticate            AuthManager.authenticate()
    ↓                              ↓
Show MainTabView ←─────────── Show MainTabView

Profile → Log Out
    ↓
AuthManager.signOut()
    ↓
Show Welcome Screen
```

## What Was Removed

- **~1,700 lines** of Supabase networking code and model types
- All `URLSession` HTTP request infrastructure
- Token-based session management (access token, refresh token, Keychain storage for tokens)
- Phone number OTP authentication flow
- Remote profile sync, photo upload/download
- Remote settings sync (notification, appearance, privacy, security)
- Active sessions management (list, revoke, trust devices)
- Login history tracking
- Blocked users management
- Data export feature
- Remote account deletion
- All Supabase-specific Codable response types (~40 structs)

## What Was Kept

- All CoreData functionality
- All local UI and navigation
- Design system usage (AppColors, AppTypography, Spacing, etc.)
- Haptic feedback (HapticManager)
- Keychain-based PIN storage
- Biometric authentication (Face ID / Touch ID)
- Local settings via AppStorage / UserDefaults
- Image picker and local photo storage
- All non-auth app features (expenses, groups, subscriptions, etc.)
