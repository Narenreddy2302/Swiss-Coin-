//
//  TimelineMessageBubbleView.swift
//  Swiss Coin
//
//  Message bubble designed for the conversation timeline.
//  Professional chat-style with timeline connector support.
//

import SwiftUI
import CoreData

struct TimelineMessageBubbleView: View {
    @ObservedObject var message: ChatMessage
    let person: Person
    var onDelete: ((ChatMessage) -> Void)? = nil
    var onFocusInput: (() -> Void)? = nil

    @Environment(\.managedObjectContext) private var viewContext
    @State private var isEditing = false
    @State private var editText = ""

    // MARK: - Computed Properties

    private var isFromUser: Bool {
        message.isFromUser
    }

    private var senderName: String {
        isFromUser ? "You" : (person.firstName)
    }

    private var senderInitials: String {
        isFromUser ? CurrentUser.initials : person.initials
    }

    private var senderColorHex: String {
        isFromUser ? CurrentUser.defaultColorHex : (person.colorHex ?? CurrentUser.defaultColorHex)
    }

    /// Edit window: 15 minutes from message creation
    private var canEdit: Bool {
        guard isFromUser else { return false }
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
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if isEditing {
                editingView
            } else {
                messageContent
            }

            // Timestamp and Edited badge
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
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.lg))
        .contextMenu { contextMenuItems }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isFromUser ? "Double tap and hold for options" : "")
    }

    // MARK: - Message Content

    @ViewBuilder
    private var messageContent: some View {
        Text(message.content ?? "")
            .font(AppTypography.bodyLarge())
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .stroke(AppColors.border.opacity(0.5), lineWidth: 0.5)
            )
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
        Button {
            HapticManager.selectionChanged()
            onFocusInput?()
        } label: {
            Label("Reply", systemImage: "arrow.turn.up.left")
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
        let edited = message.isEdited ? ", edited" : ""
        return "\(senderName): \(message.content ?? "")\(edited), \(timeText)"
    }

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme
}

// MARK: - Preview

#Preview("Timeline Message Bubble") {
    let context = PersistenceController.shared.container.viewContext

    let person: Person = {
        let p = Person(context: context)
        p.id = UUID()
        p.name = "Steve Harington"
        p.colorHex = "#F35B16"
        return p
    }()

    let message: ChatMessage = {
        let m = ChatMessage(context: context)
        m.id = UUID()
        m.content = "Hey Mike! I will be paying it off by Saturday...!"
        m.timestamp = Date()
        m.isFromUser = true
        m.isEdited = false
        return m
    }()

    TimelineMessageBubbleView(message: message, person: person)
        .padding()
        .background(AppColors.backgroundSecondary)
}
