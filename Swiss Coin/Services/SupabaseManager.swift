//
//  SupabaseManager.swift
//  Swiss Coin
//
//  Authentication manager using local UUID identity.
//  Supabase auth removed — app works fully offline-first via CoreData.
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
    @Published var errorMessage: String?

    // MARK: - Init

    private init() {
        authenticateLocally()
    }

    // MARK: - Legacy Compatibility

    /// Authenticate locally with a persistent UUID identity
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

    // MARK: - Reset App

    /// Reset all user data and re-authenticate with a fresh identity
    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        currentUserId = nil
        CurrentUser.reset()
        UserDefaults.standard.set(false, forKey: "has_seen_onboarding")
        UserDefaults.standard.removeObject(forKey: "supabase_migration_completed")
        UserDefaults.standard.removeObject(forKey: "lastSyncTimestamp")

        // Re-authenticate with fresh identity
        authenticateLocally()
    }
}

// MARK: - Backward Compatibility

/// Typealias so existing references to SupabaseManager continue to compile.
typealias SupabaseManager = AuthManager
