//
//  FeedPaymentContent.swift
//  Swiss Coin
//
//  Subscription payment content for feed rows.
//

import SwiftUI

struct FeedPaymentContent: View {
    let payment: SubscriptionPayment
    let subscription: Subscription

    private var isUserPayer: Bool {
        CurrentUser.isCurrentUser(payment.payer?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            // Line 1: Subscription name + Amount
            HStack {
                Text(subscription.name ?? "Subscription")
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(CurrencyFormatter.format(payment.amount))
                    .font(AppTypography.financialSmall())
                    .foregroundColor(AppColors.textPrimary)
            }

            // Line 2: Split info
            Text("\(subscription.subscriberCount) way split")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)

            // Note if present
            if let note = payment.note, !note.isEmpty {
                Text(note)
                    .captionStyle()
                    .foregroundColor(AppColors.textTertiary)
                    .italic()
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = CurrencyFormatter.format(payment.amount)
                HapticManager.copyAction()
            } label: {
                Label("Copy Amount", systemImage: "doc.on.doc")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUserPayer ? "You" : payment.payer?.firstName ?? "Someone") paid \(CurrencyFormatter.format(payment.amount)) for \(subscription.name ?? "subscription")")
    }
}
