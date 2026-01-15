//
//  PersonalSubscriptionSummaryCard.swift
//  Swiss Coin
//
//  Summary card for personal subscriptions showing monthly total.
//

import SwiftUI

struct PersonalSubscriptionSummaryCard: View {
    let monthlyTotal: Double
    let activeCount: Int
    let nextDueDate: Date?

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Monthly Total")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    Text(CurrencyFormatter.format(monthlyTotal))
                        .font(AppTypography.amountLarge())
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("\(activeCount) active")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    if let nextDue = nextDueDate {
                        Text("Next: \(nextDue.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(AppTypography.subheadlineMedium())
                            .foregroundColor(AppColors.accent)
                    }
                }
            }

            // Progress indicator (optional visual enhancement)
            if monthlyTotal > 0 {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accent)

                    Text("Yearly: \(CurrencyFormatter.format(monthlyTotal * 12))")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
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
