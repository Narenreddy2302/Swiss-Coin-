//
//  FeedSystemContent.swift
//  Swiss Coin
//
//  System event content for feed rows (settlements, reminders, etc.).
//

import SwiftUI

struct FeedSystemContent: View {
    let icon: String
    let iconColor: Color
    let messageText: String
    var noteText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.xs))
                    .foregroundColor(iconColor)

                Text(messageText)
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textPrimary)
            }

            if let noteText, !noteText.isEmpty {
                Text(noteText)
                    .captionStyle()
                    .foregroundColor(AppColors.textTertiary)
                    .italic()
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .stroke(AppColors.border.opacity(0.2), lineWidth: 0.5)
        )
    }
}
