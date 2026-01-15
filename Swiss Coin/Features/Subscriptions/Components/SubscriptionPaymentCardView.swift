//
//  SubscriptionPaymentCardView.swift
//  Swiss Coin
//
//  Card view for displaying a subscription payment in the conversation.
//

import SwiftUI

struct SubscriptionPaymentCardView: View {
    let payment: SubscriptionPayment
    let subscription: Subscription

    private var isUserPayer: Bool {
        CurrentUser.isCurrentUser(payment.payer?.id)
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            // Payment Icon
            Circle()
                .fill(AppColors.positive.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.positive)
                )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(isUserPayer ? "You paid" : "\(payment.payer?.firstName ?? "Someone") paid")
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)

                Text(subscription.name ?? "Subscription")
                    .font(AppTypography.footnote())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(CurrencyFormatter.format(payment.amount))
                    .font(AppTypography.amount())
                    .foregroundColor(AppColors.textPrimary)

                Text("\(subscription.subscriberCount) way split")
                    .font(AppTypography.footnote())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
        .padding(.horizontal, Spacing.lg)
    }
}
