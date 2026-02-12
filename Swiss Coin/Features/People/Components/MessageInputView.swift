//
//  MessageInputView.swift
//  Swiss Coin
//
//  iMessage-style message input with spring physics and polished interactions.
//

import SwiftUI

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void

    @FocusState private var isTextFieldFocused: Bool
    @State private var sendButtonScale: CGFloat = 1.0

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Text Input Field
            TextField("Message", text: $messageText, axis: .vertical)
                .focused($isTextFieldFocused)
                .limitTextLength(to: ValidationLimits.maxMessageLength, text: $messageText)
                .font(AppTypography.bodyLarge())
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .fill(AppColors.messageInputFieldBackground)
                )
                .lineLimit(1...5)
                .accessibilityLabel("Message input")
                .accessibilityHint("Type a message to send")

            // Send Button
            Button {
                if canSend {
                    HapticManager.messageSent()
                    isTextFieldFocused = false
                    // Spring bounce on send
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        sendButtonScale = 0.7
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            sendButtonScale = 1.0
                        }
                    }
                    onSend()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: IconSize.xl))
                    .foregroundColor(canSend ? AppColors.accent : AppColors.accent.opacity(0.3))
                    .scaleEffect(sendButtonScale)
            }
            .disabled(!canSend)
            .buttonStyle(AppButtonStyle(haptic: .none))
            .animation(AppAnimation.spring, value: canSend)
            .accessibilityLabel("Send message")
            .accessibilityHint(canSend ? "Sends the typed message" : "Type a message first")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.messageInputBackground)
        .onAppear {
            HapticManager.prepare()
        }
    }
}
