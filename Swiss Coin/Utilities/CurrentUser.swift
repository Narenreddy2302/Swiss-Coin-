//
//  CurrentUser.swift
//  Swiss Coin
//
//  Centralized current user identity management.
//  Uses a fixed UUID to identify the current user across all views and calculations.
//

import CoreData
import Foundation

/// Centralized current user identity management
struct CurrentUser {
    /// Fixed UUID for the current user - ensures consistency across the app
    static let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Display name for the current user
    static let displayName = "You"

    /// Initials for the current user
    static let initials = "ME"

    /// Default color hex for the current user's avatar
    static let defaultColorHex = "#34C759"

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
}
