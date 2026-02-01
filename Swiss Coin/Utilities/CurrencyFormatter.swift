//
//  CurrencyFormatter.swift
//  Swiss Coin
//
//  Swiss-localized currency formatting utility for consistent money display.
//

import Foundation

/// Utility for formatting currency amounts in Swiss Franc (CHF)
final class CurrencyFormatter {
    
    // MARK: - Static Formatters
    
    /// Swiss Franc formatter with symbol
    private static let chfFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CHF"
        formatter.locale = Locale(identifier: "de_CH") // Swiss German locale
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()
    
    /// Decimal formatter for calculations
    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = Locale(identifier: "de_CH")
        return formatter
    }()
    
    // MARK: - Public Methods
    
    /// Formats an amount as Swiss Francs with currency symbol
    /// - Parameter amount: The amount to format
    /// - Returns: Formatted string (e.g., "CHF 29.99")
    static func format(_ amount: Double) -> String {
        return chfFormatter.string(from: NSNumber(value: amount)) ?? "CHF 0.00"
    }
    
    /// Formats an absolute amount (always positive) with currency symbol
    /// - Parameter amount: The amount to format (will be made positive)
    /// - Returns: Formatted string (e.g., "CHF 29.99")
    static func formatAbsolute(_ amount: Double) -> String {
        return format(abs(amount))
    }
    
    /// Formats an amount without currency symbol (for calculations display)
    /// - Parameter amount: The amount to format
    /// - Returns: Formatted decimal string (e.g., "29.99")
    static func formatDecimal(_ amount: Double) -> String {
        return decimalFormatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }
    
    /// Formats an amount with explicit sign for balance display
    /// - Parameter amount: The amount to format
    /// - Returns: Formatted string with + or - (e.g., "+CHF 29.99", "-CHF 15.50")
    static func formatWithSign(_ amount: Double) -> String {
        let formatted = format(abs(amount))
        if amount > 0.01 {
            return "+\(formatted)"
        } else if amount < -0.01 {
            return "-\(formatted)"
        } else {
            return formatted
        }
    }
    
    /// Formats a short amount for compact display (removes minor currency code)
    /// - Parameter amount: The amount to format  
    /// - Returns: Compact formatted string (e.g., "29.99")
    static func formatCompact(_ amount: Double) -> String {
        let full = format(amount)
        // Remove "CHF " prefix for compact display
        return full.replacingOccurrences(of: "CHF ", with: "")
    }
    
    /// Parses a formatted currency string back to Double
    /// - Parameter string: The formatted currency string
    /// - Returns: The parsed amount, or nil if invalid
    static func parse(_ string: String) -> Double? {
        // Try direct number parsing first
        if let number = decimalFormatter.number(from: string) {
            return number.doubleValue
        }
        
        // Try removing currency symbols and parsing
        let cleaned = string
            .replacingOccurrences(of: "CHF", with: "")
            .replacingOccurrences(of: "Fr.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let number = decimalFormatter.number(from: cleaned) {
            return number.doubleValue
        }
        
        return nil
    }
}