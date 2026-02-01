//
//  MessageBubbleView.swift
//  Swiss Coin
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    private var isFromUser: Bool {
        message.isFromUser
    }

    var body: some View {
        HStack {
            if isFromUser {
                Spacer(minLength: 60)
            }

            Text(message.content ?? "")
                .font(AppTypography.body())
                .foregroundColor(isFromUser ? .white : AppColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(isFromUser ? AppColors.accent : AppColors.otherBubble)
                )

            if !isFromUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}
