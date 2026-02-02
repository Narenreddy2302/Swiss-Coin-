//
//  CurrentUser.swift
//  Swiss Coin
//
//  Utility for managing the current user's identity and data.
//

import CoreData
import Foundation

/// Utility for managing current user operations
final class CurrentUser {
    
    // MARK: - Static Properties
    
    /// The current user's unique identifier
    /// This would typically be stored in UserDefaults or Keychain
    private static var _currentUserId: UUID? = {
        // For demo purposes, create a consistent UUID
        // In production, this would be loaded from secure storage
        if let stored = UserDefaults.standard.string(forKey: "currentUserId") {
            return UUID(uuidString: stored)
        } else {
            let newId = UUID()
            UserDefaults.standard.set(newId.uuidString, forKey: "currentUserId")
            return newId
        }
    }()
    
    /// Current user's default color for UI elements
    static let defaultColorHex = AppColors.defaultAvatarColorHex
    
    /// Current user's display name
    static let displayName = "You"
    
    /// Current user's initials for avatar display
    static let initials = "ME"
    
    // MARK: - Public Methods
    
    /// Check if a given UUID belongs to the current user
    /// - Parameter id: UUID to check (can be nil)
    /// - Returns: true if the ID matches the current user
    static func isCurrentUser(_ id: UUID?) -> Bool {
        guard let id = id else { return false }
        return id == _currentUserId
    }
    
    /// Get or create the current user's Person entity in CoreData
    /// - Parameter context: NSManagedObjectContext to work with
    /// - Returns: The current user's Person entity
    static func getOrCreate(in context: NSManagedObjectContext) -> Person {
        guard let userId = _currentUserId else {
            // Fallback: create new user
            return createNewUser(in: context)
        }
        
        // Try to find existing user
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
        request.fetchLimit = 1
        
        do {
            if let existingUser = try context.fetch(request).first {
                return existingUser
            }
        } catch {
            print("Error fetching current user: \(error)")
        }
        
        // User not found, create new one
        return createNewUser(in: context, id: userId)
    }
    
    /// Create a new user entity
    /// - Parameters:
    ///   - context: NSManagedObjectContext to work with
    ///   - id: Optional UUID to use (generates new if nil)
    /// - Returns: New Person entity representing the current user
    static func createNewUser(in context: NSManagedObjectContext, id: UUID? = nil) -> Person {
        let user = Person(context: context)
        user.id = id ?? UUID()
        user.name = "Me" // Default name
        user.colorHex = AppColors.defaultAvatarColorHex
        user.phoneNumber = nil // Will be set when user adds it
        user.photoData = nil // Will be set when user adds photo
        
        // Update stored user ID if we created a new one
        if _currentUserId == nil {
            _currentUserId = user.id
            UserDefaults.standard.set(user.id?.uuidString, forKey: "currentUserId")
        }
        
        return user
    }
    
    /// Update the current user's profile information
    /// - Parameters:
    ///   - name: New name for the user
    ///   - colorHex: New color preference
    ///   - phoneNumber: Phone number
    ///   - context: NSManagedObjectContext to work with
    static func updateProfile(name: String?, colorHex: String?, phoneNumber: String?, in context: NSManagedObjectContext) {
        let user = getOrCreate(in: context)
        
        if let name = name {
            user.name = name
        }
        if let colorHex = colorHex {
            user.colorHex = colorHex
        }
        if let phoneNumber = phoneNumber {
            user.phoneNumber = phoneNumber
        }
        
        do {
            try context.save()
        } catch {
            context.rollback()
            print("Error saving user profile: \(error.localizedDescription)")
        }
    }
    
    /// Get the current user ID (for storage/sync purposes)
    /// - Returns: Current user's UUID
    static var currentUserId: UUID? {
        return _currentUserId
    }
    
    /// Reset current user (for logout/account switching)
    static func reset() {
        _currentUserId = nil
        UserDefaults.standard.removeObject(forKey: "currentUserId")
    }
    
    /// Set current user ID (for login/account switching)
    /// - Parameter id: UUID of the user to make current
    static func setCurrentUser(id: UUID) {
        _currentUserId = id
        UserDefaults.standard.set(id.uuidString, forKey: "currentUserId")
    }
}