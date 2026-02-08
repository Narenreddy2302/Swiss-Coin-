//
//  GroupReminderMessageView.swift
//  Swiss Coin
//
//  System message for reminders in group conversations.
//

import SwiftUI

struct GroupReminderMessageView: View {
    let reminder: Reminder

    private var messageText: String {
        let formatted = CurrencyFormatter.format(reminder.amount)
        let personName = reminder.toPerson?.firstName ?? "Someone"
        return "Reminder sent to \(personName) for \(formatted)"
    }

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "bell.fill")
                    .font(.system(size: IconSize.xs))
                    .foregroundColor(AppColors.warning)

                Text(messageText)
                    .font(AppTypography.caption())
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(AppColors.warning.opacity(0.15))
            )

            if let message = reminder.message, !message.isEmpty {
                Text("\"\(message)\"")
                    .font(AppTypography.caption2())
                    .foregroundColor(AppColors.textSecondary)
                    .italic()
            }

            Text(reminder.createdDate ?? Date(), style: .date)
                .font(AppTypography.caption2())
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
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
