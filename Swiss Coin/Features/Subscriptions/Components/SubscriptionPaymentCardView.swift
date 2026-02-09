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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: Spacing.md) {
                // Payer Avatar
                ConversationAvatarView(
                    initials: isUserPayer ? CurrentUser.initials : (payment.payer?.initials ?? "?"),
                    colorHex: isUserPayer ? CurrentUser.defaultColorHex : (payment.payer?.colorHex ?? CurrentUser.defaultColorHex)
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

            // Display note if present
            if let note = payment.note, !note.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)

                    Text(note)
                        .font(AppTypography.footnote())
                        .foregroundColor(AppColors.textSecondary)
                        .italic()
                        .lineLimit(2)

                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
        .padding(.horizontal, Spacing.lg)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.md))
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
        .accessibilityHint("Double tap and hold for options")
    }
}
