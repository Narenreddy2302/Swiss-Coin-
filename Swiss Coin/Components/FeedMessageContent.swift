//
//  FeedMessageContent.swift
//  Swiss Coin
//
//  Message content for feed rows with inline editing and context menu.
//

import SwiftUI
import CoreData

struct FeedMessageContent: View {
    @ObservedObject var message: ChatMessage
    var onDelete: ((ChatMessage) -> Void)? = nil
    var onFocusInput: (() -> Void)? = nil

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

    private var canSaveEdit: Bool {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != message.content
    }

    // MARK: - Body

    var body: some View {
        if isEditing {
            editingView
        } else {
            normalView
        }
    }

    // MARK: - Normal View

    @ViewBuilder
    private var normalView: some View {
        let bubbleColor = isFromUser ? AppColors.userBubble : AppColors.otherBubble
        let textColor = isFromUser ? AppColors.userBubbleText : AppColors.otherBubbleText

        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(message.content ?? "")
                .font(AppTypography.bodyLarge())
                .foregroundColor(textColor)

            if message.isEdited {
                Text("Edited")
                    .labelSmallStyle()
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(bubbleColor)
                .shadow(color: AppColors.shadowSubtle, radius: 4, x: 0, y: 2)
                .shadow(color: AppColors.shadowMicro, radius: 1, x: 0, y: 1)
        )
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.card))
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.content ?? ""
                HapticManager.copyAction()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if onFocusInput != nil {
                Button {
                    HapticManager.selectionChanged()
                    onFocusInput?()
                } label: {
                    Label("Reply", systemImage: "arrow.turn.up.left")
                }
            }

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

            if isFromUser, onDelete != nil {
                Divider()
                Button(role: .destructive) {
                    HapticManager.destructiveAction()
                    onDelete?(message)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Message: \(message.content ?? "")\(message.isEdited ? ", edited" : "")")
    }

    // MARK: - Editing View

    @ViewBuilder
    private var editingView: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            TextField("Edit message", text: $editText, axis: .vertical)
                .lineLimit(1...8)
                .limitTextLength(to: ValidationLimits.maxMessageLength, text: $editText)
                .font(AppTypography.bodyLarge())
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(AppColors.backgroundTertiary)
                )

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
}
