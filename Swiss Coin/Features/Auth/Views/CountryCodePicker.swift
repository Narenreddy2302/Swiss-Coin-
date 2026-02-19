//
//  CountryCodePicker.swift
//  Swiss Coin
//
//  Country code model and searchable picker for phone number entry.
//

import SwiftUI

// MARK: - Country Code Model

struct CountryCode: Identifiable, Hashable {
    let id: String  // ISO alpha-2
    let name: String
    let dialCode: String
    let flag: String  // emoji

    // MARK: - Default

    static let switzerland = CountryCode(id: "CH", name: "Switzerland", dialCode: "+41", flag: "\u{1F1E8}\u{1F1ED}")

    // MARK: - All Countries

    static let all: [CountryCode] = [
        CountryCode(id: "CH", name: "Switzerland", dialCode: "+41", flag: "\u{1F1E8}\u{1F1ED}"),
        CountryCode(id: "US", name: "United States", dialCode: "+1", flag: "\u{1F1FA}\u{1F1F8}"),
        CountryCode(id: "GB", name: "United Kingdom", dialCode: "+44", flag: "\u{1F1EC}\u{1F1E7}"),
        CountryCode(id: "DE", name: "Germany", dialCode: "+49", flag: "\u{1F1E9}\u{1F1EA}"),
        CountryCode(id: "FR", name: "France", dialCode: "+33", flag: "\u{1F1EB}\u{1F1F7}"),
        CountryCode(id: "IT", name: "Italy", dialCode: "+39", flag: "\u{1F1EE}\u{1F1F9}"),
        CountryCode(id: "AT", name: "Austria", dialCode: "+43", flag: "\u{1F1E6}\u{1F1F9}"),
        CountryCode(id: "IN", name: "India", dialCode: "+91", flag: "\u{1F1EE}\u{1F1F3}"),
        CountryCode(id: "AU", name: "Australia", dialCode: "+61", flag: "\u{1F1E6}\u{1F1FA}"),
        CountryCode(id: "CA", name: "Canada", dialCode: "+1", flag: "\u{1F1E8}\u{1F1E6}"),
        CountryCode(id: "ES", name: "Spain", dialCode: "+34", flag: "\u{1F1EA}\u{1F1F8}"),
        CountryCode(id: "PT", name: "Portugal", dialCode: "+351", flag: "\u{1F1F5}\u{1F1F9}"),
        CountryCode(id: "NL", name: "Netherlands", dialCode: "+31", flag: "\u{1F1F3}\u{1F1F1}"),
        CountryCode(id: "BE", name: "Belgium", dialCode: "+32", flag: "\u{1F1E7}\u{1F1EA}"),
        CountryCode(id: "SE", name: "Sweden", dialCode: "+46", flag: "\u{1F1F8}\u{1F1EA}"),
        CountryCode(id: "NO", name: "Norway", dialCode: "+47", flag: "\u{1F1F3}\u{1F1F4}"),
        CountryCode(id: "DK", name: "Denmark", dialCode: "+45", flag: "\u{1F1E9}\u{1F1F0}"),
        CountryCode(id: "FI", name: "Finland", dialCode: "+358", flag: "\u{1F1EB}\u{1F1EE}"),
        CountryCode(id: "IE", name: "Ireland", dialCode: "+353", flag: "\u{1F1EE}\u{1F1EA}"),
        CountryCode(id: "PL", name: "Poland", dialCode: "+48", flag: "\u{1F1F5}\u{1F1F1}"),
        CountryCode(id: "CZ", name: "Czech Republic", dialCode: "+420", flag: "\u{1F1E8}\u{1F1FF}"),
        CountryCode(id: "GR", name: "Greece", dialCode: "+30", flag: "\u{1F1EC}\u{1F1F7}"),
        CountryCode(id: "TR", name: "Turkey", dialCode: "+90", flag: "\u{1F1F9}\u{1F1F7}"),
        CountryCode(id: "RU", name: "Russia", dialCode: "+7", flag: "\u{1F1F7}\u{1F1FA}"),
        CountryCode(id: "JP", name: "Japan", dialCode: "+81", flag: "\u{1F1EF}\u{1F1F5}"),
        CountryCode(id: "KR", name: "South Korea", dialCode: "+82", flag: "\u{1F1F0}\u{1F1F7}"),
        CountryCode(id: "CN", name: "China", dialCode: "+86", flag: "\u{1F1E8}\u{1F1F3}"),
        CountryCode(id: "SG", name: "Singapore", dialCode: "+65", flag: "\u{1F1F8}\u{1F1EC}"),
        CountryCode(id: "HK", name: "Hong Kong", dialCode: "+852", flag: "\u{1F1ED}\u{1F1F0}"),
        CountryCode(id: "NZ", name: "New Zealand", dialCode: "+64", flag: "\u{1F1F3}\u{1F1FF}"),
        CountryCode(id: "ZA", name: "South Africa", dialCode: "+27", flag: "\u{1F1FF}\u{1F1E6}"),
        CountryCode(id: "BR", name: "Brazil", dialCode: "+55", flag: "\u{1F1E7}\u{1F1F7}"),
        CountryCode(id: "MX", name: "Mexico", dialCode: "+52", flag: "\u{1F1F2}\u{1F1FD}"),
        CountryCode(id: "AR", name: "Argentina", dialCode: "+54", flag: "\u{1F1E6}\u{1F1F7}"),
        CountryCode(id: "CL", name: "Chile", dialCode: "+56", flag: "\u{1F1E8}\u{1F1F1}"),
        CountryCode(id: "AE", name: "United Arab Emirates", dialCode: "+971", flag: "\u{1F1E6}\u{1F1EA}"),
        CountryCode(id: "SA", name: "Saudi Arabia", dialCode: "+966", flag: "\u{1F1F8}\u{1F1E6}"),
        CountryCode(id: "IL", name: "Israel", dialCode: "+972", flag: "\u{1F1EE}\u{1F1F1}"),
        CountryCode(id: "TH", name: "Thailand", dialCode: "+66", flag: "\u{1F1F9}\u{1F1ED}"),
        CountryCode(id: "PH", name: "Philippines", dialCode: "+63", flag: "\u{1F1F5}\u{1F1ED}"),
        CountryCode(id: "MY", name: "Malaysia", dialCode: "+60", flag: "\u{1F1F2}\u{1F1FE}"),
        CountryCode(id: "ID", name: "Indonesia", dialCode: "+62", flag: "\u{1F1EE}\u{1F1E9}"),
    ]
}

// MARK: - Country Code Picker View

struct CountryCodePicker: View {
    @Binding var selectedCountry: CountryCode
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var filteredCountries: [CountryCode] {
        if searchText.isEmpty {
            return CountryCode.all
        }
        let query = searchText.lowercased()
        return CountryCode.all.filter { country in
            country.name.lowercased().contains(query)
                || country.dialCode.contains(query)
                || country.id.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                List {
                    ForEach(filteredCountries) { country in
                        Button {
                            selectedCountry = country
                            HapticManager.selectionChanged()
                            dismiss()
                        } label: {
                            countryRow(country)
                        }
                        .listRowBackground(
                            selectedCountry.id == country.id
                                ? AppColors.selectedBackground
                                : AppColors.background
                        )
                    }
                }
                .listStyle(.plain)
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search countries"
                )
            }
            .navigationTitle("Country Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.lightTap()
                        dismiss()
                    }
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    // MARK: - Country Row

    private func countryRow(_ country: CountryCode) -> some View {
        let isSelected = selectedCountry.id == country.id
        return HStack(spacing: Spacing.md) {
            Text(country.flag)
                .font(.system(size: IconSize.lg))

            Text(country.name)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(country.dialCode)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: IconSize.sm))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(country.name), \(country.dialCode)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
