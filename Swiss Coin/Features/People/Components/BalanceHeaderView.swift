//
//  BalanceHeaderView.swift
//  Swiss Coin
//

import SwiftUI

struct BalanceHeaderView: View {
    let person: Person
    let balance: CurrencyBalance
    let onAvatarTap: () -> Void

    private var balanceBackgroundColor: Color {
        let sorted = balance.sortedCurrencies
        if sorted.isEmpty { return AppColors.backgroundTertiary }
        let primary = sorted[0].amount
        if primary > 0.01 { return AppColors.positive.opacity(0.1) }
        else if primary < -0.01 { return AppColors.negative.opacity(0.1) }
        else { return AppColors.backgroundTertiary }
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Avatar and Name
            Button(action: onAvatarTap) {
                VStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color(hex: person.colorHex ?? AppColors.defaultAvatarColorHex))
                        .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                        .overlay(
                            Text(person.initials)
                                .font(AppTypography.displayLarge())
                                .foregroundColor(AppColors.onAccent)
                        )
                        .shadow(color: AppColors.shadow, radius: 8, x: 0, y: 4)

                    Text(person.name ?? "Unknown")
                        .font(AppTypography.headingLarge())
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Balance Card
            HStack {
                Spacer()
                MultiCurrencyBalanceView(
                    balance: balance,
                    style: .expanded,
                    personName: person.firstName
                )
                Spacer()
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(balanceBackgroundColor)
            )
            .padding(.horizontal, Spacing.xxxl + Spacing.sm)
        }
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.lg)
        .background(AppColors.backgroundSecondary)
    }
}
