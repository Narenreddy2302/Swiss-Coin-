//
//  CurrencyBalance.swift
//  Swiss Coin
//
//  Multi-currency balance tracking value type.
//  Replaces Double for balance calculations to track per-currency amounts.
//

import Foundation

struct CurrencyBalance {
    private(set) var balances: [String: Double] = [:]

    mutating func add(_ amount: Double, currency: String) {
        balances[currency, default: 0] += amount
    }

    mutating func subtract(_ amount: Double, currency: String) {
        balances[currency, default: 0] -= amount
    }

    mutating func merge(_ other: CurrencyBalance) {
        for (code, amount) in other.balances {
            balances[code, default: 0] += amount
        }
    }

    /// Filter out near-zero entries (|x| < 0.01)
    var nonZero: [String: Double] {
        balances.filter { abs($0.value) >= 0.01 }
    }

    /// Sorted by |amount| descending
    var sortedCurrencies: [(code: String, amount: Double)] {
        nonZero
            .map { (code: $0.key, amount: $0.value) }
            .sorted { abs($0.amount) > abs($1.amount) }
    }

    /// All balances are zero
    var isSettled: Bool {
        nonZero.isEmpty
    }

    /// Non-nil if exactly one currency has a non-zero balance
    var singleCurrency: String? {
        let nz = nonZero
        return nz.count == 1 ? nz.keys.first : nil
    }

    /// Any currency where they owe you (positive balance)
    var hasPositive: Bool {
        nonZero.values.contains { $0 > 0.01 }
    }

    /// Any currency where you owe them (negative balance)
    var hasNegative: Bool {
        nonZero.values.contains { $0 < -0.01 }
    }

    /// The primary (largest absolute) balance amount, or 0
    var primaryAmount: Double {
        sortedCurrencies.first?.amount ?? 0
    }

    /// The primary currency code, or the global default
    var primaryCurrency: String {
        sortedCurrencies.first?.code ?? (UserDefaults.standard.string(forKey: "default_currency") ?? "USD")
    }

    /// Number of currencies with non-zero balances
    var currencyCount: Int {
        nonZero.count
    }
}
