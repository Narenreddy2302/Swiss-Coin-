//
//  TransactionCommentSheet.swift
//  Swiss Coin
//
//  Sheet view for commenting on a specific transaction.
//  Shows transaction context at top, comments list, and message input.
//

import SwiftUI
import CoreData

struct TransactionCommentSheet: View {
    @ObservedObject var transaction: FinancialTransaction
    let person: Person
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var commentText = ""
    @FocusState private var isInputFocused: Bool

    // MARK: - Computed Properties

    private var sortedComments: [ChatMessage] {
        let commentSet = transaction.comments as? Set<ChatMessage> ?? []
        return commentSet.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }

    private var commentCount: Int {
        (transaction.comments as? Set<ChatMessage>)?.count ?? 0
    }

    private var transactionTitle: String {
        transaction.title ?? "Expense"
    }

    private var transactionAmount: String {
        CurrencyFormatter.format(transaction.amount)
    }

    private var transactionDate: String {
        guard let date = transaction.date else { return "" }
        return date.receiptFormatted
    }

    private var canSend: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Transaction context header
                transactionHeader

                Divider()
                    .foregroundColor(AppColors.border)

                // Comments list
                commentsArea

                // Comment input
                commentInput
            }
            .background(AppColors.conversationBackground)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.conversationBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.sheetDismiss()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(AppTypography.labelLarge())
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
        .onAppear {
            isInputFocused = true
        }
    }

    // MARK: - Transaction Header

    @ViewBuilder
    private var transactionHeader: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(transactionTitle)
                    .font(AppTypography.headingSmall())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text(transactionDate)
                    .font(AppTypography.labelSmall())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text(transactionAmount)
                .font(AppTypography.financialDefault())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.transactionCardBackground)
    }

    // MARK: - Comments Area

    @ViewBuilder
    private var commentsArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if sortedComments.isEmpty {
                        emptyState
                    } else {
                        ForEach(sortedComments, id: \.id) { comment in
                            commentBubble(for: comment)
                                .id(comment.id)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: commentCount) { _, _ in
                withAnimation(AppAnimation.standard) {
                    if let lastComment = sortedComments.last {
                        proxy.scrollTo(lastComment.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastComment = sortedComments.last {
                    proxy.scrollTo(lastComment.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "text.bubble")
                .font(.system(size: IconSize.xl))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))

            Text("No comments yet")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)

            Text("Add a comment about this transaction")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textTertiary)

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Comment Bubble

    @ViewBuilder
    private func commentBubble(for comment: ChatMessage) -> some View {
        let isFromUser = comment.isFromUser
        let bubbleColor = isFromUser ? AppColors.userBubble : AppColors.otherBubble
        let textColor = isFromUser ? AppColors.userBubbleText : AppColors.otherBubbleText
        let senderName = isFromUser ? "You" : (person.firstName)

        VStack(alignment: .leading, spacing: Spacing.xxs) {
            // Sender label
            Text(senderName)
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textSecondary)
                .padding(.leading, Spacing.xs)

            // Message bubble
            Text(comment.content ?? "")
                .font(AppTypography.bodyDefault())
                .foregroundColor(textColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(bubbleColor)
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05),
                            radius: 2,
                            x: 0,
                            y: 1
                        )
                )

            // Timestamp
            HStack(spacing: Spacing.xs) {
                if comment.isEdited {
                    Text("Edited")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
                Text(commentTimeText(comment))
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.leading, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button {
                UIPasteboard.general.string = comment.content ?? ""
                HapticManager.copyAction()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if isFromUser {
                Divider()
                Button(role: .destructive) {
                    deleteComment(comment)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Comment Input

    @ViewBuilder
    private var commentInput: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Add a comment...", text: $commentText, axis: .vertical)
                .focused($isInputFocused)
                .limitTextLength(to: ValidationLimits.maxMessageLength, text: $commentText)
                .font(AppTypography.bodyLarge())
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .fill(AppColors.messageInputFieldBackground)
                )
                .lineLimit(1...5)

            Button {
                if canSend {
                    sendComment()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: IconSize.xl))
                    .foregroundColor(canSend ? AppColors.accent : AppColors.accent.opacity(0.3))
            }
            .disabled(!canSend)
            .buttonStyle(AppButtonStyle(haptic: .none))
            .animation(AppAnimation.spring, value: canSend)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.messageInputBackground)
    }

    // MARK: - Actions

    private func sendComment() {
        let trimmedText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let newComment = ChatMessage(context: viewContext)
        newComment.id = UUID()
        newComment.content = trimmedText
        newComment.timestamp = Date()
        newComment.isFromUser = true
        newComment.isEdited = false
        newComment.withPerson = person
        newComment.onTransaction = transaction

        do {
            try viewContext.save()
            commentText = ""
            HapticManager.messageSent()
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
        }
    }

    private func deleteComment(_ comment: ChatMessage) {
        viewContext.delete(comment)
        do {
            try viewContext.save()
            HapticManager.destructiveAction()
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
        }
    }

    // MARK: - Helpers

    private func commentTimeText(_ comment: ChatMessage) -> String {
        guard let timestamp = comment.timestamp else { return "" }
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(timestamp) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: timestamp)
    }
}
