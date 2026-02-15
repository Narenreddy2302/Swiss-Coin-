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
                    .fill(Color(hex: subscription.colorHex ?? AppColors.defaultAvatarColorHex).opacity(0.2))
                    .frame(width: AvatarSize.md, height: AvatarSize.md)
                    .overlay(
                        Image(systemName: subscription.iconName ?? "person.2.circle.fill")
                            .font(.system(size: IconSize.md))
                            .foregroundColor(Color(hex: subscription.colorHex ?? AppColors.defaultAvatarColorHex))
                    )

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(subscription.name ?? "Subscription")
                        .font(AppTypography.headingMedium())
                        .foregroundColor(AppColors.textPrimary)

                    (Text(CurrencyFormatter.format(subscription.amount)).fontWeight(.bold) + Text("/\(subscription.cycleAbbreviation)"))
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Next billing badge
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("Next billing")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)

                    Text(subscription.nextBillingDate?.formatted(.dateTime.month(.abbreviated).day()) ?? "")
                        .font(AppTypography.labelLarge())
                        .foregroundColor(subscription.billingStatus.color)
                }
            }

            Divider()
                .background(AppColors.textSecondary.opacity(0.3))

            // Your share info
            HStack {
                Text("Your share")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text(CurrencyFormatter.format(subscription.myShare))
                    .font(AppTypography.financialDefault())
                    .foregroundColor(AppColors.textPrimary)

                Text("/\(subscription.cycleAbbreviation)")
                    .font(AppTypography.bodyDefault())
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
