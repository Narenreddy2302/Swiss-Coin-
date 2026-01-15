//
//  MessageInputView.swift
//  Swiss Coin
//

import SwiftUI

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Text Input Field
            TextField("iMessage", text: $messageText, axis: .vertical)
                .font(AppTypography.body())
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .fill(Color(UIColor.systemGray6))
                )
                .lineLimit(1...5)

            // Send Button
            Button {
                if canSend {
                    HapticManager.sendMessage()
                    onSend()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: IconSize.xl))
                    .foregroundColor(canSend ? AppColors.accent : AppColors.accent.opacity(0.3))
            }
            .disabled(!canSend)
            .buttonStyle(AppButtonStyle(haptic: .none)) // Haptic handled in action
            .animation(AppAnimation.quick, value: canSend)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.background)
        .onAppear {
            HapticManager.prepare()
        }
    }
}
