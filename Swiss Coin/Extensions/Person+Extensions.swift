//
//  Person+Extensions.swift
//  Swiss Coin
//
//  Extension providing computed properties and convenience methods for Person entity.
//

import Foundation
import SwiftUI

extension Person {
    
    // MARK: - Display Properties
    
    /// User-friendly display name with fallback
    var displayName: String {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Unknown Person"
        }
        return name
    }
    
    /// First name extracted from full name
    var firstName: String {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Unknown"
        }
        
        // Split by whitespace and take first component
        let components = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            .components(separatedBy: .whitespacesAndNewlines)
                            .filter { !$0.isEmpty }
        
        return components.first ?? "Unknown"
    }
    
    /// Initials for avatar display (up to 2 characters)
    var initials: String {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "?"
        }
        
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines)
                          .filter { !$0.isEmpty }
        
        if words.count >= 2 {
            // Take first letter of first two words
            let first = String(words[0].prefix(1)).uppercased()
            let second = String(words[1].prefix(1)).uppercased()
            return first + second
        } else if words.count == 1 {
            let word = words[0]
            if word.count >= 2 {
                // Take first two letters of single word
                return String(word.prefix(2)).uppercased()
            } else {
                // Single letter
                return String(word.prefix(1)).uppercased()
            }
        } else {
            return "?"
        }
    }
    
    /// Full name with safety for empty strings
    var safeName: String {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Unnamed Person"
        }
        return name
    }
    
    // MARK: - Avatar and Color Properties
    
    /// Safe color hex with fallback
    var safeColorHex: String {
        return colorHex ?? AppColors.defaultAvatarColorHex
    }
    
    /// Color for UI display
    var displayColor: Color {
        return Color(hex: safeColorHex)
    }
    
    /// Background color for avatar (lighter version of main color)
    var avatarBackgroundColor: Color {
        return Color(hex: safeColorHex).opacity(0.2)
    }
    
    /// Text color for avatar (the main color)
    var avatarTextColor: Color {
        return Color(hex: safeColorHex)
    }
    
    // MARK: - Contact Information
    
    /// Formatted phone number with safety
    var formattedPhoneNumber: String? {
        guard let phone = phoneNumber, !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        // Basic formatting - could be enhanced for Swiss phone number formats
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Simple formatting for Swiss numbers
        if cleaned.hasPrefix("41") && cleaned.count == 11 {
            // +41 XX XXX XX XX format
            let areaCode = String(cleaned.dropFirst(2).prefix(2))
            let number = String(cleaned.dropFirst(4))
            let part1 = String(number.prefix(3))
            let part2 = String(number.dropFirst(3).prefix(2))
            let part3 = String(number.dropFirst(5))
            return "+41 \(areaCode) \(part1) \(part2) \(part3)"
        } else if cleaned.count == 9 {
            // 0XX XXX XX XX format
            let areaCode = String(cleaned.prefix(3))
            let remaining = String(cleaned.dropFirst(3))
            let part1 = String(remaining.prefix(3))
            let part2 = String(remaining.dropFirst(3).prefix(2))
            let part3 = String(remaining.dropFirst(5))
            return "\(areaCode) \(part1) \(part2) \(part3)"
        }
        
        return phone // Return original if no formatting rule matches
    }
    
    /// Whether the person has contact information
    var hasContactInfo: Bool {
        return phoneNumber?.isEmpty == false
    }
    
    /// Whether the person has a custom avatar photo
    var hasCustomPhoto: Bool {
        return photoData != nil
    }
    
    // MARK: - Badge Activity Detection

    /// Whether this person has new transactions or settlements since last viewed
    var hasNewActivity: Bool {
        let cutoff = max(
            lastViewedDate ?? .distantPast,
            CurrentUser.badgeFeatureActivationDate
        )
        // Check transaction splits involving this person
        if let splits = owedSplits as? Set<TransactionSplit> {
            for split in splits {
                if let txDate = split.transaction?.date, txDate > cutoff {
                    return true
                }
            }
        }
        // Check settlements (sent + received)
        if let sent = sentSettlements as? Set<Settlement> {
            for s in sent {
                if let d = s.date, d > cutoff { return true }
            }
        }
        if let received = receivedSettlements as? Set<Settlement> {
            for s in received {
                if let d = s.date, d > cutoff { return true }
            }
        }
        return false
    }

    // MARK: - Swiss Coin Status

    /// Whether this person is a registered Swiss Coin user
    var swissCoinBadgeText: String? {
        isOnSwissCoin ? "On Swiss Coin" : nil
    }

    /// Whether cross-user messaging is available with this person
    var canDirectMessage: Bool {
        isOnSwissCoin && linkedProfileId != nil
    }

    // MARK: - Comparison and Sorting
    
    /// Sort descriptor for alphabetical name sorting
    static var alphabeticalSortDescriptor: NSSortDescriptor {
        return NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
    }
    
    /// Compare two persons for sorting
    func compare(to other: Person) -> ComparisonResult {
        return self.displayName.localizedCaseInsensitiveCompare(other.displayName)
    }
}