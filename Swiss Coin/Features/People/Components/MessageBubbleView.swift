//
//  MessageBubbleView.swift
//  Swiss Coin
//
//  iMessage-style chat bubble with context menu, inline editing, and copy support.
//

import SwiftUI

struct MessageBubbleView: View {
    @ObservedObject var message: ChatMessage
    var onDelete: ((ChatMessage) -> Void)? = nil

    @Environment(\.managedObjectContext) private var viewContext
    @State private var isEditing = false
    @State private var editText = ""

    // MARK: - Computed Properties

    private var isFromUser: Bool {
        message.isFromUser
    }

    /// Edit window: 15 minutes from message creation
    private var canEdit: Bool {
        guard message.isFromUser else { return false }
        guard let timestamp = message.timestamp else { return false }
        return Date().timeIntervalSince(timestamp) < 15 * 60
    }

    private var timeText: String {
        guard let timestamp = message.timestamp else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: timestamp)
    }

    private var canSaveEdit: Bool {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != message.content
    }

    // MARK: - Body

    var body: some View {
        HStack {
            if isFromUser { Spacer(minLength: 60) }

            VStack(alignment: isFromUser ? .trailing : .leading, spacing: Spacing.xxs) {
                if isEditing {
                    editingView
                } else {
                    bubbleView
                }

                // Timestamp + Edited badge
                HStack(spacing: Spacing.xs) {
                    if message.isEdited && !isEditing {
                        Text("Edited")
                            .font(AppTypography.caption2())
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Text(timeText)
                        .font(AppTypography.caption2())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 4)
            }

            if !isFromUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, Spacing.lg)
        .contextMenu {
            // Copy — available for all messages
            Button {
                UIPasteboard.general.string = message.content ?? ""
                HapticManager.tap()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            // Edit — own messages within 15-minute window
            if canEdit {
                Button {
                    HapticManager.tap()
                    editText = message.content ?? ""
                    withAnimation(AppAnimation.standard) {
                        isEditing = true
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            // Delete — own messages only
            if message.isFromUser, onDelete != nil {
                Divider()
                Button(role: .destructive) {
                    HapticManager.delete()
                    onDelete?(message)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(message.isFromUser ? "Double tap and hold for options" : "")
    }

    // MARK: - Bubble View

    @ViewBuilder
    private var bubbleView: some View {
        Text(message.content ?? "")
            .font(AppTypography.body())
            .foregroundColor(isFromUser ? .white : AppColors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
    }

    private var bubbleBackground: some View {
        UnevenRoundedRectangle(
            topLeading: CornerRadius.lg,
            bottomLeading: isFromUser ? CornerRadius.lg : Spacing.xs,
            bottomTrailing: isFromUser ? Spacing.xs : CornerRadius.lg,
            topTrailing: CornerRadius.lg
        )
        .fill(isFromUser ? AppColors.accent : AppColors.cardBackground)
    }

    // MARK: - Edit Mode

    @ViewBuilder
    private var editingView: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            TextField("Edit message...", text: $editText, axis: .vertical)
                .limitTextLength(to: ValidationLimits.maxMessageLength, text: $editText)
                .font(AppTypography.body())
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(AppColors.backgroundTertiary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(AppColors.accent, lineWidth: 2)
                )
                .lineLimit(1...8)

            HStack(spacing: Spacing.sm) {
                Button {
                    HapticManager.cancel()
                    withAnimation(AppAnimation.standard) {
                        isEditing = false
                    }
                } label: {
                    Text("Cancel")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(AppColors.backgroundTertiary)
                        )
                }

                Button {
                    saveEdit()
                } label: {
                    Text("Save")
                        .font(AppTypography.caption())
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(canSaveEdit ? AppColors.accent : AppColors.disabled)
                        )
                }
                .disabled(!canSaveEdit)
            }
        }
    }

    // MARK: - Actions

    private func saveEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != message.content else { return }

        message.content = trimmed
        message.isEdited = true

        do {
            try viewContext.save()
            HapticManager.success()
            withAnimation(AppAnimation.standard) {
                isEditing = false
            }
        } catch {
            viewContext.rollback()
            HapticManager.error()
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let sender = isFromUser ? "You" : "Them"
        let content = message.content ?? ""
        let edited = message.isEdited ? ", edited" : ""
        return "\(sender): \(content)\(edited), \(timeText)"
    }
}
