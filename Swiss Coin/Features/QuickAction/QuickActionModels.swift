//
//  QuickActionModels.swift
//  Swiss Coin
//
//  Models for the Quick Action Transaction flow.
//

import CoreData
import SwiftUI

// MARK: - Enums

/// Type of transaction
enum TransactionType: String, CaseIterable {
    case expense = "expense"
    case income = "income"
}

/// Available methods for splitting a transaction
enum QuickActionSplitMethod: String, CaseIterable, Identifiable {
    case equal = "equal"  // Split evenly among all participants
    case amounts = "amounts"  // Each person pays a specific amount
    case percentages = "percentages"  // Each person pays a percentage
    case shares = "shares"  // Split by number of shares
    case adjustment = "adjustment"  // Equal split with +/- adjustments

    var id: String { rawValue }

    /// Display name for the split method
    var displayName: String {
        switch self {
        case .equal: return "Equally"
        case .amounts: return "By Amount"
        case .percentages: return "By Percent"
        case .shares: return "By Shares"
        case .adjustment: return "Adjustments"
        }
    }

    /// Icon/symbol representing the split method
    var icon: String {
        switch self {
        case .equal: return "="
        case .amounts: return "$"
        case .percentages: return "%"
        case .shares: return "÷"
        case .adjustment: return "±"
        }
    }
}

// MARK: - Helper Structs

/// Supported currencies with their symbols and display information
struct Currency: Identifiable, Hashable {
    let id: String  // Currency code (e.g., "USD")
    let code: String  // Same as id, for display
    let symbol: String  // Currency symbol (e.g., "$")
    let name: String  // Full name (e.g., "US Dollar")
    let flag: String  // Country flag emoji

    // TODO: Populate from API or configuration
    static let all: [Currency] = []
}

/// Transaction categories for organizing expenses/income
struct Category: Identifiable, Hashable {
    let id: String  // Unique identifier
    let name: String  // Category name
    let icon: String  // Emoji icon
    let color: Color  // Theme color

    // TODO: Populate from API or configuration
    static let all: [Category] = []
}

/// Stores the calculated split details for each participant
struct SplitDetail {
    var amount: Double = 0  // Calculated amount this person owes/paid
    var percentage: Double = 0  // Percentage of total (for display)
    var shares: Int = 1  // Number of shares (for shares method)
    var adjustment: Double = 0  // Adjustment amount (for adjustment method)
}
