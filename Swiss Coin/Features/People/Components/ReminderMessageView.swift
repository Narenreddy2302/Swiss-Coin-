//
//  ReminderMessageView.swift
//  Swiss Coin
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
        VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "bell.fill")
                    .font(.system(size: IconSize.xs))
                    .foregroundColor(AppColors.warning)

                Text(messageText)
                    .font(AppTypography.caption())
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
    }
}
