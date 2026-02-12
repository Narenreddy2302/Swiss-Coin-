//
//  MessageBubbleView.swift
//  Swiss Coin
//
//  Chat bubble with context menu, inline editing, and copy support.
//  Supports both timeline (left-aligned) and classic (iMessage-style) layouts.
//

import SwiftUI
import CoreData

struct MessageBubbleView: View {
    @ObservedObject var message: ChatMessage
    var onDelete: ((ChatMessage) -> Void)? = nil
    var onFocusInput: (() -> Void)? = nil
    var useTimelineLayout: Bool = false
    var senderInitials: String? = nil
    var senderColor: String? = nil

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
        if useTimelineLayout {
            timelineBody
        } else {
            classicBody
        }
    }

    // MARK: - Timeline Layout (left-aligned, for PersonConversationView)

    @ViewBuilder
    private var timelineBody: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if isEditing {
                editingView
            } else {
                timelineBubbleView
            }

            // Timestamp + Edited badge
            HStack(spacing: Spacing.xs) {
                if message.isEdited && !isEditing {
                    Text("Edited")
                        .labelSmallStyle()
                        .foregroundColor(AppColors.textTertiary)
                }
                Text(timeText)
                    .labelSmallStyle()
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.leading, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(message.isFromUser ? "Double tap and hold for options" : "")
    }

    @ViewBuilder
    private var timelineBubbleView: some View {
        let bubbleColor = isFromUser ? AppColors.userBubble : AppColors.otherBubble
        let textColor = isFromUser ? AppColors.userBubbleText : AppColors.otherBubbleText

        Text(message.content ?? "")
            .font(AppTypography.bodyLarge())
            .foregroundColor(textColor)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(bubbleColor)
            )
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.card))
            .contextMenu { contextMenuItems }
    }

    // MARK: - Classic Layout (iMessage-style, for Group/Subscription views)

    @ViewBuilder
    private var classicBody: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            if isFromUser { Spacer(minLength: 60) }

            // Avatar for non-user messages
            if !isFromUser, let initials = senderInitials {
                ConversationAvatarView(
                    initials: initials,
                    colorHex: senderColor ?? CurrentUser.defaultColorHex,
                    size: AvatarSize.xs
                )
            }

            VStack(alignment: isFromUser ? .trailing : .leading, spacing: Spacing.xxs) {
                if isEditing {
                    editingView
                } else {
                    classicBubbleView
                }

                // Timestamp + Edited badge
                HStack(spacing: Spacing.xs) {
                    if message.isEdited && !isEditing {
                        Text("Edited")
                            .labelSmallStyle()
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Text(timeText)
                        .labelSmallStyle()
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, Spacing.xs)
            }

            if !isFromUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(message.isFromUser ? "Double tap and hold for options" : "")
    }

    @ViewBuilder
    private var classicBubbleView: some View {
        Text(message.content ?? "")
            .font(AppTypography.bodyLarge())
            .foregroundColor(isFromUser ? AppColors.userBubbleText : AppColors.otherBubbleText)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(classicBubbleBackground)
            .contentShape(.contextMenuPreview, UnevenRoundedRectangle(
                topLeadingRadius: CornerRadius.lg,
                bottomLeadingRadius: isFromUser ? CornerRadius.lg : Spacing.xs,
                bottomTrailingRadius: isFromUser ? Spacing.xs : CornerRadius.lg,
                topTrailingRadius: CornerRadius.lg
            ))
            .contextMenu { contextMenuItems }
    }

    private var classicBubbleBackground: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: CornerRadius.lg,
            bottomLeadingRadius: isFromUser ? CornerRadius.lg : Spacing.xs,
            bottomTrailingRadius: isFromUser ? Spacing.xs : CornerRadius.lg,
            topTrailingRadius: CornerRadius.lg
        )
        .fill(isFromUser ? AppColors.userBubble : AppColors.otherBubble)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        // Copy
        Button {
            UIPasteboard.general.string = message.content ?? ""
            HapticManager.copyAction()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        // Reply (focuses input)
        if onFocusInput != nil {
            Button {
                HapticManager.selectionChanged()
                onFocusInput?()
            } label: {
                Label("Reply", systemImage: "arrow.turn.up.left")
            }
        }

        // Edit — own messages within 15-minute window
        if canEdit {
            Button {
                HapticManager.selectionChanged()
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
                HapticManager.destructiveAction()
                onDelete?(message)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Edit Mode

    @ViewBuilder
    private var editingView: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            TextField("Edit message...", text: $editText, axis: .vertical)
                .limitTextLength(to: ValidationLimits.maxMessageLength, text: $editText)
                .font(AppTypography.bodyLarge())
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
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
                    HapticManager.navigationTap()
                    withAnimation(AppAnimation.standard) {
                        isEditing = false
                    }
                } label: {
                    Text("Cancel")
                        .font(AppTypography.buttonSmall())
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
                        .font(AppTypography.buttonSmall())
                        .foregroundColor(AppColors.buttonForeground)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(canSaveEdit ? AppColors.buttonBackground : AppColors.disabled)
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
            HapticManager.messageSent()
            withAnimation(AppAnimation.standard) {
                isEditing = false
            }
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let sender = isFromUser ? "You" : (senderInitials ?? "Them")
        let content = message.content ?? ""
        let edited = message.isEdited ? ", edited" : ""
        return "\(sender): \(content)\(edited), \(timeText)"
    }
}
