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
            Text(messageText)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)

            if let noteText, !noteText.isEmpty {
                Text(noteText)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        )
    }
}
