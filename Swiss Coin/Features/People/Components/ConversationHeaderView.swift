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
                HStack(spacing: Spacing.md) {
                    // Gray avatar with gray initials (matching iMessage style)
                    Circle()
                        .fill(Color(UIColor.systemGray3))
                        .frame(width: AvatarSize.md, height: AvatarSize.md)
                        .overlay(
                            Text(person.initials)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(UIColor.systemGray))
                        )

                    Text(person.displayName)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(AppButtonStyle(haptic: .none))

            Spacer()

            // Balance (right side) - "owes you" above amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(balanceLabel)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(UIColor.systemGray))

                Text(balanceAmount)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(balanceColor)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.background)
    }
}
