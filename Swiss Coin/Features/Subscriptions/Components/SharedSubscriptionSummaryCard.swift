//
//  SharedSubscriptionSummaryCard.swift
//  Swiss Coin
//
//  Summary card for shared subscriptions showing your share.
//

import SwiftUI

struct SharedSubscriptionSummaryCard: View {
    let totalMonthly: Double
    let myShare: Double
    let activeCount: Int

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Your Monthly Share")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    Text(CurrencyFormatter.format(myShare))
                        .font(AppTypography.amountLarge())
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("Total: \(CurrencyFormatter.format(totalMonthly))")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    Text("\(activeCount) shared")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Savings indicator
            if totalMonthly > myShare {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.positive)

                    Text("Saving \(CurrencyFormatter.format(totalMonthly - myShare))/mo by sharing")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.positive)
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
