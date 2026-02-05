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
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)

                ForEach(memberBalances, id: \.member.id) { item in
                    HStack {
                        // Member Avatar
                        Circle()
                            .fill(Color(hex: item.member.colorHex ?? "#808080").opacity(0.3))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(item.member.initials)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(hex: item.member.colorHex ?? "#808080"))
                            )

                        Text(item.member.firstName)
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        if abs(item.balance) > 0.01 {
                            Text(item.balance > 0 ? "owes you \(CurrencyFormatter.formatAbsolute(item.balance))" : "you owe \(CurrencyFormatter.formatAbsolute(abs(item.balance)))")
                                .font(AppTypography.subheadline())
                                .foregroundColor(item.balance > 0 ? AppColors.positive : AppColors.negative)
                        } else {
                            Text("settled")
                                .font(AppTypography.subheadline())
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
