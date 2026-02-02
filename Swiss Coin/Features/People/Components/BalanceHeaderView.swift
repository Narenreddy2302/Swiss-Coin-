//
//  BalanceHeaderView.swift
//  Swiss Coin
//

import SwiftUI

struct BalanceHeaderView: View {
    let person: Person
    let balance: Double
    let onAvatarTap: () -> Void

    private var balanceText: String {
        let formatted = CurrencyFormatter.format(abs(balance))

        if balance > 0.01 {
            return "\(person.firstName) owes you \(formatted)"
        } else if balance < -0.01 {
            return "You owe \(person.firstName) \(formatted)"
        } else {
            return "All settled up!"
        }
    }

    private var balanceColor: Color {
        if balance > 0.01 {
            return AppColors.positive
        } else if balance < -0.01 {
            return AppColors.negative
        } else {
            return AppColors.neutral
        }
    }

    private var balanceBackgroundColor: Color {
        if balance > 0.01 {
            return AppColors.positive.opacity(0.1)
        } else if balance < -0.01 {
            return AppColors.negative.opacity(0.1)
        } else {
            return AppColors.backgroundTertiary
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Avatar and Name
            Button(action: onAvatarTap) {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: person.colorHex ?? AppColors.defaultAvatarColorHex))
                        .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                        .overlay(
                            Text(person.initials)
                                .font(AppTypography.title1())
                                .foregroundColor(.white)
                        )
                        .shadow(color: AppColors.shadow, radius: 8, x: 0, y: 4)

                    Text(person.name ?? "Unknown")
                        .font(AppTypography.title3())
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Balance Card
            HStack {
                Spacer()
                Text(balanceText)
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(balanceColor)
                Spacer()
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(balanceBackgroundColor)
            )
            .padding(.horizontal, 40)
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(AppColors.backgroundSecondary)
    }
}
