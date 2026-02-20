//
//  CountryCodePicker.swift
//  Swiss Coin
//
//  Searchable picker for selecting a phone country code.
//

import SwiftUI

struct CountryCodePicker: View {
    @Binding var selectedCountry: CountryCode
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredCountries: [CountryCode] {
        if searchText.isEmpty {
            return CountryCode.all
        }
        let query = searchText.lowercased()
        return CountryCode.all.filter {
            $0.name.lowercased().contains(query)
                || $0.dialCode.contains(query)
                || $0.id.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredCountries) { country in
                Button {
                    HapticManager.tap()
                    selectedCountry = country
                    dismiss()
                } label: {
                    HStack(spacing: Spacing.md) {
                        Text(country.flag)
                            .font(.system(size: IconSize.lg))

                        Text(country.name)
                            .font(AppTypography.bodyLarge())
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Text(country.dialCode)
                            .font(AppTypography.bodyDefault())
                            .foregroundColor(AppColors.textSecondary)

                        if country.id == selectedCountry.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: IconSize.sm))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .navigationTitle("Country Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.tap()
                        dismiss()
                    }
                    .font(AppTypography.bodyLarge())
                }
            }
        }
    }
}
