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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Monthly Total")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)

                    Text(CurrencyFormatter.format(monthlyTotal))
                        .font(AppTypography.financialLarge())
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("\(activeCount) active")
                        .font(AppTypography.labelLarge())
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(AppColors.accent.opacity(0.12))
                        )

                    if let nextDue = nextDueDate {
                        Text("Next: \(nextDue.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(AppTypography.labelDefault())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            if monthlyTotal > 0 {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: IconSize.xs))
                        .foregroundColor(AppColors.textTertiary)

                    (Text("Yearly: ") + Text(CurrencyFormatter.format(monthlyTotal * 12)).fontWeight(.bold))
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
        )
    }
}
