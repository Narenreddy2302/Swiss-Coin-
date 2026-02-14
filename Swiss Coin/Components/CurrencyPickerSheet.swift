//
//  CurrencyPickerSheet.swift
//  Swiss Coin
//
//  Currency picker sheet for selecting transaction currency.
//

import SwiftUI

struct CurrencyPickerSheet: View {
    @Binding var selectedCurrency: Currency
    @Binding var isPresented: Bool
    @State private var searchText = ""

    private var filteredCurrencies: [Currency] {
        if searchText.isEmpty {
            return Currency.all
        }
        return Currency.all.filter { currency in
            currency.name.localizedCaseInsensitiveContains(searchText) ||
            currency.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCurrencies) { currency in
                    Button(action: {
                        HapticManager.selectionChanged()
                        selectedCurrency = currency
                        isPresented = false
                    }) {
                        HStack(spacing: Spacing.md) {
                            Text(currency.flag)
                                .font(.system(size: 28))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(currency.name)
                                    .font(AppTypography.bodyDefault())
                                    .foregroundColor(AppColors.textPrimary)

                                Text(currency.code)
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            Text(currency.symbol)
                                .font(AppTypography.headingMedium())
                                .foregroundColor(AppColors.textSecondary)

                            if selectedCurrency.id == currency.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search currencies")
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(AppTypography.bodyDefault())
                }
            }
        }
    }
}

#Preview {
    CurrencyPickerSheet(
        selectedCurrency: .constant(Currency.fromCode("USD")),
        isPresented: .constant(true)
    )
}
