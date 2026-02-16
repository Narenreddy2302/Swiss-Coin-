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

    struct CurrencyConfig {
        let code: String
        let locale: String
        let symbol: String
        let flag: String
    }

    /// Safe fallback for when a currency code isn't found in configs
    private static let usdFallback = CurrencyConfig(code: "USD", locale: "en_US", symbol: "$", flag: "🇺🇸")

    /// All supported currency configurations with locale and symbol mappings
    static let configs: [String: CurrencyConfig] = [
        "USD": CurrencyConfig(code: "USD", locale: "en_US",  symbol: "$",   flag: "🇺🇸"),
        "EUR": CurrencyConfig(code: "EUR", locale: "de_DE",  symbol: "€",   flag: "🇪🇺"),
        "GBP": CurrencyConfig(code: "GBP", locale: "en_GB",  symbol: "£",   flag: "🇬🇧"),
        "CHF": CurrencyConfig(code: "CHF", locale: "de_CH",  symbol: "CHF", flag: "🇨🇭"),
        "CAD": CurrencyConfig(code: "CAD", locale: "en_CA",  symbol: "CA$", flag: "🇨🇦"),
        "AUD": CurrencyConfig(code: "AUD", locale: "en_AU",  symbol: "A$",  flag: "🇦🇺"),
        "JPY": CurrencyConfig(code: "JPY", locale: "ja_JP",  symbol: "¥",   flag: "🇯🇵"),
        "INR": CurrencyConfig(code: "INR", locale: "en_IN",  symbol: "₹",   flag: "🇮🇳"),
        "CNY": CurrencyConfig(code: "CNY", locale: "zh_CN",  symbol: "¥",   flag: "🇨🇳"),
        "KRW": CurrencyConfig(code: "KRW", locale: "ko_KR",  symbol: "₩",   flag: "🇰🇷"),
        "SGD": CurrencyConfig(code: "SGD", locale: "en_SG",  symbol: "S$",  flag: "🇸🇬"),
        "AED": CurrencyConfig(code: "AED", locale: "en_AE",  symbol: "د.إ", flag: "🇦🇪"),
        "BRL": CurrencyConfig(code: "BRL", locale: "pt_BR",  symbol: "R$",  flag: "🇧🇷"),
        "MXN": CurrencyConfig(code: "MXN", locale: "es_MX",  symbol: "MX$", flag: "🇲🇽"),
        "SEK": CurrencyConfig(code: "SEK", locale: "sv_SE",  symbol: "kr",  flag: "🇸🇪"),
        "NZD": CurrencyConfig(code: "NZD", locale: "en_NZ",  symbol: "NZ$", flag: "🇳🇿"),
    ]

    /// All supported currencies sorted by code, for picker UIs
    static var allSupportedCurrencies: [CurrencyConfig] {
        configs.values.sorted { $0.code < $1.code }
    }

    /// Popular currencies for picker sections
    static let popularCurrencyCodes: Set<String> = [
        "USD", "EUR", "GBP", "CHF", "CAD", "AUD", "JPY", "INR"
    ]

    // MARK: - Formatter Cache (Global Default)

    /// Cached formatters are rebuilt whenever the selected currency changes.
    private static var _cachedCode: String?
    private static var _currencyFmt: NumberFormatter?
    private static var _decimalFmt: NumberFormatter?

    // MARK: - Per-Currency Formatter Cache (Thread-Safe)

    private static let cacheLock = NSLock()
    private static var _currencyFmtCache: [String: NumberFormatter] = [:]
    private static var _decimalFmtCache: [String: NumberFormatter] = [:]
    private static let maxCacheSize = 20

    /// Reads the user's selected currency code from UserDefaults
    private static var selectedCode: String {
        UserDefaults.standard.string(forKey: "default_currency") ?? "USD"
    }

    /// Returns the config for the currently selected currency (falls back to USD)
    private static var currentConfig: CurrencyConfig {
        configs[selectedCode] ?? usdFallback
    }

    /// Ensures cached formatters match the current currency selection; rebuilds if stale.
    private static func ensureCache() {
        let code = selectedCode
        guard _cachedCode != code else { return }

        let config = configs[code] ?? usdFallback
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

    /// Builds a currency NumberFormatter for a given code (not cached by this method).
    private static func buildCurrencyFormatter(for code: String) -> NumberFormatter {
        let config = configs[code] ?? usdFallback
        let isZeroDecimal = (code == "JPY" || code == "KRW")
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = config.code
        formatter.locale = Locale(identifier: config.locale)
        formatter.maximumFractionDigits = isZeroDecimal ? 0 : 2
        formatter.minimumFractionDigits = isZeroDecimal ? 0 : 2
        return formatter
    }

    /// Builds a decimal NumberFormatter for a given code (not cached by this method).
    private static func buildDecimalFormatter(for code: String) -> NumberFormatter {
        let config = configs[code] ?? usdFallback
        let isZeroDecimal = (code == "JPY" || code == "KRW")
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: config.locale)
        formatter.maximumFractionDigits = isZeroDecimal ? 0 : 2
        formatter.minimumFractionDigits = isZeroDecimal ? 0 : 2
        return formatter
    }

    /// Returns a cached currency formatter for the given code, creating one if needed.
    private static func cachedCurrencyFormatter(for code: String) -> NumberFormatter {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = _currencyFmtCache[code] { return cached }
        if _currencyFmtCache.count >= maxCacheSize {
            _currencyFmtCache.removeAll()
            _decimalFmtCache.removeAll()
        }
        let formatter = buildCurrencyFormatter(for: code)
        _currencyFmtCache[code] = formatter
        return formatter
    }

    /// Returns a cached decimal formatter for the given code, creating one if needed.
    private static func cachedDecimalFormatter(for code: String) -> NumberFormatter {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = _decimalFmtCache[code] { return cached }
        if _decimalFmtCache.count >= maxCacheSize {
            _decimalFmtCache.removeAll()
            _currencyFmtCache.removeAll()
        }
        let formatter = buildDecimalFormatter(for: code)
        _decimalFmtCache[code] = formatter
        return formatter
    }

    // MARK: - Public Properties (Global Default)

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

    /// Whether the currently selected currency uses zero decimal places (e.g., JPY, KRW)
    static var isZeroDecimalCurrency: Bool {
        let code = selectedCode
        return code == "JPY" || code == "KRW"
    }

    // MARK: - Per-Currency Public Properties

    /// Returns the symbol for a specific currency code.
    static func symbol(for currencyCode: String) -> String {
        (configs[currencyCode] ?? usdFallback).symbol
    }

    /// Returns the flag emoji for a specific currency code.
    static func flag(for currencyCode: String) -> String {
        (configs[currencyCode] ?? usdFallback).flag
    }

    /// Whether a specific currency code uses zero decimal places (e.g., JPY, KRW)
    static func isZeroDecimal(_ currencyCode: String) -> Bool {
        currencyCode == "JPY" || currencyCode == "KRW"
    }

    // MARK: - Public Methods (Global Default)

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

    // MARK: - Per-Currency Public Methods

    /// Formats an amount using a specific currency code (not the global default).
    /// - Parameters:
    ///   - amount: The amount to format
    ///   - currencyCode: ISO 4217 currency code (e.g., "USD", "EUR")
    /// - Returns: Formatted string (e.g., "$29.99", "€29,99")
    static func format(_ amount: Double, currencyCode: String) -> String {
        let formatter = cachedCurrencyFormatter(for: currencyCode)
        let config = configs[currencyCode] ?? usdFallback
        return formatter.string(from: NSNumber(value: amount))
            ?? "\(config.symbol)\(String(format: "%.2f", amount))"
    }

    /// Formats an absolute amount (always positive) with a specific currency.
    static func formatAbsolute(_ amount: Double, currencyCode: String) -> String {
        return format(abs(amount), currencyCode: currencyCode)
    }

    /// Formats an amount without currency symbol for a specific currency code.
    static func formatDecimal(_ amount: Double, currencyCode: String) -> String {
        let formatter = cachedDecimalFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }

    /// Formats an amount with explicit sign for a specific currency code.
    static func formatWithSign(_ amount: Double, currencyCode: String) -> String {
        let formatted = format(abs(amount), currencyCode: currencyCode)
        if amount > 0.01 {
            return "+\(formatted)"
        } else if amount < -0.01 {
            return "-\(formatted)"
        } else {
            return formatted
        }
    }

    // MARK: - Parsing

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
