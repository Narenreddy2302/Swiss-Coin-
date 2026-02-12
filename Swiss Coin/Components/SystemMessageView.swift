//
//  SystemMessageView.swift
//  Swiss Coin
//
//  Unified system message component for consistent styling of settlements,
//  reminders, and other system events across all conversation views.
//

import SwiftUI

/// Displays a system event message (settlement, reminder, etc.) as a full-width
/// message bubble across person, group, and subscription conversation views.
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
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(messageText)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)

            if let noteText, !noteText.isEmpty {
                Text(noteText)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                    .italic()
            }

            if let date {
                Text(date, style: .time)
                    .labelSmallStyle()
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(backgroundColor)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        )
    }
}
