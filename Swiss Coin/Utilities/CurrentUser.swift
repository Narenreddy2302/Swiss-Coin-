//
//  CurrentUser.swift
//  Swiss Coin
//
//  Centralized current user identity management for production.
//  Integrates with both local CoreData and remote Supabase.
//  Requires authentication before accessing user data.
//

import Combine
import CoreData
import Foundation
import SwiftUI

// MARK: - Current User Manager

/// Centralized current user identity and state management
@MainActor
final class CurrentUserManager: ObservableObject {
    static let shared = CurrentUserManager()

    // MARK: - Published Properties

    @Published private(set) var userId: UUID?
    @Published private(set) var displayName: String = "You"
    @Published private(set) var phoneNumber: String?
    @Published private(set) var avatarUrl: String?
    @Published private(set) var colorHex: String = "#34C759"
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    @Published private(set) var profile: UserProfile?

    // MARK: - Settings (synced with @AppStorage)

    @AppStorage("default_currency") var defaultCurrency = "USD"
    @AppStorage("theme_mode") var themeMode = "system"
    @AppStorage("accent_color") var accentColor = "#007AFF"
    @AppStorage("font_size") var fontSize = "medium"
    @AppStorage("reduce_motion") var reduceMotion = false
    @AppStorage("haptic_feedback") var hapticFeedback = true

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let supabase = SupabaseManager.shared

    // MARK: - Init

    private init() {
        setupBindings()
    }

    // MARK: - Bindings

    private func setupBindings() {
        // Listen to auth state changes
        supabase.$authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .authenticated(let userId):
                    self?.userId = userId
                    self?.isAuthenticated = true
                    Task { await self?.loadProfile() }
                case .unauthenticated:
                    self?.userId = nil
                    self?.isAuthenticated = false
                    self?.resetToDefaults()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Profile Management

    /// Load user profile from Supabase
    func loadProfile() async {
        guard isAuthenticated else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await supabase.getUserProfile()
            self.profile = profile

            // Update local properties
            if let name = profile.displayName {
                self.displayName = name
            }
            self.phoneNumber = profile.phoneNumber
            self.avatarUrl = profile.avatarUrl

            // Sync settings to AppStorage
            if let settings = profile.settings {
                self.themeMode = settings.themeMode
                self.accentColor = settings.accentColor
                self.fontSize = settings.fontSize
                self.reduceMotion = settings.reduceMotion
                self.hapticFeedback = settings.hapticFeedback
                self.defaultCurrency = settings.defaultCurrency
            }
        } catch {
            print("Failed to load profile: \(error.localizedDescription)")
        }
    }

    /// Update display name
    func updateDisplayName(_ name: String) async throws {
        let update = UserSettingsUpdate()
        // Note: display_name is in profiles table, would need separate update
        self.displayName = name

        // Also update local CoreData
        if let context = try? PersistenceController.shared.container.viewContext,
           let person = CurrentUser.fetch(from: context) {
            person.name = name
            try? context.save()
        }
    }

    /// Update avatar color
    func updateColor(_ color: String) async throws {
        self.colorHex = color

        // Update local CoreData
        if let context = try? PersistenceController.shared.container.viewContext,
           let person = CurrentUser.fetch(from: context) {
            person.colorHex = color
            try? context.save()
        }
    }

    /// Update currency preference
    func updateCurrency(_ currency: String) async throws {
        self.defaultCurrency = currency

        guard isAuthenticated else { return }

        var update = UserSettingsUpdate()
        update.defaultCurrency = currency
        try await supabase.updateUserSettings(update)
    }

    /// Update theme mode
    func updateThemeMode(_ mode: String) async throws {
        self.themeMode = mode

        guard isAuthenticated else { return }

        var update = UserSettingsUpdate()
        update.themeMode = mode
        try await supabase.updateUserSettings(update)
    }

    /// Update appearance settings
    func updateAppearance(accentColor: String? = nil, fontSize: String? = nil, reduceMotion: Bool? = nil, hapticFeedback: Bool? = nil) async throws {
        if let color = accentColor { self.accentColor = color }
        if let size = fontSize { self.fontSize = size }
        if let motion = reduceMotion { self.reduceMotion = motion }
        if let haptic = hapticFeedback { self.hapticFeedback = haptic }

        guard isAuthenticated else { return }

        var update = UserSettingsUpdate()
        update.accentColor = accentColor
        update.fontSize = fontSize
        update.reduceMotion = reduceMotion
        update.hapticFeedbackEnabled = hapticFeedback
        try await supabase.updateUserSettings(update)
    }

    /// Reset to default values
    private func resetToDefaults() {
        displayName = "You"
        phoneNumber = nil
        avatarUrl = nil
        colorHex = "#34C759"
        profile = nil
    }

    // MARK: - Computed Properties

    var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first, first.count >= 2 {
            return String(first.prefix(2)).uppercased()
        }
        return "ME"
    }
}

// MARK: - Static Helpers (Backward Compatibility)

/// Static helpers for backward compatibility with existing code
struct CurrentUser {
    /// Fallback UUID when not authenticated (should not be used in production)
    private static let fallbackUUID = UUID()

    /// Current user UUID - requires authentication
    static var uuid: UUID {
        guard let userId = CurrentUserManager.shared.userId else {
            // In production, this should only be reached during initial app load
            return fallbackUUID
        }
        return userId
    }

    /// Display name for the current user
    static var displayName: String {
        CurrentUserManager.shared.displayName
    }

    /// Initials for the current user
    static var initials: String {
        CurrentUserManager.shared.initials
    }

    /// Default color hex for the current user's avatar
    static var defaultColorHex: String {
        CurrentUserManager.shared.colorHex
    }

    /// Check if user is authenticated with Supabase
    static var isAuthenticated: Bool {
        CurrentUserManager.shared.isAuthenticated
    }

    /// Fetches or creates the current user Person entity
    /// - Parameter context: The managed object context to use
    /// - Returns: The current user Person entity
    @discardableResult
    static func getOrCreate(in context: NSManagedObjectContext) -> Person {
        // Try to fetch existing current user
        if let existingUser = fetch(from: context) {
            return existingUser
        }

        // Create new current user
        let newUser = Person(context: context)
        newUser.id = uuid
        newUser.name = displayName
        newUser.colorHex = defaultColorHex

        return newUser
    }

    /// Fetches the current user Person entity (returns nil if not found)
    /// - Parameter context: The managed object context to use
    /// - Returns: The current user Person entity or nil
    static func fetch(from context: NSManagedObjectContext) -> Person? {
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        fetchRequest.fetchLimit = 1

        return try? context.fetch(fetchRequest).first
    }

    /// Checks if a given UUID belongs to the current user
    /// - Parameter id: The UUID to check
    /// - Returns: True if the UUID matches the current user
    static func isCurrentUser(_ id: UUID?) -> Bool {
        return id == uuid
    }

    /// Checks if a given Person is the current user
    /// - Parameter person: The Person to check
    /// - Returns: True if the Person is the current user
    static func isCurrentUser(_ person: Person?) -> Bool {
        return person?.id == uuid
    }

    /// Sync local CoreData user with Supabase profile
    static func syncWithRemote(context: NSManagedObjectContext) async {
        guard isAuthenticated else { return }

        let manager = CurrentUserManager.shared
        await manager.loadProfile()

        // Update local CoreData entity
        if let person = fetch(from: context) {
            person.name = manager.displayName
            person.colorHex = manager.colorHex
            try? context.save()
        }
    }
}

// MARK: - Environment Key

private struct CurrentUserManagerKey: EnvironmentKey {
    static let defaultValue = CurrentUserManager.shared
}

extension EnvironmentValues {
    var currentUserManager: CurrentUserManager {
        get { self[CurrentUserManagerKey.self] }
        set { self[CurrentUserManagerKey.self] = newValue }
    }
}
