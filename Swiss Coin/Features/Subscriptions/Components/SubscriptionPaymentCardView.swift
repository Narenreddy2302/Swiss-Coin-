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
    var onEdit: ((SubscriptionPayment) -> Void)? = nil
    var onDelete: ((SubscriptionPayment) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var isUserPayer: Bool {
        CurrentUser.isCurrentUser(payment.payer?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // First line: Avatar + "You paid" + amount
            HStack(alignment: .center, spacing: Spacing.sm) {
                ConversationAvatarView(
                    initials: isUserPayer ? CurrentUser.initials : (payment.payer?.initials ?? "?"),
                    colorHex: isUserPayer ? CurrentUser.defaultColorHex : (payment.payer?.colorHex ?? CurrentUser.defaultColorHex),
                    size: AvatarSize.xs
                )

                Text(isUserPayer ? "You paid" : "\(payment.payer?.firstName ?? "Someone") paid")
                    .font(AppTypography.headingSmall())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(CurrencyFormatter.format(payment.amount))
                    .font(AppTypography.financialDefault())
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)

            // Second line: "for SubscriptionName · N way split"
            Text("for \(subscription.name ?? "Subscription") · \(subscription.subscriberCount) way split")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .padding(.leading, Spacing.lg + AvatarSize.xs + Spacing.sm)
                .padding(.trailing, Spacing.lg)
                .padding(.top, Spacing.xxs)
                .padding(.bottom, Spacing.md)

            // Note section with divider
            if let note = payment.note, !note.isEmpty {
                Rectangle()
                    .fill(AppColors.divider)
                    .frame(height: 0.5)
                    .padding(.horizontal, Spacing.lg)

                Text("\"\(note)\"")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                    .italic()
                    .lineLimit(2)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.md)
            }
        }
        .background {
            let s = AppShadow.bubble(for: colorScheme)
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.card))
        .contextMenu {
            Button {
                UIPasteboard.general.string = CurrencyFormatter.format(payment.amount)
                HapticManager.copyAction()
            } label: {
                Label("Copy Amount", systemImage: "doc.on.doc")
            }

            if isUserPayer, let onEdit {
                Button {
                    HapticManager.lightTap()
                    onEdit(payment)
                } label: {
                    Label("Edit Payment", systemImage: "pencil")
                }
            }

            if isUserPayer, let onDelete {
                Divider()

                Button(role: .destructive) {
                    HapticManager.delete()
                    onDelete(payment)
                } label: {
                    Label("Delete Payment", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUserPayer ? "You" : payment.payer?.firstName ?? "Someone") paid \(CurrencyFormatter.format(payment.amount)) for \(subscription.name ?? "subscription")")
        .accessibilityHint("Double tap and hold for options")
    }
}
