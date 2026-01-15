//
//  SubscriptionInfoCard.swift
//  Swiss Coin
//
//  Info card displayed at the top of shared subscription conversation.
//

import SwiftUI

struct SubscriptionInfoCard: View {
    let subscription: Subscription

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                // Icon
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(Color(hex: subscription.colorHex ?? "#007AFF").opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: subscription.iconName ?? "person.2.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: subscription.colorHex ?? "#007AFF"))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.name ?? "Subscription")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)

                    Text("\(CurrencyFormatter.format(subscription.amount))/\(subscription.cycleAbbreviation)")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Next billing badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Next billing")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)

                    Text(subscription.nextBillingDate?.formatted(.dateTime.month(.abbreviated).day()) ?? "")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(subscription.billingStatus.color)
                }
            }

            Divider()
                .background(AppColors.textSecondary.opacity(0.3))

            // Your share info
            HStack {
                Text("Your share")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text(CurrencyFormatter.format(subscription.myShare))
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)

                Text("/\(subscription.cycleAbbreviation)")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }
}
