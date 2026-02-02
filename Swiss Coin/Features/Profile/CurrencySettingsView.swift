//
//  CurrencySettingsView.swift
//  Swiss Coin
//
//  Simplified currency settings with card-based design.
//

import SwiftUI

struct CurrencySettingsView: View {
    @AppStorage("default_currency") private var selectedCurrency = "USD"
    @State private var searchText = ""

    private let popularCurrencies: [CurrencyOption] = [
        CurrencyOption(code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸"),
        CurrencyOption(code: "EUR", name: "Euro", symbol: "€", flag: "🇪🇺"),
        CurrencyOption(code: "GBP", name: "British Pound", symbol: "£", flag: "🇬🇧"),
        CurrencyOption(code: "CHF", name: "Swiss Franc", symbol: "CHF", flag: "🇨🇭"),
        CurrencyOption(code: "CAD", name: "Canadian Dollar", symbol: "CA$", flag: "🇨🇦"),
        CurrencyOption(code: "AUD", name: "Australian Dollar", symbol: "A$", flag: "🇦🇺"),
        CurrencyOption(code: "JPY", name: "Japanese Yen", symbol: "¥", flag: "🇯🇵"),
        CurrencyOption(code: "INR", name: "Indian Rupee", symbol: "₹", flag: "🇮🇳"),
    ]

    private let otherCurrencies: [CurrencyOption] = [
        CurrencyOption(code: "CNY", name: "Chinese Yuan", symbol: "¥", flag: "🇨🇳"),
        CurrencyOption(code: "KRW", name: "South Korean Won", symbol: "₩", flag: "🇰🇷"),
        CurrencyOption(code: "SGD", name: "Singapore Dollar", symbol: "S$", flag: "🇸🇬"),
        CurrencyOption(code: "AED", name: "UAE Dirham", symbol: "د.إ", flag: "🇦🇪"),
        CurrencyOption(code: "BRL", name: "Brazilian Real", symbol: "R$", flag: "🇧🇷"),
        CurrencyOption(code: "MXN", name: "Mexican Peso", symbol: "MX$", flag: "🇲🇽"),
        CurrencyOption(code: "SEK", name: "Swedish Krona", symbol: "kr", flag: "🇸🇪"),
        CurrencyOption(code: "NZD", name: "New Zealand Dollar", symbol: "NZ$", flag: "🇳🇿"),
    ]

    private var allCurrencies: [CurrencyOption] {
        popularCurrencies + otherCurrencies
    }

    private var filteredCurrencies: [CurrencyOption] {
        if searchText.isEmpty {
            return allCurrencies
        }
        return allCurrencies.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedCurrencyOption: CurrencyOption? {
        allCurrencies.first { $0.code == selectedCurrency }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundSecondary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // Current Selection Card
                    if let selected = selectedCurrencyOption {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Current Currency")
                                .font(AppTypography.headline())
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, Spacing.sm)

                            HStack(spacing: Spacing.md) {
                                Text(selected.flag)
                                    .font(.system(size: 40))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selected.name)
                                        .font(AppTypography.headline())
                                        .foregroundColor(AppColors.textPrimary)

                                    Text("\(selected.code) • \(selected.symbol)")
                                        .font(AppTypography.subheadline())
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.positive)
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(AppColors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .strokeBorder(AppColors.accent.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal)

                            // Preview
                            HStack {
                                Text("Preview")
                                    .font(AppTypography.subheadline())
                                    .foregroundColor(AppColors.textSecondary)
                                Spacer()
                                Text(CurrencyFormatter.format(1234.56))
                                    .font(AppTypography.amount())
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(AppColors.backgroundTertiary)
                            )
                            .padding(.horizontal)
                        }
                    }

                    // Search Bar
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)

                        TextField("Search currencies", text: $searchText)
                            .font(AppTypography.body())

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(AppColors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                    )
                    .padding(.horizontal)

                    // Currency List
                    if !filteredCurrencies.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Select Currency")
                                .font(AppTypography.headline())
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, Spacing.sm)

                            VStack(spacing: 0) {
                                ForEach(Array(filteredCurrencies.enumerated()), id: \.element.id) { index, currency in
                                    CurrencyRow(
                                        currency: currency,
                                        isSelected: selectedCurrency == currency.code
                                    ) {
                                        HapticManager.selectionChanged()
                                        selectedCurrency = currency.code
                                    }

                                    if index < filteredCurrencies.count - 1 {
                                        Divider()
                                            .padding(.leading, 70)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(AppColors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                            )
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: Spacing.lg) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.textSecondary)
                            Text("No currencies found")
                                .font(AppTypography.subheadline())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xxl)
                    }
                }
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.section)
            }
        }
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Currency Row

private struct CurrencyRow: View {
    let currency: CurrencyOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Text(currency.flag)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.name)
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    Text("\(currency.code) (\(currency.symbol))")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.accent)
                } else {
                    Circle()
                        .strokeBorder(AppColors.textTertiary.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

#Preview {
    NavigationStack {
        CurrencySettingsView()
    }
}
