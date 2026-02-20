//
//  SupabaseManager.swift
//  Swiss Coin
//
//  Authentication manager using Supabase + Sign in with Apple.
//

import AuthenticationServices
import Combine
import CoreData
import CryptoKit
import Foundation
import os
import Supabase

// MARK: - Auth State

enum AuthState: Equatable {
    case loading
    case authenticated
    case unauthenticated
    case needsPhoneEntry
}

// MARK: - Auth Manager

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    // MARK: - Published Properties

    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var isLoading = false
    @Published private(set) var currentUserId: UUID?
    @Published var errorMessage: String?

    private var authStateTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var currentNonce: String?
    private var lastHandledUserId: UUID?

    // MARK: - Init

    private init() {
        listenForAuthChanges()

        // Sign out immediately if Apple credential is revoked while app is running
        NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.signOut()
            }
        }
    }

    deinit {
        authStateTask?.cancel()
        timeoutTask?.cancel()
    }

    // MARK: - Auth State Listener

    private func listenForAuthChanges() {
        // Stored timeout: if no auth event resolves within 10s, assume unauthenticated.
        // Cancelled when auth resolves normally (handleSession, signedOut, initialSession nil).
        timeoutTask = Task {
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                if self.authState == .loading {
                    AppLogger.auth.warning("Auth timeout — no session event in 10s, falling back to unauthenticated")
                    self.authState = .unauthenticated
                }
            } catch {
                // Task was cancelled — auth resolved normally
            }
        }

        authStateTask = Task {
            for await (event, session) in SupabaseConfig.client.auth.authStateChanges {
                switch event {
                case .initialSession:
                    self.timeoutTask?.cancel()
                    if let session {
                        self.handleSession(session)
                    } else {
                        self.authState = .unauthenticated
                        self.currentUserId = nil
                    }
                case .signedIn:
                    if let session {
                        self.handleSession(session)
                    }
                case .signedOut:
                    self.timeoutTask?.cancel()
                    self.currentUserId = nil
                    self.authState = .unauthenticated
                case .tokenRefreshed:
                    if let session {
                        self.handleSession(session)
                    }
                default:
                    break
                }
            }
        }
    }

    private func handleSession(_ session: Session) {
        timeoutTask?.cancel()

        // Legacy phone OTP sessions must be cleared before proceeding
        if isLegacyPhoneOTPSession(session) {
            Task { await forceLegacySessionSignOut() }
            return
        }

        let userId = session.user.id

        // Deduplicate: Supabase fires both .initialSession and .signedIn on
        // first sign-in. Skip if we already handled this user's session.
        guard userId != lastHandledUserId else { return }
        lastHandledUserId = userId

        currentUserId = userId
        CurrentUser.setCurrentUser(id: userId)

        // Check if phone has been collected
        if UserDefaults.standard.bool(forKey: "user_phone_collected") {
            // Fast path: cached — no flash
            authState = .authenticated

            // Claim any phantom shares for returning users
            Task { let _ = await SharedDataService.shared.claimPendingShares() }
        } else {
            // Slow path: stay in .loading while checking Supabase
            Task {
                await checkProfileHasPhone(userId: userId)
            }
        }

        // Sync Apple metadata (name, email) to Supabase profile in the background.
        // This ensures the profile row has up-to-date Apple data regardless of phone state.
        Task { await syncAppleMetadataToProfile(userId: userId) }
    }

    /// Detects legacy phone OTP sessions from before Apple Sign-In migration.
    private func isLegacyPhoneOTPSession(_ session: Session) -> Bool {
        let provider = session.user.appMetadata["provider"]?.stringValue
        let hasAppleUserId = KeychainHelper.read(key: "apple_user_id") != nil
        return provider == "phone" && !hasAppleUserId
    }

    /// Signs out a legacy phone OTP session and clears related UserDefaults.
    /// Preserves CoreData, theme, and onboarding state.
    private func forceLegacySessionSignOut() async {
        do {
            try await SupabaseConfig.client.auth.signOut()
        } catch {
            // Even if remote sign-out fails, clear local state
        }

        currentUserId = nil
        lastHandledUserId = nil
        CurrentUser.reset()
        UserDefaults.standard.removeObject(forKey: "lastSyncTimestamp")
        UserDefaults.standard.removeObject(forKey: "supabase_migration_completed")
        authState = .unauthenticated
    }

    /// Ensures the profile row exists after Apple Sign-In and populates
    /// display_name, full_name, and email if missing.
    /// The `handle_new_user()` trigger should create the row, but if it fails
    /// silently this self-heals by inserting or patching client-side.
    private func ensureProfileExists(userId: UUID) async {
        do {
            let existing: [ProfileDTO] = try await SupabaseConfig.client.from("profiles")
                .select("*")
                .eq("id", value: userId.uuidString)
                .execute().value

            let displayName = UserDefaults.standard.string(forKey: "apple_given_name") ?? "User"
            let fullName = UserDefaults.standard.string(forKey: "apple_full_name")
            let email = KeychainHelper.read(key: "apple_email")

            if existing.isEmpty {
                AppLogger.auth.warning("Profile row missing for user \(userId) — inserting client-side")
                try await SupabaseConfig.client.from("profiles")
                    .insert([
                        "id": userId.uuidString,
                        "display_name": displayName,
                        "full_name": fullName,
                        "email": email,
                    ] as [String: String?])
                    .execute()
            } else if let profile = existing.first,
                      profile.fullName == nil || profile.fullName?.isEmpty == true {
                // Profile exists but missing name/email — patch it
                try await SupabaseConfig.client.from("profiles")
                    .update([
                        "display_name": displayName,
                        "full_name": fullName,
                        "email": email,
                    ] as [String: String?])
                    .eq("id", value: userId.uuidString)
                    .execute()
            }
        } catch {
            AppLogger.auth.warning("ensureProfileExists failed: \(error.localizedDescription)")
        }
    }

    /// Syncs Apple Sign-In metadata (name, email) to the Supabase profile row.
    /// The `handle_new_user()` trigger may not capture this data because Apple's name
    /// is written via `auth.update()` after the trigger fires. This method fills the gap.
    ///
    /// Apple only provides name/email on the FIRST sign-in. On subsequent sign-ins
    /// the credential fields are nil. After a sign-out the local cache is cleared.
    /// So we fall back to `session.user.userMetadata` which Supabase always keeps.
    private func syncAppleMetadataToProfile(userId: UUID) async {
        await ensureProfileExists(userId: userId)

        // 1. Try local cache first (populated on first Apple sign-in)
        var displayName = UserDefaults.standard.string(forKey: "apple_given_name")
        var fullName = UserDefaults.standard.string(forKey: "apple_full_name")
        var email = KeychainHelper.read(key: "apple_email")

        // 2. Fall back to Supabase session metadata (always available from auth.users)
        if displayName == nil || fullName == nil || email == nil {
            if let session = try? await SupabaseConfig.client.auth.session {
                let meta = session.user.userMetadata

                if displayName == nil, let given = meta["given_name"]?.stringValue, !given.isEmpty {
                    displayName = given
                    UserDefaults.standard.set(given, forKey: "apple_given_name")
                }
                if fullName == nil, let full = meta["full_name"]?.stringValue, !full.isEmpty {
                    fullName = full
                    UserDefaults.standard.set(full, forKey: "apple_full_name")
                }
                if email == nil {
                    let sessionEmail = meta["email"]?.stringValue ?? session.user.email
                    if let resolvedEmail = sessionEmail, !resolvedEmail.isEmpty {
                        email = resolvedEmail
                        KeychainHelper.save(key: "apple_email", value: resolvedEmail)
                    }
                }

                // Also restore family name if missing
                if UserDefaults.standard.string(forKey: "apple_family_name") == nil,
                   let family = meta["family_name"]?.stringValue, !family.isEmpty {
                    UserDefaults.standard.set(family, forKey: "apple_family_name")
                }
            }
        }

        // 2b. Last resort — read directly from profiles table
        if displayName == nil || fullName == nil || email == nil {
            if let profiles: [ProfileDTO] = try? await SupabaseConfig.client.from("profiles")
                .select("*").eq("id", value: userId.uuidString).execute().value,
               let profile = profiles.first {
                if displayName == nil, !profile.displayName.isEmpty {
                    displayName = profile.displayName
                    UserDefaults.standard.set(profile.displayName, forKey: "apple_given_name")
                }
                if fullName == nil, let remote = profile.fullName, !remote.isEmpty {
                    fullName = remote
                    UserDefaults.standard.set(remote, forKey: "apple_full_name")
                }
                if email == nil, let remote = profile.email, !remote.isEmpty {
                    email = remote
                    KeychainHelper.save(key: "apple_email", value: remote)
                }
            }
        }

        // 3. Populate PersonalDetailsView keys so the profile page shows the data
        if let fullName, !fullName.isEmpty,
           UserDefaults.standard.string(forKey: "user_full_name")?.isEmpty != false {
            UserDefaults.standard.set(fullName, forKey: "user_full_name")
        }
        if let email, !email.isEmpty,
           UserDefaults.standard.string(forKey: "user_email")?.isEmpty != false {
            UserDefaults.standard.set(email, forKey: "user_email")
        }

        // 4. Update CoreData Person.name if still a placeholder
        if let resolvedName = displayName, !resolvedName.isEmpty {
            let context = PersistenceController.shared.container.viewContext
            await context.perform {
                let person = CurrentUser.getOrCreate(in: context)
                let current = person.name ?? ""
                if current.isEmpty || current == "Me" || current == "User" || current == "You" {
                    person.name = resolvedName
                    try? context.save()
                }
            }
        }

        // Only update if we have Apple data to push
        guard displayName != nil || fullName != nil || email != nil else { return }

        do {
            var updates: [String: String?] = [:]
            if let displayName { updates["display_name"] = displayName }
            if let fullName { updates["full_name"] = fullName }
            if let email { updates["email"] = email }

            try await SupabaseConfig.client.from("profiles")
                .update(updates)
                .eq("id", value: userId.uuidString)
                .execute()
        } catch {
            AppLogger.auth.warning("syncAppleMetadataToProfile failed: \(error.localizedDescription)")
        }
    }

    /// Query Supabase to check if the user's profile already has a phone number.
    /// Skips PhoneEntryView for returning users (e.g., app reinstall).
    private func checkProfileHasPhone(userId: UUID) async {
        // Ensure trigger-created profile exists before checking phone
        await ensureProfileExists(userId: userId)

        do {
            let profiles: [ProfileDTO] = try await SupabaseConfig.client.from("profiles")
                .select("*")
                .eq("id", value: userId.uuidString)
                .execute().value

            if let profile = profiles.first,
               let phone = profile.phone, !phone.isEmpty {
                // Phone already collected — cache and proceed
                UserDefaults.standard.set(true, forKey: "user_phone_collected")
                UserDefaults.standard.set(phone, forKey: "user_phone_e164")

                // Hydrate CoreData + local caches from the remote profile
                let context = PersistenceController.shared.container.viewContext
                await context.perform {
                    let person = CurrentUser.getOrCreate(in: context)
                    let currentName = person.name ?? ""

                    // Only overwrite placeholder names — preserve user-customized names
                    if currentName.isEmpty || currentName == "Me" || currentName == "User" || currentName == "You" {
                        let remoteName = profile.displayName
                        if !remoteName.isEmpty {
                            person.name = remoteName
                        }
                    }

                    if person.phoneNumber?.isEmpty != false {
                        person.phoneNumber = phone
                    }

                    if person.colorHex == nil || person.colorHex == AppColors.defaultAvatarColorHex {
                        if let remoteColor = profile.colorHex, !remoteColor.isEmpty {
                            person.colorHex = remoteColor
                        }
                    }

                    try? context.save()
                }

                // Restore local caches from remote profile
                if let remoteEmail = profile.email, !remoteEmail.isEmpty {
                    UserDefaults.standard.set(remoteEmail, forKey: "user_email")
                    KeychainHelper.save(key: "apple_email", value: remoteEmail)
                }
                if let remoteFull = profile.fullName, !remoteFull.isEmpty {
                    UserDefaults.standard.set(remoteFull, forKey: "user_full_name")
                }
                let remoteDisplay = profile.displayName
                if !remoteDisplay.isEmpty {
                    UserDefaults.standard.set(remoteDisplay, forKey: "apple_given_name")
                }

                authState = .authenticated
            } else {
                authState = .needsPhoneEntry
            }
        } catch {
            AppLogger.auth.warning("checkProfileHasPhone failed: \(error.localizedDescription)")
            authState = .needsPhoneEntry // safe fallback — phone gate is re-entrant
        }
    }

    // MARK: - Apple Credential State

    /// Checks whether the user's Apple credential is still valid.
    /// Signs out if the credential has been revoked or is not found.
    func checkAppleCredentialState() async {
        guard authState == .authenticated,
              let appleUserId = KeychainHelper.read(key: "apple_user_id")
        else { return }

        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: appleUserId)
            if state == .revoked || state == .notFound {
                await signOut()
            }
        } catch {
            // Can't determine state — don't sign out on transient errors
        }
    }

    // MARK: - Sign in with Apple

    /// Configures the Apple Sign-In request with a cryptographic nonce and requested scopes.
    /// Call this from the `SignInWithAppleButton` request handler.
    func prepareAppleSignIn(request: ASAuthorizationAppleIDRequest) {
        let rawNonce = generateNonce()
        currentNonce = rawNonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = sha256(rawNonce)
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let identityToken = credential.identityToken,
              let idToken = String(data: identityToken, encoding: .utf8)
        else {
            errorMessage = "Unable to retrieve identity token."
            throw AuthError.missingToken
        }

        // Store Apple User ID in Keychain for credential revocation checks
        KeychainHelper.save(key: "apple_user_id", value: credential.user)

        try await SupabaseConfig.client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: currentNonce
            )
        )
        currentNonce = nil

        // Apple only provides the user's full name on first sign-in.
        // Persist to UserDefaults since Apple won't provide it again.
        if let fullName = credential.fullName {
            var nameParts: [String] = []
            if let givenName = fullName.givenName {
                nameParts.append(givenName)
                UserDefaults.standard.set(givenName, forKey: "apple_given_name")
            }
            if let familyName = fullName.familyName {
                nameParts.append(familyName)
                UserDefaults.standard.set(familyName, forKey: "apple_family_name")
            }

            let fullNameString = nameParts.joined(separator: " ")
            if !fullNameString.isEmpty {
                UserDefaults.standard.set(fullNameString, forKey: "apple_full_name")
                do {
                    try await SupabaseConfig.client.auth.update(
                        user: UserAttributes(
                            data: [
                                "full_name": .string(fullNameString),
                                "given_name": .string(fullName.givenName ?? ""),
                                "family_name": .string(fullName.familyName ?? ""),
                            ]
                        )
                    )
                } catch {
                    AppLogger.auth.warning("auth.update metadata failed: \(error.localizedDescription)")
                }
            }
        }

        // Persist email in Keychain (may be Apple relay address)
        if let email = credential.email {
            KeychainHelper.save(key: "apple_email", value: email)
        }

        // Migrate legacy local data if needed
        await migrateLegacyUserIfNeeded()
    }

    // MARK: - Sign Out

    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        // Tear down realtime before signing out
        await RealtimeService.shared.unsubscribe()
        await ConversationService.shared.unsubscribe()

        do {
            try await SupabaseConfig.client.auth.signOut()
        } catch {
            // Even if remote sign-out fails, clear local state
        }

        currentUserId = nil
        lastHandledUserId = nil
        CurrentUser.reset()

        // Clear Keychain (sensitive data)
        KeychainHelper.delete(key: "apple_user_id")
        KeychainHelper.delete(key: "apple_email")

        // Clear UserDefaults (non-sensitive)
        // NOTE: Keep apple_given_name, apple_family_name, apple_full_name across
        // sign-out because Apple only provides the name on the FIRST sign-in ever.
        // These are recovered from session.user.userMetadata on re-login, but
        // preserving locally avoids a race condition on slow networks.
        UserDefaults.standard.set(false, forKey: "has_seen_onboarding")
        UserDefaults.standard.removeObject(forKey: "supabase_migration_completed")
        UserDefaults.standard.removeObject(forKey: "lastSyncTimestamp")
        UserDefaults.standard.removeObject(forKey: "lastContactDiscoveryDate")
        UserDefaults.standard.removeObject(forKey: "user_email")
        UserDefaults.standard.removeObject(forKey: "user_full_name")
        UserDefaults.standard.removeObject(forKey: "user_phone_collected")
        UserDefaults.standard.removeObject(forKey: "user_phone_e164")

        authState = .unauthenticated
    }

    /// Transitions from the phone entry gate to authenticated state.
    func completePhoneEntry() {
        guard authState == .needsPhoneEntry else { return }
        authState = .authenticated
    }

    // MARK: - Legacy Migration

    private func migrateLegacyUserIfNeeded() async {
        guard let newUserId = currentUserId else { return }

        let legacyKey = "legacy_user_migrated"
        guard !UserDefaults.standard.bool(forKey: legacyKey) else { return }

        // Check if there's a legacy UUID that differs from the Supabase user
        if let legacyIdString = UserDefaults.standard.string(forKey: "currentUserId"),
           let legacyId = UUID(uuidString: legacyIdString),
           legacyId != newUserId
        {
            let context = PersistenceController.shared.container.viewContext
            await context.perform {
                let request: NSFetchRequest<Person> = Person.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", legacyId as CVarArg)
                request.fetchLimit = 1

                if let legacyPerson = try? context.fetch(request).first {
                    legacyPerson.id = newUserId
                    try? context.save()
                }
            }
        }

        UserDefaults.standard.set(true, forKey: legacyKey)
    }

    // MARK: - Nonce Helpers

    /// Generates a cryptographically random nonce (hex-encoded).
    private func generateNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(status == errSecSuccess, "Failed to generate random nonce")
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Returns the SHA-256 hash of the input string (hex-encoded).
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Phone Linking

    /// Links a phone number to the current Apple Sign-In account.
    /// Two-step flow: first call with `confirmMerge: false` to check for conflicts,
    /// then `confirmMerge: true` to execute the merge if a conflict was found.
    func linkPhoneToAccount(phone: String, phoneHash: String, confirmMerge: Bool = false) async throws -> PhoneLinkResult {
        let body = PhoneLinkRequest(phone: phone, phoneHash: phoneHash, confirmMerge: confirmMerge)
        let response: PhoneLinkResult = try await SupabaseConfig.client.functions.invoke(
            "link-phone-to-account",
            options: .init(body: body)
        )
        return response
    }

    // MARK: - Error Types

    enum AuthError: LocalizedError {
        case missingToken

        var errorDescription: String? {
            switch self {
            case .missingToken:
                return "Unable to retrieve identity token from Apple."
            }
        }
    }
}

// MARK: - Phone Link Types

/// Request body for the `link-phone-to-account` edge function.
private struct PhoneLinkRequest: Encodable {
    let phone: String
    let phoneHash: String
    let confirmMerge: Bool

    enum CodingKeys: String, CodingKey {
        case phone
        case phoneHash = "phone_hash"
        case confirmMerge = "confirm_merge"
    }
}

/// Response from the `link-phone-to-account` edge function.
struct PhoneLinkResult: Decodable {
    let action: String          // "phone_set", "conflict", "accounts_merged", "error"
    let merged: Bool
    let existingProfileId: String?
    let existingDisplayName: String?
    let dataTransferred: [String: Int]?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case action
        case merged
        case existingProfileId = "existing_profile_id"
        case existingDisplayName = "existing_display_name"
        case dataTransferred = "data_transferred"
        case error
    }
}

// MARK: - Backward Compatibility

/// Typealias so existing references to SupabaseManager continue to compile.
typealias SupabaseManager = AuthManager
