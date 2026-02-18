# 01 - Authentication

Phone OTP as the primary auth method. Supabase Auth manages sessions, token refresh, and user identity. The existing local UUID system in `CurrentUser.swift` is replaced by the Supabase auth user ID.

---

## Table of Contents

1. [SDK Setup](#1-sdk-setup)
2. [SupabaseConfig Singleton](#2-supabaseconfig-singleton)
3. [AuthManager Rewrite](#3-authmanager-rewrite)
4. [Phone OTP Login UI](#4-phone-otp-login-ui)
5. [Auto-Profile Creation Trigger](#5-auto-profile-creation-trigger)
6. [Session Management](#6-session-management)
7. [Existing User Migration](#7-existing-user-migration)
8. [Dashboard Configuration](#8-dashboard-configuration)
9. [Apple Sign-In (Deferred)](#9-apple-sign-in-deferred)

---

## 1. SDK Setup

### Add Supabase Swift SDK via SPM

1. In Xcode: **File > Add Package Dependencies**
2. URL: `https://github.com/supabase/supabase-swift`
3. Version: **2.0.0** or later (Up to Next Major)
4. Select products: `Supabase` (includes Auth, PostgREST, Realtime, Storage, Functions)

This adds the following to `Package.resolved`:
```
supabase-swift (2.x)
  - Auth
  - PostgREST
  - Realtime
  - Storage
  - Functions
```

### Info.plist Changes

Add URL scheme for auth deep links (needed for magic links / OAuth redirects in future):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>swisscoin</string>
    </array>
    <key>CFBundleURLName</key>
    <string>com.swisscoin.app</string>
  </dict>
</array>
```

---

## 2. SupabaseConfig Singleton

```swift
// Swiss Coin/Services/Supabase/SupabaseConfig.swift

import Foundation
import Supabase

/// Central Supabase client — single instance for the entire app.
/// Access via `SupabaseConfig.shared.client`.
final class SupabaseConfig {

    static let shared = SupabaseConfig()

    let client: SupabaseClient

    /// Project reference ID
    static let projectRef = "fgcjijairsikaeshpiof"

    private init() {
        // These values are safe to embed — RLS protects data access
        let url = URL(string: "https://\(Self.projectRef).supabase.co")!
        let anonKey = "YOUR_ANON_KEY_HERE" // Replace with actual anon key

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: .init(
                auth: .init(
                    redirectToURL: URL(string: "swisscoin://auth-callback")
                ),
                global: .init(
                    headers: ["x-app-version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"]
                )
            )
        )
    }
}
```

> **Note:** The anon key is a publishable key (like Stripe's `pk_` key). It is safe in client code because RLS policies enforce data access. The **service role key** must NEVER appear in client code.

---

## 3. AuthManager Rewrite

Replace the existing `CurrentUser` local UUID system with Supabase Auth session management.

```swift
// Swiss Coin/Services/Supabase/AuthManager.swift

import Foundation
import Supabase
import Combine
import os

/// Manages Supabase authentication state.
/// Replaces the old local-UUID CurrentUser identity system.
///
/// Usage:
///   AuthManager.shared.currentUserId   // UUID? of authenticated user
///   AuthManager.shared.isAuthenticated  // Bool
///   AuthManager.shared.$authState       // Published state changes
///
typealias SupabaseManager = AuthManager

@MainActor
final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    // MARK: - Published State

    enum AuthState: Equatable {
        case loading           // Checking stored session
        case unauthenticated   // No session, show login
        case authenticated     // Valid session, show app
    }

    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var currentUserId: UUID?
    @Published private(set) var userPhone: String?

    var isAuthenticated: Bool { authState == .authenticated }

    private let client = SupabaseConfig.shared.client
    private let logger = Logger(subsystem: "com.swisscoin", category: "Auth")
    private var authStateTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        // Start listening for auth state changes
        listenForAuthChanges()

        // Check for existing session
        Task {
            await checkExistingSession()
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Auth State Listener

    /// Listens to Supabase auth state changes (sign in, sign out, token refresh).
    private func listenForAuthChanges() {
        authStateTask = Task { [weak self] in
            guard let self else { return }

            for await (event, session) in client.auth.authStateChanges {
                logger.info("Auth event: \(String(describing: event))")

                switch event {
                case .signedIn:
                    if let userId = session?.user.id {
                        self.currentUserId = userId
                        self.userPhone = session?.user.phone
                        self.authState = .authenticated

                        // Update CurrentUser to use Supabase ID
                        CurrentUser.setCurrentUser(id: userId)

                        logger.info("Signed in: \(userId)")
                    }

                case .signedOut:
                    self.currentUserId = nil
                    self.userPhone = nil
                    self.authState = .unauthenticated
                    CurrentUser.reset()
                    logger.info("Signed out")

                case .tokenRefreshed:
                    logger.info("Token refreshed")

                case .userUpdated:
                    if let userId = session?.user.id {
                        self.currentUserId = userId
                        self.userPhone = session?.user.phone
                    }

                default:
                    break
                }
            }
        }
    }

    /// Check if there's a stored session from a previous launch.
    private func checkExistingSession() async {
        do {
            let session = try await client.auth.session
            currentUserId = session.user.id
            userPhone = session.user.phone
            authState = .authenticated
            CurrentUser.setCurrentUser(id: session.user.id)
            logger.info("Restored session for \(session.user.id)")
        } catch {
            logger.info("No existing session: \(error.localizedDescription)")
            authState = .unauthenticated
        }
    }

    // MARK: - Phone OTP Flow

    /// Step 1: Send OTP code to phone number.
    /// - Parameter phone: E.164 format phone number (e.g., "+14155551234")
    func sendPhoneOTP(phone: String) async throws {
        logger.info("Sending OTP to \(phone)")
        try await client.auth.signInWithOTP(phone: phone)
    }

    /// Step 2: Verify OTP code entered by user.
    /// - Parameters:
    ///   - phone: Same phone number from step 1
    ///   - token: 6-digit OTP code
    func verifyPhoneOTP(phone: String, token: String) async throws {
        logger.info("Verifying OTP for \(phone)")
        try await client.auth.verifyOTP(
            phone: phone,
            token: token,
            type: .sms
        )
        // Auth state listener will handle the rest
    }

    // MARK: - Sign Out

    /// Sign out the current user. Clears session and local state.
    func signOut() async throws {
        logger.info("Signing out")
        try await client.auth.signOut()
        // Auth state listener will handle state transition
    }

    // MARK: - User Info

    /// Get the current authenticated user's metadata.
    var currentUser: User? {
        get async {
            try? await client.auth.session.user
        }
    }
}
```

### CurrentUser.swift Changes

The existing `CurrentUser.swift` mostly stays the same but `setCurrentUser(id:)` and `reset()` are now called by `AuthManager` instead of being managed locally. The key change:

```swift
// In CurrentUser.swift, the _currentUserId initialization changes:
// OLD: generates random UUID from UserDefaults
// NEW: returns nil until AuthManager sets it after Supabase sign-in

private static var _currentUserId: UUID? = {
    if let stored = UserDefaults.standard.string(forKey: "currentUserId") {
        return UUID(uuidString: stored)
    }
    return nil // Don't auto-generate; wait for auth
}()
```

---

## 4. Phone OTP Login UI

Two-step flow: phone number input -> OTP verification.

### AuthViewModel

```swift
// Swiss Coin/Features/Auth/AuthViewModel.swift

import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {

    enum Step {
        case phoneInput
        case otpVerification
    }

    @Published var step: Step = .phoneInput
    @Published var phoneNumber: String = ""
    @Published var countryCode: String = "+1"
    @Published var otpCode: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Full E.164 phone number
    var fullPhoneNumber: String {
        let digits = phoneNumber.filter { $0.isNumber }
        return "\(countryCode)\(digits)"
    }

    var isPhoneValid: Bool {
        let digits = phoneNumber.filter { $0.isNumber }
        return digits.count >= 10
    }

    var isOTPValid: Bool {
        otpCode.filter { $0.isNumber }.count == 6
    }

    // MARK: - Actions

    func sendOTP() async {
        guard isPhoneValid else {
            errorMessage = "Please enter a valid phone number"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await AuthManager.shared.sendPhoneOTP(phone: fullPhoneNumber)
            step = .otpVerification
        } catch {
            errorMessage = "Failed to send code: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func verifyOTP() async {
        guard isOTPValid else {
            errorMessage = "Please enter the 6-digit code"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await AuthManager.shared.verifyPhoneOTP(
                phone: fullPhoneNumber,
                token: otpCode.filter { $0.isNumber }
            )
            // Success — AuthManager listener handles state transition
        } catch {
            errorMessage = "Invalid code. Please try again."
        }

        isLoading = false
    }

    func goBackToPhone() {
        step = .phoneInput
        otpCode = ""
        errorMessage = nil
    }
}
```

### PhoneLoginView

```swift
// Swiss Coin/Features/Auth/PhoneLoginView.swift

import SwiftUI

struct PhoneLoginView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: Spacing.xxl) {
                Spacer()

                // App Logo / Title
                VStack(spacing: Spacing.md) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: IconSize.xxl))
                        .foregroundColor(AppColors.accent)

                    Text("Swiss Coin")
                        .font(AppTypography.displayLarge())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Sign in with your phone number")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Content based on step
                switch viewModel.step {
                case .phoneInput:
                    phoneInputSection
                case .otpVerification:
                    otpVerificationSection
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }

    // MARK: - Phone Input

    private var phoneInputSection: some View {
        VStack(spacing: Spacing.lg) {
            // Country code + phone number
            HStack(spacing: Spacing.sm) {
                // Country code selector
                TextField("+1", text: $viewModel.countryCode)
                    .font(AppTypography.bodyLarge())
                    .keyboardType(.phonePad)
                    .frame(width: 60)
                    .padding(Spacing.md)
                    .background(AppColors.surface)
                    .cornerRadius(CornerRadius.medium)

                // Phone number
                TextField("Phone number", text: $viewModel.phoneNumber)
                    .font(AppTypography.bodyLarge())
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding(Spacing.md)
                    .background(AppColors.surface)
                    .cornerRadius(CornerRadius.medium)
            }

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.negative)
            }

            // Send OTP button
            Button {
                Task { await viewModel.sendOTP() }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(AppColors.onAccent)
                    } else {
                        Text("Send Code")
                            .font(AppTypography.buttonLarge())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.lg)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.isPhoneValid || viewModel.isLoading)
        }
    }

    // MARK: - OTP Verification

    private var otpVerificationSection: some View {
        VStack(spacing: Spacing.lg) {
            Text("Enter the 6-digit code sent to")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)

            Text(viewModel.fullPhoneNumber)
                .font(AppTypography.headingMedium())
                .foregroundColor(AppColors.textPrimary)

            // OTP input
            TextField("000000", text: $viewModel.otpCode)
                .font(AppTypography.financialLarge())
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .padding(Spacing.md)
                .background(AppColors.surface)
                .cornerRadius(CornerRadius.medium)
                .frame(maxWidth: 200)

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.negative)
            }

            // Verify button
            Button {
                Task { await viewModel.verifyOTP() }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(AppColors.onAccent)
                    } else {
                        Text("Verify")
                            .font(AppTypography.buttonLarge())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.lg)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.isOTPValid || viewModel.isLoading)

            // Back button
            Button {
                viewModel.goBackToPhone()
            } label: {
                Text("Change phone number")
                    .font(AppTypography.buttonDefault())
            }
            .buttonStyle(GhostButtonStyle())
        }
    }
}
```

### App Entry Point Changes

```swift
// In Swiss_CoinApp.swift — wrap content in auth state check

@main
struct Swiss_CoinApp: App {
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.authState {
                case .loading:
                    // Splash screen while checking session
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppColors.background.ignoresSafeArea())

                case .unauthenticated:
                    PhoneLoginView()

                case .authenticated:
                    ContentView()
                        .environment(\.managedObjectContext,
                            PersistenceController.shared.container.viewContext)
                }
            }
        }
    }
}
```

---

## 5. Auto-Profile Creation Trigger

When a user signs up via Phone OTP, Supabase creates a row in `auth.users`. This trigger automatically creates a corresponding `profiles` row:

```sql
-- Create the trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, phone, created_at, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'display_name', 'Me'),
    NEW.phone,
    NOW(),
    NOW()
  );
  RETURN NEW;
END;
$$;

-- Attach to auth.users inserts
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
```

This ensures every authenticated user has a `profiles` row immediately available for foreign key references and RLS policies.

---

## 6. Session Management

### How Supabase SDK Handles Sessions

The Supabase Swift SDK automatically:

1. **Stores tokens** in the iOS Keychain (secure, persists across app launches)
2. **Refreshes tokens** automatically before expiry (using the refresh token)
3. **Emits auth events** via `authStateChanges` async stream

You do NOT need to:
- Manually store/retrieve JWT tokens
- Implement token refresh logic
- Handle Keychain operations

### Session Lifecycle

```
App Launch
    |
    v
checkExistingSession()
    |
    +-- Session found --> .authenticated (restore userId)
    |
    +-- No session --> .unauthenticated (show login)

During Use:
    |
    +-- Token near expiry --> SDK auto-refreshes
    |                         --> .tokenRefreshed event
    |
    +-- User signs out --> .signedOut event --> .unauthenticated
    |
    +-- Network lost --> SDK queues refresh for reconnection
```

### Token Expiry Defaults

| Token | Default TTL | Configurable |
|-------|-------------|-------------|
| Access Token (JWT) | 3600s (1 hour) | Yes, in Dashboard > Auth > Settings |
| Refresh Token | 1 week (no expiry if used) | Yes |

Recommendation: Keep defaults. The SDK handles refresh transparently.

---

## 7. Existing User Migration

Users who used Swiss Coin before Supabase integration have data tied to a local UUID (stored in UserDefaults as `currentUserId`). After they sign in with phone OTP:

### Migration Steps

1. **Detect legacy user:** Check `UserDefaults` for `currentUserId` before first Supabase sign-in
2. **Store mapping:** Save `{localUUID: "<old>", supabaseUUID: "<new>"}` to UserDefaults
3. **Upload local data:** Push all CoreData records to Supabase with `owner_id = supabaseUUID`
4. **Remap CoreData:** Update the local `Person` entity's `id` from old UUID to new UUID
5. **Clean up:** Remove old `currentUserId` from UserDefaults

```swift
// Migration check — run once after first successful Supabase sign-in
func migrateExistingUser(supabaseUserId: UUID) {
    let legacyKey = "currentUserId"
    guard let legacyIdString = UserDefaults.standard.string(forKey: legacyKey),
          let legacyId = UUID(uuidString: legacyIdString),
          legacyId != supabaseUserId else {
        return // No migration needed
    }

    // Store mapping for data upload phase
    UserDefaults.standard.set(legacyIdString, forKey: "legacy_user_id")

    // Update CurrentUser to new ID
    CurrentUser.setCurrentUser(id: supabaseUserId)

    // Mark migration as pending (SyncEngine will handle the actual data push)
    UserDefaults.standard.set(true, forKey: "pending_data_migration")
}
```

Full migration details in `08-MIGRATION-GUIDE.md`.

---

## 8. Dashboard Configuration

### Enable Phone Auth

1. Go to **Supabase Dashboard > Authentication > Providers**
2. Enable **Phone** provider
3. Configure SMS provider:

#### Twilio Setup

| Setting | Value |
|---------|-------|
| SMS Provider | Twilio |
| Account SID | `AC...` (from Twilio Console) |
| Auth Token | `...` (from Twilio Console) |
| Message Service SID | `MG...` (from Twilio Messaging) |
| OTP Expiry | 300 seconds (5 minutes) |
| OTP Length | 6 digits |

#### Rate Limiting

| Setting | Recommended |
|---------|-------------|
| Rate limit (per hour per phone) | 5 |
| Rate limit (per hour per IP) | 30 |
| Anti-bot / CAPTCHA | Enable for production |

### Auth Settings

1. Go to **Authentication > Settings**
2. Set:
   - **Site URL:** `swisscoin://auth-callback`
   - **Redirect URLs:** `swisscoin://auth-callback`
   - **JWT expiry:** 3600 (default)
   - **Enable email confirmations:** OFF (phone-only)

---

## 9. Apple Sign-In (Deferred)

**Status: DEFERRED to Phase 2**

Apple Sign-In will be added as an alternative auth method after the initial phone OTP launch.

### Why Deferred
- Phone OTP is simpler to implement and test
- Phone numbers are more useful for contact matching in expense splitting
- Apple Sign-In requires Apple Developer Program enrollment review
- Can be added alongside phone auth without breaking existing sessions

### Future Implementation Notes
- Use `ASAuthorizationAppleIDProvider` to get identity token
- Pass identity token to `client.auth.signInWithIdToken(credentials:)`
- Apple requires Sign In with Apple if any third-party sign-in is offered
- Will need to handle "Hide My Email" relay addresses

---

## Error Handling Reference

| Error | Cause | User Message |
|-------|-------|-------------|
| `AuthError.rateLimitExceeded` | Too many OTP requests | "Too many attempts. Please wait a few minutes." |
| `AuthError.invalidCredentials` | Wrong OTP code | "Invalid code. Please try again." |
| `AuthError.sessionNotFound` | No stored session | (redirect to login) |
| `AuthError.userNotFound` | Deleted user | "Account not found. Please sign up." |
| Network error | No internet | "No internet connection. Please try again." |

---

## Checklist

- [ ] Add Supabase Swift SDK via SPM
- [ ] Create `SupabaseConfig.swift`
- [ ] Rewrite `AuthManager.swift`
- [ ] Build `PhoneLoginView` and `OTPVerificationView`
- [ ] Create `AuthViewModel`
- [ ] Apply `handle_new_user()` trigger SQL
- [ ] Configure Phone Auth in Supabase Dashboard
- [ ] Set up Twilio SMS provider
- [ ] Update `Swiss_CoinApp.swift` entry point
- [ ] Test OTP flow end-to-end
- [ ] Implement existing user migration path
