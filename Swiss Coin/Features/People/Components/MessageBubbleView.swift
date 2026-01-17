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
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(isFromUser ? .white : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isFromUser ? AppColors.accent : Color(UIColor.systemGray4))
                )

            if !isFromUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
    }
}
