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
                .foregroundColor(isFromUser ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    ChatBubbleShape(isFromUser: isFromUser)
                        .fill(isFromUser ? Color.green : Color(UIColor.systemGray5))
                )

            if !isFromUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Chat Bubble Shape

struct ChatBubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18

        var path = Path()

        if isFromUser {
            // Right-aligned bubble
            path.addRoundedRect(
                in: rect,
                cornerSize: CGSize(width: radius, height: radius)
            )
        } else {
            // Left-aligned bubble
            path.addRoundedRect(
                in: rect,
                cornerSize: CGSize(width: radius, height: radius)
            )
        }

        return path
    }
}
