//
//  ReminderMessageView.swift
//  Swiss Coin
//
//  Timeline-style system message for reminders in person conversations.
//

import SwiftUI

struct ReminderMessageView: View {
    let reminder: Reminder
    let person: Person

    private var messageText: String {
        let formatted = CurrencyFormatter.format(reminder.amount)
        return "Reminder sent for \(formatted)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "bell.fill")
                    .font(.system(size: IconSize.xs))
                    .foregroundColor(AppColors.warning)

                Text(messageText)
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.warningMuted)
            )

            if let message = reminder.message, !message.isEmpty {
                Text("\"\(message)\"")
                    .captionStyle()
                    .foregroundColor(AppColors.textSecondary)
                    .italic()
                    .padding(.leading, Spacing.xs)
            }

            Text(reminder.createdDate ?? Date(), style: .date)
                .captionStyle()
                .foregroundColor(AppColors.textSecondary)
                .padding(.leading, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button {
                UIPasteboard.general.string = messageText
                HapticManager.copyAction()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                UIPasteboard.general.string = CurrencyFormatter.format(reminder.amount)
                HapticManager.copyAction()
            } label: {
                Label("Copy Amount", systemImage: "dollarsign.circle")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reminder: \(messageText)")
    }
}
