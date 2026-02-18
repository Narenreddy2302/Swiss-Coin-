//
//  QuickSettleSheetView.swift
//  Swiss Coin
//
//  Sheet listing all people the user owes money to,
//  allowing quick navigation to SettlementView.
//

import SwiftUI

struct QuickSettleSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let people: [Person]

    @State private var selectedPerson: Person?
    @State private var selectedBalance: CurrencyBalance = CurrencyBalance()
    @State private var peopleYouOwe: [(person: Person, balance: CurrencyBalance)] = []

    var body: some View {
        NavigationStack {
            Group {
                if peopleYouOwe.isEmpty {
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: IconSize.xxl))
                            .foregroundColor(AppColors.positive)

                        Text("All settled up!")
                            .font(AppTypography.headingLarge())
                            .foregroundColor(AppColors.textPrimary)

                        Text("You don't owe anyone right now.")
                            .font(AppTypography.bodyDefault())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundSecondary)
                } else {
                    List {
                        Section {
                            ForEach(peopleYouOwe, id: \.person.id) { item in
                                Button {
                                    HapticManager.tap()
                                    selectedPerson = item.person
                                    selectedBalance = item.balance
                                } label: {
                                    HStack(spacing: Spacing.md) {
                                        // Avatar
                                        Circle()
                                            .fill(Color(hex: item.person.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                                            .frame(width: AvatarSize.md, height: AvatarSize.md)
                                            .overlay(
                                                Text(item.person.initials)
                                                    .font(AppTypography.labelLarge())
                                                    .foregroundColor(Color(hex: item.person.colorHex ?? CurrentUser.defaultColorHex))
                                            )

                                        // Name
                                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                                            Text(item.person.name ?? "Unknown")
                                                .font(AppTypography.headingMedium())
                                                .foregroundColor(AppColors.textPrimary)
                                                .lineLimit(1)

                                            Text("You owe")
                                                .font(AppTypography.caption())
                                                .foregroundColor(AppColors.textSecondary)
                                        }

                                        Spacer()

                                        // Amount
                                        MultiCurrencyBalanceView(balance: item.balance, style: .compact)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: IconSize.xs, weight: .semibold))
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                    .padding(.vertical, Spacing.xs)
                                }
                            }
                        } header: {
                            Text("People You Owe")
                                .font(AppTypography.labelLarge())
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(AppColors.backgroundSecondary)
                }
            }
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.lightTap()
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedPerson) { person in
                SettlementView(person: person, currentBalance: selectedBalance.primaryAmount, currentCurrencyBalance: selectedBalance)
            }
            .task {
                peopleYouOwe = people
                    .filter { !CurrentUser.isCurrentUser($0.id) }
                    .compactMap { person in
                        let balance = person.calculateBalance()
                        guard balance.hasNegative else { return nil }
                        return (person: person, balance: balance)
                    }
                    .sorted { abs($0.balance.primaryAmount) > abs($1.balance.primaryAmount) }
            }
        }
    }
}

// Person conforms to Identifiable via CoreData
