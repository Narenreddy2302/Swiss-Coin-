//
//  SystemMessageView.swift
//  Swiss Coin
//
//  Centered pill-style notification for settlements, reminders, and other
//  system events across all conversation views. Compact and professional,
//  matching the design language of date header capsules.
//

import SwiftUI

/// Displays a system event as a centered rounded pill with a muted background.
/// Green-tinted for settlements, amber-tinted for reminders.
struct SystemMessageView: View {
    let icon: String
    let iconColor: Color
    let messageText: String
    let noteText: String?
    let date: Date?
    let backgroundColor: Color

    init(
        icon: String,
        iconColor: Color,
        messageText: String,
        noteText: String? = nil,
        date: Date? = nil,
        backgroundColor: Color
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.messageText = messageText
        self.noteText = noteText
        self.date = date
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        HStack {
            Spacer()

            VStack(spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(iconColor)

                    Text(messageText)
                        .font(AppTypography.bodySmall())
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                }

                if let noteText, !noteText.isEmpty {
                    Text(noteText)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                        .italic()
                }

                if let date {
                    Text(date, style: .time)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(backgroundColor)
            )

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }
}
