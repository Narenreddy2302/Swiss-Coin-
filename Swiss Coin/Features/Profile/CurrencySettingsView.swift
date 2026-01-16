//
//  CurrencySettingsView.swift
//  Swiss Coin
//
//  View for managing currency preferences.
//

import SwiftUI

struct CurrencySettingsView: View {
    @AppStorage("default_currency") private var defaultCurrency = "USD"
    @AppStorage("show_currency_symbol") private var showCurrencySymbol = true
    @AppStorage("decimal_places") private var decimalPlaces = 2

    @State private var searchText = ""

    // Available currencies
    private let currencies: [CurrencyOption] = [
        CurrencyOption(code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸"),
        CurrencyOption(code: "EUR", name: "Euro", symbol: "€", flag: "🇪🇺"),
        CurrencyOption(code: "GBP", name: "British Pound", symbol: "£", flag: "🇬🇧"),
        CurrencyOption(code: "INR", name: "Indian Rupee", symbol: "₹", flag: "🇮🇳"),
        CurrencyOption(code: "JPY", name: "Japanese Yen", symbol: "¥", flag: "🇯🇵"),
        CurrencyOption(code: "AUD", name: "Australian Dollar", symbol: "A$", flag: "🇦🇺"),
        CurrencyOption(code: "CAD", name: "Canadian Dollar", symbol: "CA$", flag: "🇨🇦"),
        CurrencyOption(code: "CHF", name: "Swiss Franc", symbol: "CHF", flag: "🇨🇭"),
        CurrencyOption(code: "CNY", name: "Chinese Yuan", symbol: "¥", flag: "🇨🇳"),
        CurrencyOption(code: "MXN", name: "Mexican Peso", symbol: "MX$", flag: "🇲🇽"),
        CurrencyOption(code: "BRL", name: "Brazilian Real", symbol: "R$", flag: "🇧🇷"),
        CurrencyOption(code: "KRW", name: "South Korean Won", symbol: "₩", flag: "🇰🇷"),
        CurrencyOption(code: "SGD", name: "Singapore Dollar", symbol: "S$", flag: "🇸🇬"),
        CurrencyOption(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$", flag: "🇭🇰"),
        CurrencyOption(code: "NZD", name: "New Zealand Dollar", symbol: "NZ$", flag: "🇳🇿"),
        CurrencyOption(code: "SEK", name: "Swedish Krona", symbol: "kr", flag: "🇸🇪"),
        CurrencyOption(code: "NOK", name: "Norwegian Krone", symbol: "kr", flag: "🇳🇴"),
        CurrencyOption(code: "DKK", name: "Danish Krone", symbol: "kr", flag: "🇩🇰"),
        CurrencyOption(code: "ZAR", name: "South African Rand", symbol: "R", flag: "🇿🇦"),
        CurrencyOption(code: "AED", name: "UAE Dirham", symbol: "د.إ", flag: "🇦🇪")
    ]

    private var filteredCurrencies: [CurrencyOption] {
        if searchText.isEmpty {
            return currencies
        }
        return currencies.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedCurrencyOption: CurrencyOption? {
        currencies.first { $0.code == defaultCurrency }
    }

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
            } header: {
                Text("Current Currency")
                    .font(AppTypography.subheadlineMedium())
            }

            // Display Settings
            Section {
                Toggle("Show Currency Symbol", isOn: $showCurrencySymbol)
                    .onChange(of: showCurrencySymbol) { _, _ in HapticManager.toggle() }

                Picker("Decimal Places", selection: $decimalPlaces) {
                    Text("0").tag(0)
                    Text("2").tag(2)
                }
                .onChange(of: decimalPlaces) { _, _ in
                    HapticManager.selectionChanged()
                }

                // Format preview
                HStack {
                    Text("Preview")
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(formatPreview)
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)
                }
            } header: {
                Text("Display")
                    .font(AppTypography.subheadlineMedium())
            }

            // Currency Selection
            Section {
                ForEach(filteredCurrencies) { currency in
                    Button {
                        HapticManager.selectionChanged()
                        defaultCurrency = currency.code
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

                            if defaultCurrency == currency.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                }
            } header: {
                Text("Select Currency")
                    .font(AppTypography.subheadlineMedium())
            }
        }
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search currencies")
    }

    // MARK: - Computed Properties

    private var formatPreview: String {
        let amount = 1234.56
        let symbol = showCurrencySymbol ? (selectedCurrencyOption?.symbol ?? "$") : ""

        if decimalPlaces == 0 {
            return "\(symbol)1,235"
        } else {
            return "\(symbol)1,234.56"
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
