//
//  SubscriptionReminderMessageView.swift
//  Swiss Coin
//
//  Message view for displaying a reminder in the subscription conversation.
//

import SwiftUI

struct SubscriptionReminderMessageView: View {
    let reminder: SubscriptionReminder

    private var messageText: String {
        let formatted = CurrencyFormatter.format(reminder.amount)
        let personName = reminder.toPerson?.firstName ?? "Someone"
        return "Reminder sent to \(personName) for \(formatted)"
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "bell.fill")
                    .font(.system(size: IconSize.xs))
                    .foregroundColor(AppColors.warning)

                Text(messageText)
                    .font(AppTypography.caption())
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(AppColors.warningMuted)
            )

            if let message = reminder.message, !message.isEmpty {
                Text("\"\(message)\"")
                    .font(AppTypography.labelSmall())
                    .foregroundColor(AppColors.textSecondary)
                    .italic()
            }

            Text(reminder.createdDate ?? Date(), style: .date)
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
    }
}
