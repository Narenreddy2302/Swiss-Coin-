//
//  CurrentUser.swift
//  Swiss Coin
//
//  Centralized current user management - stub for authentication integration.
//  TODO: Replace with actual authenticated user data from your auth provider.
//

import CoreData
import Foundation

/// Centralized current user identity management
/// This is a stub - values will be populated after authentication is integrated
struct CurrentUser {
    /// The UUID for the current user - nil until authenticated
    /// TODO: Set after authentication
    static var uuid: UUID? = nil

    /// The display name for the current user
    static var displayName: String = ""

    /// The initials for the current user
    static var initials: String = ""

    /// Default color hex for the current user's avatar (kept for UI fallback)
    static let defaultColorHex = "#34C759"

    /// Fetches or creates the current user Person entity
    /// - Parameter context: The managed object context to use
    /// - Returns: The current user Person entity (creates with empty values if uuid is nil)
    @discardableResult
    static func getOrCreate(in context: NSManagedObjectContext) -> Person {
        // If no uuid is set (not authenticated), create a placeholder user
        guard let userUUID = uuid else {
            // Create a placeholder user for unauthenticated state
            let placeholder = Person(context: context)
            placeholder.id = UUID()
            placeholder.name = "Not logged in"
            placeholder.colorHex = defaultColorHex
            return placeholder
        }

        // Try to fetch existing current user
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", userUUID as CVarArg)
        fetchRequest.fetchLimit = 1

        if let existingUser = try? context.fetch(fetchRequest).first {
            return existingUser
        }

        // Create new current user
        let newUser = Person(context: context)
        newUser.id = userUUID
        newUser.name = displayName.isEmpty ? "You" : displayName
        newUser.colorHex = defaultColorHex

        return newUser
    }

    /// Fetches the current user Person entity (returns nil if not found or not authenticated)
    /// - Parameter context: The managed object context to use
    /// - Returns: The current user Person entity or nil
    static func fetch(from context: NSManagedObjectContext) -> Person? {
        guard let userUUID = uuid else { return nil }

        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", userUUID as CVarArg)
        fetchRequest.fetchLimit = 1

        return try? context.fetch(fetchRequest).first
    }

    /// Checks if a given UUID belongs to the current user
    /// - Parameter id: The UUID to check
    /// - Returns: True if the UUID matches the current user (false if not authenticated)
    static func isCurrentUser(_ id: UUID?) -> Bool {
        guard let userUUID = uuid else { return false }
        return id == userUUID
    }

    /// Checks if a given Person is the current user
    /// - Parameter person: The Person to check
    /// - Returns: True if the Person is the current user (false if not authenticated)
    static func isCurrentUser(_ person: Person?) -> Bool {
        guard let userUUID = uuid else { return false }
        return person?.id == userUUID
    }
}
