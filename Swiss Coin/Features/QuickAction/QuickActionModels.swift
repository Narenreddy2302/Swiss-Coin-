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

/// Available methods for splitting a transaction.
/// Canonical enum used by both the Transaction and QuickAction flows.
enum SplitMethod: String, CaseIterable, Identifiable {
    case equal = "equal"            // Split evenly among all participants
    case amount = "amount"          // Each person pays a specific amount
    case percentage = "percentage"  // Each person pays a percentage
    case shares = "shares"          // Split by number of shares
    case adjustment = "adjustment"  // Equal split with +/- adjustments

    var id: String { rawValue }

    /// Display name for the split method
    var displayName: String {
        switch self {
        case .equal: return "Equally"
        case .amount: return "By Amount"
        case .percentage: return "By Percent"
        case .shares: return "By Shares"
        case .adjustment: return "Adjustments"
        }
    }

    /// Icon/symbol representing the split method
    var icon: String {
        switch self {
        case .equal: return "="
        case .amount: return CurrencyFormatter.currencySymbol
        case .percentage: return "%"
        case .shares: return "÷"
        case .adjustment: return "±"
        }
    }

    /// SF Symbol name for use in pickers and UI elements
    var systemImage: String {
        switch self {
        case .equal: return "equal"
        case .percentage: return "percent"
        case .amount: return "dollarsign.circle"
        case .adjustment: return "plus.forwardslash.minus"
        case .shares: return "chart.pie.fill"
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

    static let all: [Currency] = [
        Currency(id: "USD", code: "USD", symbol: "$",   name: "US Dollar",         flag: "🇺🇸"),
        Currency(id: "EUR", code: "EUR", symbol: "€",   name: "Euro",              flag: "🇪🇺"),
        Currency(id: "GBP", code: "GBP", symbol: "£",   name: "British Pound",     flag: "🇬🇧"),
        Currency(id: "INR", code: "INR", symbol: "₹",   name: "Indian Rupee",      flag: "🇮🇳"),
        Currency(id: "CNY", code: "CNY", symbol: "¥",   name: "Chinese Yuan",      flag: "🇨🇳"),
        Currency(id: "JPY", code: "JPY", symbol: "¥",   name: "Japanese Yen",      flag: "🇯🇵"),
        Currency(id: "CHF", code: "CHF", symbol: "CHF", name: "Swiss Franc",       flag: "🇨🇭"),
        Currency(id: "CAD", code: "CAD", symbol: "CA$", name: "Canadian Dollar",   flag: "🇨🇦"),
        Currency(id: "AUD", code: "AUD", symbol: "A$",  name: "Australian Dollar", flag: "🇦🇺"),
        Currency(id: "KRW", code: "KRW", symbol: "₩",   name: "South Korean Won",  flag: "🇰🇷"),
        Currency(id: "SGD", code: "SGD", symbol: "S$",  name: "Singapore Dollar",  flag: "🇸🇬"),
        Currency(id: "AED", code: "AED", symbol: "د.إ", name: "UAE Dirham",        flag: "🇦🇪"),
        Currency(id: "BRL", code: "BRL", symbol: "R$",  name: "Brazilian Real",    flag: "🇧🇷"),
        Currency(id: "MXN", code: "MXN", symbol: "MX$", name: "Mexican Peso",      flag: "🇲🇽"),
        Currency(id: "SEK", code: "SEK", symbol: "kr",  name: "Swedish Krona",     flag: "🇸🇪"),
    ]

    /// Returns the Currency matching the given code, or USD as fallback
    static func fromCode(_ code: String) -> Currency {
        all.first { $0.code == code } ?? all[0]
    }

    /// Returns the Currency matching the user's global currency setting
    static func fromGlobalSetting() -> Currency {
        let code = UserDefaults.standard.string(forKey: "default_currency") ?? "USD"
        return fromCode(code)
    }
}

/// Transaction categories for organizing expenses/income
struct Category: Identifiable, Hashable {
    let id: String  // Unique identifier
    let name: String  // Category name
    let icon: String  // Emoji icon
    let color: Color  // Theme color

    static let all: [Category] = [
        Category(id: "food", name: "Food & Drinks", icon: "🍽️", color: .orange),
        Category(id: "transport", name: "Transport", icon: "🚗", color: .blue),
        Category(id: "shopping", name: "Shopping", icon: "🛍️", color: .pink),
        Category(id: "entertainment", name: "Entertainment", icon: "🎬", color: .purple),
        Category(id: "bills", name: "Bills", icon: "📄", color: .indigo),
        Category(id: "health", name: "Health", icon: "💊", color: .red),
        Category(id: "travel", name: "Travel", icon: "✈️", color: .green),
        Category(id: "other", name: "Other", icon: "📦", color: .gray),
    ]
}

/// Stores the calculated split details for each participant
struct SplitDetail {
    var amount: Double = 0  // Calculated amount this person owes/paid
    var percentage: Double = 0  // Percentage of total (for display)
    var shares: Int = 1  // Number of shares (for shares method)
    var adjustment: Double = 0  // Adjustment amount (for adjustment method)
}
