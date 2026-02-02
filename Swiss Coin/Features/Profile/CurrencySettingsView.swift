//
//  CurrencySettingsView.swift
//  Swiss Coin
//
//  View for managing currency preferences.
//

import SwiftUI

struct CurrencySettingsView: View {
    @AppStorage("default_currency") private var selectedCurrency = "USD"

    @State private var searchText = ""

    // MARK: - Currency Data

    private let popularCurrencies: [CurrencyOption] = [
        CurrencyOption(code: "USD", name: "US Dollar",         symbol: "$",   flag: "🇺🇸"),
        CurrencyOption(code: "EUR", name: "Euro",              symbol: "€",   flag: "🇪🇺"),
        CurrencyOption(code: "GBP", name: "British Pound",     symbol: "£",   flag: "🇬🇧"),
        CurrencyOption(code: "JPY", name: "Japanese Yen",      symbol: "¥",   flag: "🇯🇵"),
        CurrencyOption(code: "CHF", name: "Swiss Franc",       symbol: "CHF", flag: "🇨🇭"),
        CurrencyOption(code: "CAD", name: "Canadian Dollar",   symbol: "CA$", flag: "🇨🇦"),
        CurrencyOption(code: "AUD", name: "Australian Dollar", symbol: "A$",  flag: "🇦🇺"),
        CurrencyOption(code: "INR", name: "Indian Rupee",      symbol: "₹",   flag: "🇮🇳"),
    ]

    private let otherCurrencies: [CurrencyOption] = [
        CurrencyOption(code: "CNY", name: "Chinese Yuan",       symbol: "¥",   flag: "🇨🇳"),
        CurrencyOption(code: "KRW", name: "South Korean Won",   symbol: "₩",   flag: "🇰🇷"),
        CurrencyOption(code: "SGD", name: "Singapore Dollar",   symbol: "S$",  flag: "🇸🇬"),
        CurrencyOption(code: "AED", name: "UAE Dirham",         symbol: "د.إ", flag: "🇦🇪"),
        CurrencyOption(code: "BRL", name: "Brazilian Real",     symbol: "R$",  flag: "🇧🇷"),
        CurrencyOption(code: "MXN", name: "Mexican Peso",       symbol: "MX$", flag: "🇲🇽"),
        CurrencyOption(code: "SEK", name: "Swedish Krona",      symbol: "kr",  flag: "🇸🇪"),
    ]

    private var allCurrencies: [CurrencyOption] {
        popularCurrencies + otherCurrencies
    }

    // MARK: - Filtered Lists

    private var filteredPopular: [CurrencyOption] {
        guard !searchText.isEmpty else { return popularCurrencies }
        return popularCurrencies.filter { matches($0) }
    }

    private var filteredOther: [CurrencyOption] {
        guard !searchText.isEmpty else { return otherCurrencies }
        return otherCurrencies.filter { matches($0) }
    }

    private func matches(_ option: CurrencyOption) -> Bool {
        option.name.localizedCaseInsensitiveContains(searchText) ||
        option.code.localizedCaseInsensitiveContains(searchText) ||
        option.symbol.localizedCaseInsensitiveContains(searchText)
    }

    private var selectedCurrencyOption: CurrencyOption? {
        allCurrencies.first { $0.code == selectedCurrency }
    }

    // MARK: - Body

    var body: some View {
        Form {
            // Current Selection
            Section {
                if let selected = selectedCurrencyOption {
                    HStack(spacing: Spacing.md) {
                        Text(selected.flag)
                            .font(.system(size: 32))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.name)
                                .font(AppTypography.headline())
                                .foregroundColor(AppColors.textPrimary)

                            Text("\(selected.code) (\(selected.symbol))")
                                .font(AppTypography.subheadline())
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.positive)
                    }
                    .padding(.vertical, Spacing.sm)
                }

                // Live format preview
                HStack {
                    Text("Preview")
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(CurrencyFormatter.format(1234.56))
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)
                }
            } header: {
                Text("Current Currency")
                    .font(AppTypography.subheadlineMedium())
            }

            // Popular Currencies
            if !filteredPopular.isEmpty {
                Section {
                    ForEach(filteredPopular) { currency in
                        currencyRow(currency)
                    }
                } header: {
                    Text("Popular")
                        .font(AppTypography.subheadlineMedium())
                }
            }

            // Other Currencies
            if !filteredOther.isEmpty {
                Section {
                    ForEach(filteredOther) { currency in
                        currencyRow(currency)
                    }
                } header: {
                    Text("Other")
                        .font(AppTypography.subheadlineMedium())
                }
            }
        }
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search currencies")
    }

    // MARK: - Currency Row

    @ViewBuilder
    private func currencyRow(_ currency: CurrencyOption) -> some View {
        Button {
            HapticManager.selectionChanged()
            selectedCurrency = currency.code
        } label: {
            HStack(spacing: Spacing.md) {
                Text(currency.flag)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.name)
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    Text("\(currency.code) (\(currency.symbol))")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if selectedCurrency == currency.code {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

// MARK: - Currency Option Model

struct CurrencyOption: Identifiable, Hashable {
    let code: String
    let name: String
    let symbol: String
    let flag: String

    var id: String { code }
}
