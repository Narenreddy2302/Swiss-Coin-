//
//  SystemMessageView.swift
//  Swiss Coin
//
//  Unified system message component for consistent styling of settlements,
//  reminders, and other system events across all conversation views.
//

import SwiftUI

/// Displays a system event message (settlement, reminder, etc.) with consistent
/// capsule styling across person, group, and subscription conversation views.
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
        VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.xs))
                    .foregroundColor(iconColor)

                Text(messageText)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )

            if let noteText, !noteText.isEmpty {
                Text(noteText)
                    .captionStyle()
                    .foregroundColor(AppColors.textTertiary)
                    .italic()
            }

            if let date {
                Text(date, style: .date)
                    .captionStyle()
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
    }
}
