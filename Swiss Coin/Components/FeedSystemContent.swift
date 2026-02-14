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
    var backgroundColor: Color = AppColors.cardBackground

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.xs, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(messageText)
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textPrimary)
            }

            if let noteText, !noteText.isEmpty {
                Text(noteText)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(backgroundColor)
        )
    }
}
