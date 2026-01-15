//
//  CurrencyFormatter.swift
//  Swiss Coin
//
//  Shared currency formatting utility to avoid repeated NumberFormatter creation.
//

import Foundation

/// Shared currency formatting utility
enum CurrencyFormatter {
    /// Shared NumberFormatter instance for currency formatting
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Formats a Double value as currency string
    /// - Parameter amount: The amount to format
    /// - Returns: Formatted currency string (e.g., "$42.50")
    static func format(_ amount: Double) -> String {
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    /// Formats an absolute value as currency string
    /// - Parameter amount: The amount to format (will use absolute value)
    /// - Returns: Formatted currency string (e.g., "$42.50")
    static func formatAbsolute(_ amount: Double) -> String {
        return formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"
    }

    /// Formats a value with a sign prefix for positive values
    /// - Parameter amount: The amount to format
    /// - Returns: Formatted currency string with + prefix if positive (e.g., "+$42.50")
    static func formatWithSign(_ amount: Double) -> String {
        let formatted = format(abs(amount))
        if amount > 0 {
            return "+\(formatted)"
        }
        return formatted
    }

    /// Parses a currency string to Double
    /// - Parameter string: The string to parse (can contain $, commas)
    /// - Returns: Parsed Double value or nil if invalid
    static func parse(_ string: String) -> Double? {
        let cleaned = string
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }
}
