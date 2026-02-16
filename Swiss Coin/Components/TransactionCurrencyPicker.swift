import SwiftUI

// MARK: - Transaction Currency Picker

/// Reusable currency picker sheet for transaction views.
/// Binds to a currency code string (ISO 4217) and dismisses on selection.
struct TransactionCurrencyPicker: View {
    @Binding var selectedCurrencyCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let popularCodes: Set<String> = CurrencyFormatter.popularCurrencyCodes

    private var allCurrencies: [CurrencyFormatter.CurrencyConfig] {
        CurrencyFormatter.allSupportedCurrencies
    }

    private var filteredCurrencies: [CurrencyFormatter.CurrencyConfig] {
        if searchText.isEmpty {
            return allCurrencies
        }
        let query = searchText.lowercased()
        return allCurrencies.filter {
            $0.code.lowercased().contains(query)
            || $0.symbol.lowercased().contains(query)
            || currencyName(for: $0.code).lowercased().contains(query)
        }
    }

    private var popularCurrencies: [CurrencyFormatter.CurrencyConfig] {
        filteredCurrencies.filter { popularCodes.contains($0.code) }
    }

    private var otherCurrencies: [CurrencyFormatter.CurrencyConfig] {
        filteredCurrencies.filter { !popularCodes.contains($0.code) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(AppColors.textTertiary)

                    TextField("Search currencies...", text: $searchText)
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textPrimary)
                        .autocorrectionDisabled()

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: IconSize.sm))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(AppColors.cardBackground)

                Divider()

                // Currency list
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        if !popularCurrencies.isEmpty {
                            currencySection(title: "Popular", currencies: popularCurrencies)
                        }

                        if !otherCurrencies.isEmpty {
                            currencySection(title: "Other", currencies: otherCurrencies)
                        }

                        if filteredCurrencies.isEmpty {
                            HStack {
                                Spacer()
                                Text("No currencies found")
                                    .font(AppTypography.bodyDefault())
                                    .foregroundColor(AppColors.textSecondary)
                                Spacer()
                            }
                            .padding(.vertical, Spacing.xl)
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.tap()
                        dismiss()
                    }
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Currency Section

    private func currencySection(title: String, currencies: [CurrencyFormatter.CurrencyConfig]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.uppercased())
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)
                .tracking(AppTypography.Tracking.labelSmall)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                ForEach(Array(currencies.enumerated()), id: \.element.code) { index, currency in
                    currencyRow(currency)

                    if index < currencies.count - 1 {
                        Divider()
                            .padding(.leading, Spacing.lg + IconSize.lg + Spacing.md)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
            )
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Currency Row

    private func currencyRow(_ currency: CurrencyFormatter.CurrencyConfig) -> some View {
        let isSelected = selectedCurrencyCode == currency.code

        return Button {
            HapticManager.selectionChanged()
            selectedCurrencyCode = currency.code
            dismiss()
        } label: {
            HStack(spacing: Spacing.md) {
                Text(currency.flag)
                    .font(.system(size: IconSize.lg))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(currencyName(for: currency.code))
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(AppColors.textPrimary)

                    Text(currency.code)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Text(currency.symbol)
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(AppColors.textSecondary)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(AppTypography.headingMedium())
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(currencyName(for: currency.code)), \(currency.code)\(isSelected ? ", selected" : "")")
    }

    // MARK: - Currency Name Lookup

    private func currencyName(for code: String) -> String {
        let names: [String: String] = [
            "USD": "US Dollar",
            "EUR": "Euro",
            "GBP": "British Pound",
            "CHF": "Swiss Franc",
            "CAD": "Canadian Dollar",
            "AUD": "Australian Dollar",
            "JPY": "Japanese Yen",
            "INR": "Indian Rupee",
            "CNY": "Chinese Yuan",
            "KRW": "South Korean Won",
            "SGD": "Singapore Dollar",
            "AED": "UAE Dirham",
            "BRL": "Brazilian Real",
            "MXN": "Mexican Peso",
            "SEK": "Swedish Krona",
            "NZD": "New Zealand Dollar",
        ]
        return names[code] ?? code
    }
}

// MARK: - Preview

#Preview {
    TransactionCurrencyPicker(selectedCurrencyCode: .constant("USD"))
}
