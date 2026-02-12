//
//  SystemMessageView.swift
//  Swiss Coin
//
//  Full-width notification strip for settlements, reminders, and other
//  system events across all conversation views. Spans edge to edge with
//  a colored background — no avatar, no rounded card.
//

import SwiftUI

/// Displays a system event as a full-width colored notification strip.
/// Red for reminders, green for settlements.
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
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.stripText.opacity(0.9))

                Text(messageText)
                    .font(AppTypography.bodyDefault())
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.stripText)
            }

            if let noteText, !noteText.isEmpty {
                Text(noteText)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.stripText.opacity(0.85))
                    .italic()
            }

            if let date {
                Text(date, style: .time)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.stripText.opacity(0.7))
            }
        }
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
    }
}
