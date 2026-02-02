//
//  SupabaseManager.swift
//  Swiss Coin
//
//  Local authentication manager. Handles auth state for the app.
//  No external dependencies or network calls — fully offline.
//

import Combine
import Foundation

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

    // MARK: - Init

    private init() {
        Task {
            await restoreSession()
        }
    }

    // MARK: - Session Management

    /// Restore previous session or auto-authenticate
    private func restoreSession() async {
        // Brief loading state for smooth UX transition
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s

        if UserDefaults.standard.bool(forKey: "swiss_coin_signed_out") {
            authState = .unauthenticated
        } else {
            // Auto-authenticate returning users
            authenticate()
        }
    }

    /// Authenticate the user locally
    func authenticate() {
        isLoading = true
        defer { isLoading = false }

        // Get existing user ID or create a new one
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

    /// Sign out the current user
    func signOut() {
        isLoading = true
        defer { isLoading = false }

        currentUserId = nil
        CurrentUser.reset()
        UserDefaults.standard.set(true, forKey: "swiss_coin_signed_out")
        authState = .unauthenticated
    }
}

// MARK: - Backward Compatibility

/// Typealias so existing references to SupabaseManager continue to compile.
typealias SupabaseManager = AuthManager
