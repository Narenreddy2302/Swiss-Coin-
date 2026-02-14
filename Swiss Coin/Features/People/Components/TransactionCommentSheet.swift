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

    // Error state
    @State private var showingError = false
    @State private var errorMessage = ""

    // Undo state
    @State private var showUndoToast = false
    @State private var deletedCommentContent: String?
    @State private var deletedCommentTimestamp: Date?
    @State private var deletedCommentIsEdited: Bool = false

    // Edit state
    @State private var editingCommentId: UUID?
    @State private var editCommentText: String = ""

    // Cached sorted comments
    @State private var cachedSortedComments: [ChatMessage] = []

    // Send button animation
    @State private var sendButtonScale: CGFloat = 1.0

    // MARK: - Static Formatters

    private static let todayTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let fullTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    // MARK: - Computed Properties

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

    private var splitMethodDisplay: String {
        switch transaction.splitMethod {
        case "equal": return "= Equally"
        case "amount": return "$ By Amount"
        case "percentage": return "% By Percentage"
        case "shares": return "÷ By Shares"
        case "adjustment": return "± Adjusted"
        default: return "= Equally"
        }
    }

    private var canSend: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var commentCountLabel: String {
        let count = cachedSortedComments.count
        return count == 1 ? "1 comment" : "\(count) comments"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Transaction context header
                transactionHeader

                AppColors.transactionCardDivider
                    .frame(height: 0.5)

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
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .undoToast(
            isShowing: $showUndoToast,
            message: "Comment deleted",
            onUndo: undoDeleteComment
        )
        .onAppear {
            isInputFocused = true
            recomputeSortedComments()
        }
        .onChange(of: transaction.isDeleted) { _, isDeleted in
            if isDeleted { dismiss() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            recomputeSortedComments()
        }
    }

    // MARK: - Sorted Comments Cache

    private func recomputeSortedComments() {
        let commentSet = transaction.comments as? Set<ChatMessage> ?? []
        cachedSortedComments = commentSet.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
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

                HStack(spacing: Spacing.sm) {
                    Text(transactionDate)
                        .font(AppTypography.labelSmall())
                        .foregroundColor(AppColors.textSecondary)

                    if !cachedSortedComments.isEmpty {
                        Text("\u{00B7}")
                            .font(AppTypography.labelSmall())
                            .foregroundColor(AppColors.textTertiary)

                        Text(commentCountLabel)
                            .font(AppTypography.labelSmall())
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Text(splitMethodDisplay)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(AppColors.backgroundTertiary)
                    )
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
                    if cachedSortedComments.isEmpty {
                        emptyState
                    } else {
                        ForEach(cachedSortedComments, id: \.id) { comment in
                            commentBubble(for: comment)
                                .id(comment.id)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: cachedSortedComments.count) { _, _ in
                withAnimation(AppAnimation.standard) {
                    if let lastComment = cachedSortedComments.last {
                        proxy.scrollTo(lastComment.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastComment = cachedSortedComments.last {
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
                .frame(height: Spacing.xxxl)

            Circle()
                .fill(AppColors.accent.opacity(0.15))
                .frame(width: IconSize.xxl + Spacing.xl, height: IconSize.xxl + Spacing.xl)
                .overlay(
                    Image(systemName: "text.bubble")
                        .font(.system(size: IconSize.xl))
                        .foregroundColor(AppColors.accent)
                )

            Text("Start the conversation")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)

            Text("Comments help keep everyone on the same page")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)

            Spacer()
                .frame(height: Spacing.xxxl)
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
        let alignment: HorizontalAlignment = isFromUser ? .trailing : .leading
        let frameAlignment: Alignment = isFromUser ? .trailing : .leading
        let bubbleShadow = AppShadow.bubble(for: colorScheme)
        let isEditing = editingCommentId == comment.id

        VStack(alignment: alignment, spacing: Spacing.xxs) {
            // Sender label
            Text(senderName)
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.xs)

            if isEditing {
                // Inline edit mode
                editBubble(for: comment)
            } else {
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
                                color: bubbleShadow.color,
                                radius: bubbleShadow.radius,
                                x: bubbleShadow.x,
                                y: bubbleShadow.y
                            )
                    )
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: frameAlignment)
            }

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
            .padding(.horizontal, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .contextMenu {
            Button {
                UIPasteboard.general.string = comment.content ?? ""
                HapticManager.copyAction()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                HapticManager.selectionChanged()
                commentText = "@\(senderName) "
                isInputFocused = true
            } label: {
                Label("Reply", systemImage: "arrow.turn.up.left")
            }

            if isFromUser && canEditComment(comment) {
                Button {
                    HapticManager.selectionChanged()
                    editCommentText = comment.content ?? ""
                    withAnimation(AppAnimation.standard) {
                        editingCommentId = comment.id
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
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

    // MARK: - Edit Bubble

    @ViewBuilder
    private func editBubble(for comment: ChatMessage) -> some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            TextField("Edit comment...", text: $editCommentText, axis: .vertical)
                .limitTextLength(to: ValidationLimits.maxMessageLength, text: $editCommentText)
                .font(AppTypography.bodyDefault())
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(AppColors.backgroundTertiary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .stroke(AppColors.accent, lineWidth: 2)
                )
                .lineLimit(1...8)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75)

            HStack(spacing: Spacing.sm) {
                Button {
                    HapticManager.navigationTap()
                    withAnimation(AppAnimation.standard) {
                        editingCommentId = nil
                        editCommentText = ""
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
                    saveCommentEdit(comment)
                } label: {
                    Text("Save")
                        .font(AppTypography.buttonSmall())
                        .foregroundColor(AppColors.buttonForeground)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(canSaveCommentEdit(comment) ? AppColors.buttonBackground : AppColors.disabled)
                        )
                }
                .disabled(!canSaveCommentEdit(comment))
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
                .accessibilityLabel("Comment input")
                .accessibilityHint("Type a comment about this transaction")

            Button {
                if canSend {
                    sendComment()
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
            .accessibilityLabel("Send comment")
            .accessibilityHint(canSend ? "Sends the typed comment" : "Type a comment first")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.messageInputBackground)
    }

    // MARK: - Edit Helpers

    private func canEditComment(_ comment: ChatMessage) -> Bool {
        guard let timestamp = comment.timestamp else { return false }
        return Date().timeIntervalSince(timestamp) < 15 * 60
    }

    private func canSaveCommentEdit(_ comment: ChatMessage) -> Bool {
        let trimmed = editCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != comment.content
    }

    private func saveCommentEdit(_ comment: ChatMessage) {
        let trimmed = editCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != comment.content else { return }

        comment.content = trimmed
        comment.isEdited = true

        do {
            try viewContext.save()
            HapticManager.messageSent()
            withAnimation(AppAnimation.standard) {
                editingCommentId = nil
                editCommentText = ""
            }
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
            errorMessage = "Failed to save edit. Please try again."
            showingError = true
        }
    }

    // MARK: - Actions

    private func sendComment() {
        let trimmedText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        guard !transaction.isDeleted && transaction.managedObjectContext != nil else {
            errorMessage = "Unable to send comment. The transaction may have been deleted."
            showingError = true
            return
        }

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
            // Spring bounce on send
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                sendButtonScale = 0.7
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    sendButtonScale = 1.0
                }
            }
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
            errorMessage = "Failed to send comment. Please try again."
            showingError = true
        }
    }

    private func deleteComment(_ comment: ChatMessage) {
        // Cache data for potential undo
        deletedCommentContent = comment.content
        deletedCommentTimestamp = comment.timestamp
        deletedCommentIsEdited = comment.isEdited

        viewContext.delete(comment)
        do {
            try viewContext.save()
            HapticManager.destructiveAction()
            withAnimation(AppAnimation.standard) {
                showUndoToast = true
            }
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
            errorMessage = "Failed to delete comment."
            showingError = true
        }
    }

    private func undoDeleteComment() {
        guard let content = deletedCommentContent else { return }

        let restored = ChatMessage(context: viewContext)
        restored.id = UUID()
        restored.content = content
        restored.timestamp = deletedCommentTimestamp ?? Date()
        restored.isFromUser = true
        restored.isEdited = deletedCommentIsEdited
        restored.withPerson = person
        restored.onTransaction = transaction

        do {
            try viewContext.save()
            HapticManager.undoAction()
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
        }

        deletedCommentContent = nil
        deletedCommentTimestamp = nil
        deletedCommentIsEdited = false
    }

    // MARK: - Helpers

    private func commentTimeText(_ comment: ChatMessage) -> String {
        guard let timestamp = comment.timestamp else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(timestamp) {
            return Self.todayTimeFormatter.string(from: timestamp)
        } else {
            return Self.fullTimeFormatter.string(from: timestamp)
        }
    }
}
