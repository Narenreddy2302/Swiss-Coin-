//
//  SupabaseManager.swift
//  Swiss Coin
//
//  Authentication manager backed by Supabase Auth.
//  Supports phone OTP login. Apple Sign-In deferred to Phase 2.
//

import Combine
import Foundation
import Supabase

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case authenticated
    case unauthenticated
}

// MARK: - Auth Manager

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    // MARK: - Published Properties

    @Published private(set) var authState: AuthState = .unknown
    @Published private(set) var isLoading = false
    @Published private(set) var currentUserId: UUID?
    @Published var errorMessage: String?

    private var authListenerTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        listenToAuthChanges()
        Task {
            await restoreSession()
        }
    }

    deinit {
        authListenerTask?.cancel()
    }

    // MARK: - Auth State Listener

    /// Listen for auth state changes from the Supabase SDK
    private func listenToAuthChanges() {
        authListenerTask = Task { [weak self] in
            for await (event, session) in SupabaseConfig.client.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .signedIn:
                    if let userId = session?.user.id {
                        self.currentUserId = userId
                        CurrentUser.setCurrentUser(id: userId)
                        self.authState = .authenticated
                    }
                case .signedOut:
                    self.currentUserId = nil
                    self.authState = .unauthenticated
                case .tokenRefreshed:
                    break // SDK handles token refresh automatically
                default:
                    break
                }
            }
        }
    }

    // MARK: - Session Management

    /// Restore previous session or transition to unauthenticated
    private func restoreSession() async {
        do {
            let session = try await SupabaseConfig.client.auth.session
            currentUserId = session.user.id
            CurrentUser.setCurrentUser(id: session.user.id)
            authState = .authenticated
        } catch {
            // No valid session — check for legacy local user
            if UserDefaults.standard.string(forKey: "currentUserId") != nil {
                // User had local data — show login so they can link their account
                authState = .unauthenticated
            } else {
                authState = .unauthenticated
            }
        }
    }

    // MARK: - Phone OTP Authentication

    /// Send a one-time password to the given phone number
    /// - Parameter phone: Phone number in E.164 format (e.g., "+1234567890")
    func sendPhoneOTP(phone: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await SupabaseConfig.client.auth.signInWithOTP(phone: phone)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Verify the OTP code sent to the phone number
    /// - Parameters:
    ///   - phone: Phone number in E.164 format
    ///   - token: 6-digit OTP code
    func verifyPhoneOTP(phone: String, token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await SupabaseConfig.client.auth.verifyOTP(
                phone: phone,
                token: token,
                type: .sms
            )
            // Auth state change listener handles the rest
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Legacy Compatibility

    /// Authenticate locally for offline mode or development
    /// Falls back to local UUID if Supabase is unavailable
    func authenticateLocally() {
        isLoading = true
        defer { isLoading = false }

        let userId: UUID
        if let existingId = CurrentUser.currentUserId {
            userId = existingId
        } else {
            userId = UUID()
            CurrentUser.setCurrentUser(id: userId)
        }

        currentUserId = userId
        UserDefaults.standard.set(false, forKey: "swiss_coin_signed_out")
        authState = .authenticated
    }

    // MARK: - Sign Out

    /// Sign out the current user from Supabase and clear local state
    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await SupabaseConfig.client.auth.signOut()
        } catch {
            // Sign out locally even if Supabase call fails
        }

        currentUserId = nil
        CurrentUser.reset()
        UserDefaults.standard.set(true, forKey: "swiss_coin_signed_out")
        authState = .unauthenticated
    }

    /// Check if the current user has existing local data that needs migration
    var needsDataMigration: Bool {
        let hasLocalData = UserDefaults.standard.string(forKey: "currentUserId") != nil
        let migrationDone = UserDefaults.standard.bool(forKey: "supabase_migration_completed")
        return hasLocalData && !migrationDone
    }
}

// MARK: - Backward Compatibility

/// Typealias so existing references to SupabaseManager continue to compile.
typealias SupabaseManager = AuthManager
