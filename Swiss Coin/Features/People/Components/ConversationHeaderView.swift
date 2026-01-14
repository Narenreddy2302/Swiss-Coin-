//
//  ConversationHeaderView.swift
//  Swiss Coin
//

import SwiftUI

struct ConversationHeaderView: View {
    let person: Person
    let balance: Double
    let onAvatarTap: () -> Void

    private var balanceLabel: String {
        if balance > 0.01 {
            return "owes you"
        } else if balance < -0.01 {
            return "you owe"
        } else {
            return "settled"
        }
    }

    private var balanceAmount: String {
        CurrencyFormatter.formatAbsolute(balance)
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

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar and Name (left side)
            Button {
                HapticManager.navigate()
                onAvatarTap()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                        .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                        .overlay(
                            Text(person.initials)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )

                    Text(person.displayName)
                        .font(AppTypography.bodyBold())
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .buttonStyle(AppButtonStyle(haptic: .none))

            Spacer()

            // Balance (right side)
            VStack(alignment: .trailing, spacing: 2) {
                Text(balanceLabel)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                Text(balanceAmount)
                    .font(AppTypography.amount())
                    .foregroundColor(balanceColor)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.background)
    }
}
