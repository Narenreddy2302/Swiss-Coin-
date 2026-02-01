//
//  Person+Extensions.swift
//  Swiss Coin
//
//  Extension providing computed properties and business logic for Person entity.
//

import Foundation

extension Person {
    
    // MARK: - Display Properties
    
    /// The display name for this person
    var displayName: String {
        name ?? "Unknown"
    }
    
    /// First name extracted from full name
    var firstName: String {
        guard let name = name, !name.isEmpty else { return "Unknown" }
        return String(name.split(separator: " ").first ?? "Unknown")
    }
    
    /// Last name extracted from full name
    var lastName: String {
        guard let name = name, !name.isEmpty else { return "" }
        let components = name.split(separator: " ")
        guard components.count > 1 else { return "" }
        return components.dropFirst().joined(separator: " ")
    }
    
    /// Initials for avatar display
    var initials: String {
        guard let name = name, !name.isEmpty else { return "?" }
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    /// Avatar color, falling back to default if not set
    var avatarColor: String {
        colorHex ?? "#808080"
    }
    
    // MARK: - Validation
    
    /// Whether this person has a valid name
    var hasValidName: Bool {
        guard let name = name else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Whether this person has a phone number
    var hasPhoneNumber: Bool {
        guard let phoneNumber = phoneNumber else { return false }
        return !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Whether this person has a profile photo
    var hasProfilePhoto: Bool {
        photoData != nil
    }
}