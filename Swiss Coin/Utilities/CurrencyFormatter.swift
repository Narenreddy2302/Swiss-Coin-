//
//  CurrencyFormatter.swift
//  Swiss Coin
//
//  Multi-currency formatting utility with user-selectable currency support.
//  Reads the selected currency from UserDefaults ("default_currency"), defaulting to USD.
//

import Foundation

/// Utility for formatting currency amounts using the user's selected currency.
/// Call any static method directly — no instance needed.
final class CurrencyFormatter {

    // MARK: - Currency Configuration

    private struct CurrencyConfig {
        let code: String
        let locale: String
        let symbol: String
        let flag: String
    }

    /// All supported currency configurations with locale and symbol mappings
    private static let configs: [String: CurrencyConfig] = [
        "USD": CurrencyConfig(code: "USD", locale: "en_US",  symbol: "$",   flag: "🇺🇸"),
        "EUR": CurrencyConfig(code: "EUR", locale: "de_DE",  symbol: "€",   flag: "🇪🇺"),
        "GBP": CurrencyConfig(code: "GBP", locale: "en_GB",  symbol: "£",   flag: "🇬🇧"),
        "INR": CurrencyConfig(code: "INR", locale: "en_IN",  symbol: "₹",   flag: "🇮🇳"),
        "CNY": CurrencyConfig(code: "CNY", locale: "zh_CN",  symbol: "¥",   flag: "🇨🇳"),
        "JPY": CurrencyConfig(code: "JPY", locale: "ja_JP",  symbol: "¥",   flag: "🇯🇵"),
        "CHF": CurrencyConfig(code: "CHF", locale: "de_CH",  symbol: "CHF", flag: "🇨🇭"),
        "CAD": CurrencyConfig(code: "CAD", locale: "en_CA",  symbol: "CA$", flag: "🇨🇦"),
        "AUD": CurrencyConfig(code: "AUD", locale: "en_AU",  symbol: "A$",  flag: "🇦🇺"),
        "KRW": CurrencyConfig(code: "KRW", locale: "ko_KR",  symbol: "₩",   flag: "🇰🇷"),
        "SGD": CurrencyConfig(code: "SGD", locale: "en_SG",  symbol: "S$",  flag: "🇸🇬"),
        "AED": CurrencyConfig(code: "AED", locale: "en_AE",  symbol: "د.إ", flag: "🇦🇪"),
        "BRL": CurrencyConfig(code: "BRL", locale: "pt_BR",  symbol: "R$",  flag: "🇧🇷"),
        "MXN": CurrencyConfig(code: "MXN", locale: "es_MX",  symbol: "MX$", flag: "🇲🇽"),
        "SEK": CurrencyConfig(code: "SEK", locale: "sv_SE",  symbol: "kr",  flag: "🇸🇪"),
    ]

    // MARK: - Formatter Cache

    /// Cached formatters are rebuilt whenever the selected currency changes.
    private static var _cachedCode: String?
    private static var _currencyFmt: NumberFormatter?
    private static var _decimalFmt: NumberFormatter?

    /// Reads the user's selected currency code from UserDefaults
    private static var selectedCode: String {
        UserDefaults.standard.string(forKey: "default_currency") ?? "USD"
    }

    /// Returns the config for the currently selected currency (falls back to USD)
    private static var currentConfig: CurrencyConfig {
        configs[selectedCode] ?? configs["USD"]!
    }

    /// Ensures cached formatters match the current currency selection; rebuilds if stale.
    private static func ensureCache() {
        let code = selectedCode
        guard _cachedCode != code else { return }

        let config = configs[code] ?? configs["USD"]!
        let isZeroDecimal = (code == "JPY" || code == "KRW")

        let cf = NumberFormatter()
        cf.numberStyle = .currency
        cf.currencyCode = config.code
        cf.locale = Locale(identifier: config.locale)
        cf.maximumFractionDigits = isZeroDecimal ? 0 : 2
        cf.minimumFractionDigits = isZeroDecimal ? 0 : 2

        let df = NumberFormatter()
        df.numberStyle = .decimal
        df.locale = Locale(identifier: config.locale)
        df.maximumFractionDigits = isZeroDecimal ? 0 : 2
        df.minimumFractionDigits = isZeroDecimal ? 0 : 2

        _cachedCode = code
        _currencyFmt = cf
        _decimalFmt = df
    }

    // MARK: - Public Properties

    /// The currency symbol for the currently selected currency (e.g., "$", "€", "CHF")
    static var currencySymbol: String {
        currentConfig.symbol
    }

    /// The flag emoji for the currently selected currency (e.g., "🇺🇸", "🇪🇺")
    static var currencyFlag: String {
        currentConfig.flag
    }

    /// The ISO 4217 currency code for the currently selected currency (e.g., "USD", "EUR")
    static var currencyCode: String {
        currentConfig.code
    }

    // MARK: - Public Methods

    /// Formats an amount using the user's selected currency with full locale formatting.
    /// - Parameter amount: The amount to format
    /// - Returns: Formatted string (e.g., "$29.99", "€29,99", "CHF 29.99")
    static func format(_ amount: Double) -> String {
        ensureCache()
        return _currencyFmt?.string(from: NSNumber(value: amount))
            ?? "\(currencySymbol)\(String(format: "%.2f", amount))"
    }

    /// Formats an absolute amount (always positive) with currency symbol.
    /// - Parameter amount: The amount to format (will be made positive)
    /// - Returns: Formatted string (e.g., "$29.99")
    static func formatAbsolute(_ amount: Double) -> String {
        return format(abs(amount))
    }

    /// Formats an amount without currency symbol (for calculations display).
    /// - Parameter amount: The amount to format
    /// - Returns: Formatted decimal string (e.g., "29.99")
    static func formatDecimal(_ amount: Double) -> String {
        ensureCache()
        return _decimalFmt?.string(from: NSNumber(value: amount)) ?? "0.00"
    }

    /// Formats an amount with explicit sign for balance display.
    /// - Parameter amount: The amount to format
    /// - Returns: Formatted string with + or - (e.g., "+$29.99", "-$15.50")
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

    /// Formats an amount as a decimal without currency symbol for compact display.
    /// - Parameter amount: The amount to format
    /// - Returns: Compact formatted string (e.g., "29.99")
    static func formatCompact(_ amount: Double) -> String {
        return formatDecimal(amount)
    }

    /// Parses a formatted currency string back to Double.
    /// Handles the current currency's symbols as well as legacy CHF/Fr. formats.
    /// - Parameter string: The formatted currency string
    /// - Returns: The parsed amount, or nil if invalid
    static func parse(_ string: String) -> Double? {
        ensureCache()

        // Try direct decimal parsing first
        if let number = _decimalFmt?.number(from: string) {
            return number.doubleValue
        }

        // Try removing current currency symbols
        let config = currentConfig
        var cleaned = string
            .replacingOccurrences(of: config.code, with: "")
            .replacingOccurrences(of: config.symbol, with: "")

        // Also handle legacy CHF/Fr. symbols for backward compatibility
        cleaned = cleaned
            .replacingOccurrences(of: "CHF", with: "")
            .replacingOccurrences(of: "Fr.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let number = _decimalFmt?.number(from: cleaned) {
            return number.doubleValue
        }

        // Last resort: strip grouping separators and try standard parsing
        let stripped = cleaned
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "") // non-breaking space
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(stripped)
    }
}
