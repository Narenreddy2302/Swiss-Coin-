//
//  MessageBubbleView.swift
//  Swiss Coin
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    @Environment(\.colorScheme) private var colorScheme

    private var isFromUser: Bool {
        message.isFromUser
    }

    private var timeText: String {
        guard let timestamp = message.timestamp else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: timestamp)
    }

    var body: some View {
        HStack {
            if isFromUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isFromUser ? .trailing : .leading, spacing: Spacing.xxs) {
                Text(message.content ?? "")
                    .font(AppTypography.body())
                    .foregroundColor(isFromUser ? .white : AppColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .fill(isFromUser ? AppColors.accent : AppColors.cardBackground)
                    )

                Text(timeText)
                    .font(AppTypography.caption2())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 4)
            }

            if !isFromUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}
