//
//  MemberBalancesCard.swift
//  Swiss Coin
//
//  Card showing member balances for a shared subscription.
//

import SwiftUI

struct MemberBalancesCard: View {
    let subscription: Subscription

    private var memberBalances: [(member: Person, balance: Double, paid: Double)] {
        subscription.getMemberBalances()
    }

    var body: some View {
        if memberBalances.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Member Balances")
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textSecondary)

                ForEach(memberBalances, id: \.member.id) { item in
                    HStack {
                        // Member Avatar
                        Circle()
                            .fill(Color(hex: item.member.colorHex ?? AppColors.defaultAvatarColorHex).opacity(0.3))
                            .frame(width: IconSize.category, height: IconSize.category)
                            .overlay(
                                Text(item.member.initials)
                                    .font(AppTypography.labelSmall())
                                    .foregroundColor(Color(hex: item.member.colorHex ?? AppColors.defaultAvatarColorHex))
                            )

                        Text(item.member.firstName)
                            .font(AppTypography.bodyDefault())
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        if abs(item.balance) > 0.01 {
                            (item.balance > 0
                                ? Text("owes you ") + Text(CurrencyFormatter.formatAbsolute(item.balance)).fontWeight(.bold)
                                : Text("you owe ") + Text(CurrencyFormatter.formatAbsolute(abs(item.balance))).fontWeight(.bold))
                                .font(AppTypography.bodySmall())
                                .foregroundColor(item.balance > 0 ? AppColors.positive : AppColors.negative)
                        } else {
                            Text("settled")
                                .font(AppTypography.bodySmall())
                                .foregroundColor(AppColors.neutral)
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackground)
            )
        }
    }
}
