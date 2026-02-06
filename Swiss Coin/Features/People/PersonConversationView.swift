//
//  PersonConversationView.swift
//  Swiss Coin
//
//  iMessage-style conversation view for person-to-person interactions.
//

import CoreData
import os
import SwiftUI

struct PersonConversationView: View {
    @ObservedObject var person: Person
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    // MARK: - State

    @State private var showingAddTransaction = false
    @State private var showingSettlement = false
    @State private var showingReminder = false
    @State private var showingPersonDetail = false
    @State private var messageText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var transactionToDelete: FinancialTransaction?
    @State private var showingDeleteTransaction = false
    @State private var showingTransactionDetail: FinancialTransaction?

    // Undo toast state (messages)
    @State private var showUndoToast = false
    @State private var deletedMessageContent: String?
    @State private var deletedMessageTimestamp: Date?
    @State private var deletedMessageIsEdited: Bool = false

    // Transaction edit state
    @State private var transactionToEdit: FinancialTransaction?

    // Transaction undo toast state
    @State private var showUndoTransactionToast = false
    @State private var cachedTxnTitle: String = ""
    @State private var cachedTxnAmount: Double = 0
    @State private var cachedTxnDate: Date = Date()
    @State private var cachedTxnSplitMethod: String = "equal"
    @State private var cachedTxnPayer: Person?
    @State private var cachedTxnCreatedBy: Person?
    @State private var cachedTxnSplitPersons: [Person?] = []
    @State private var cachedTxnSplitAmounts: [Double] = []
    @State private var cachedTxnSplitRawAmounts: [Double] = []

    // Retained haptic generator for reliable feedback
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Computed Properties

    private var balance: Double {
        person.calculateBalance()
    }

    private var groupedItems: [ConversationDateGroup] {
        person.getGroupedConversationItems()
    }

    private var totalItemCount: Int {
        groupedItems.reduce(0) { $0 + $1.items.count }
    }

    private var balanceLabel: String {
        if balance > 0.01 { return "owes you" }
        else if balance < -0.01 { return "you owe" }
        else { return "settled" }
    }

    private var balanceAmount: String {
        CurrencyFormatter.formatAbsolute(balance)
    }

    private var balanceColor: Color {
        if balance > 0.01 { return AppColors.positive }
        else if balance < -0.01 { return AppColors.negative }
        else { return AppColors.neutral }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Messages Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        if groupedItems.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(groupedItems) { group in
                                DateHeaderView(dateString: group.dateDisplayString)
                                    .padding(.top, Spacing.lg)
                                    .padding(.bottom, Spacing.sm)

                                ForEach(group.items) { item in
                                    conversationItemView(for: item)
                                        .id(item.id)
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                }
                            }
                        }
                    }
                    .padding(.vertical, Spacing.lg)
                }
                .background(AppColors.background)
                .onTapGesture {
                    hideKeyboard()
                }
                .onAppear {
                    hapticGenerator.prepare()
                    scrollToBottom(proxy)
                }
                .onChange(of: totalItemCount) { _, _ in
                    withAnimation(AppAnimation.standard) {
                        scrollToBottom(proxy)
                    }
                }
            }

            // Action Bar
            ConversationActionBar(
                balance: balance,
                onAdd: { showingAddTransaction = true },
                onSettle: { showingSettlement = true },
                onRemind: { showingReminder = true }
            )

            // Message Input
            MessageInputView(
                messageText: $messageText,
                onSend: sendMessage
            )
        }
        .background(AppColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.backgroundTertiary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .tint(AppColors.textSecondary)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                toolbarLeadingContent
            }
            ToolbarItem(placement: .topBarTrailing) {
                toolbarTrailingContent
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            QuickActionSheetPresenter(initialPerson: person)
        }
        .sheet(isPresented: $showingSettlement) {
            SettlementView(person: person, currentBalance: balance)
        }
        .sheet(isPresented: $showingReminder) {
            ReminderSheetView(person: person, amount: balance)
        }
        .sheet(isPresented: $showingPersonDetail) {
            NavigationStack {
                PersonDetailView(person: person)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingPersonDetail = false
                            }
                        }
                    }
            }
        }
        .sheet(item: $showingTransactionDetail) { transaction in
            NavigationStack {
                TransactionDetailSheet(transaction: transaction, person: person)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Delete Transaction", isPresented: $showingDeleteTransaction) {
            Button("Cancel", role: .cancel) {
                transactionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let transaction = transactionToDelete {
                    deleteTransaction(transaction)
                }
                transactionToDelete = nil
            }
        } message: {
            Text("This will permanently delete this transaction and update all related balances. This cannot be undone.")
        }
        .undoToast(
            isShowing: $showUndoToast,
            message: "Message deleted",
            onUndo: undoDeleteMessage
        )
        .sheet(item: $transactionToEdit) { transaction in
            TransactionEditView(transaction: transaction)
        }
        .undoToast(
            isShowing: $showUndoTransactionToast,
            message: "Transaction undone",
            onUndo: restoreUndoneTransaction
        )
    }

    // MARK: - Toolbar Components

    @ViewBuilder
    private var toolbarLeadingContent: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                HapticManager.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.accent)
            }
            .accessibilityLabel("Back")

            Button {
                HapticManager.tap()
                showingPersonDetail = true
            } label: {
                personHeaderContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View \(person.name ?? "person") details")
        }
    }

    @ViewBuilder
    private var personHeaderContent: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                .overlay(
                    Text(person.initials)
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                )

            Text(person.name ?? "Unknown")
                .font(AppTypography.bodyBold())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var toolbarTrailingContent: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(balanceLabel)
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)

            Text(balanceAmount)
                .font(AppTypography.amountSmall())
                .foregroundColor(balanceColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Balance: \(balanceLabel) \(balanceAmount)")
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "message.fill")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                .accessibilityHidden(true)

            Text("No conversations yet")
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textSecondary)

            Text("Start a conversation with \(person.firstName) or add an expense")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Conversation Item View

    @ViewBuilder
    private func conversationItemView(for item: ConversationItem) -> some View {
        switch item {
        case .transaction(let transaction):
            TransactionCardView(
                transaction: transaction,
                person: person,
                onEdit: {
                    transactionToEdit = transaction
                },
                onViewDetails: {
                    showingTransactionDetail = transaction
                },
                onUndo: {
                    undoTransactionWithToast(transaction)
                },
                onDelete: {
                    transactionToDelete = transaction
                    showingDeleteTransaction = true
                }
            )
            .padding(.vertical, Spacing.xxs)

        case .settlement(let settlement):
            SettlementMessageView(settlement: settlement, person: person)
                .padding(.vertical, Spacing.xxs)

        case .reminder(let reminder):
            ReminderMessageView(reminder: reminder, person: person)
                .padding(.vertical, Spacing.xxs)

        case .message(let chatMessage):
            MessageBubbleView(
                message: chatMessage,
                onDelete: { msg in
                    deleteMessageWithUndo(msg)
                }
            )
            .padding(.vertical, 2)
        }
    }

    // MARK: - Helpers

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastGroup = groupedItems.last,
           let lastItem = lastGroup.items.last {
            proxy.scrollTo(lastItem.id, anchor: .bottom)
        }
    }

    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        guard !person.isDeleted && person.managedObjectContext != nil else {
            errorMessage = "Unable to send message. Please try again."
            showingError = true
            return
        }

        let newMessage = ChatMessage(context: viewContext)
        newMessage.id = UUID()
        newMessage.content = trimmedText
        newMessage.timestamp = Date()
        newMessage.isFromUser = true
        newMessage.isEdited = false
        newMessage.withPerson = person

        do {
            try viewContext.save()
            messageText = ""
            hapticGenerator.impactOccurred()
        } catch {
            viewContext.rollback()
            errorMessage = "Failed to send message. Please try again."
            showingError = true
            AppLogger.coreData.error("Failed to save message: \(error.localizedDescription)")
        }
    }

    private func deleteTransaction(_ transaction: FinancialTransaction) {
        viewContext.delete(transaction)
        do {
            try viewContext.save()
            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to delete transaction."
            showingError = true
            AppLogger.coreData.error("Failed to delete transaction: \(error.localizedDescription)")
        }
    }

    // MARK: - Message Delete with Undo

    private func deleteMessageWithUndo(_ message: ChatMessage) {
        // Cache data for potential undo
        deletedMessageContent = message.content
        deletedMessageTimestamp = message.timestamp
        deletedMessageIsEdited = message.isEdited

        // Delete immediately
        viewContext.delete(message)
        do {
            try viewContext.save()
            HapticManager.delete()
            withAnimation(AppAnimation.standard) {
                showUndoToast = true
            }
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to delete message."
            showingError = true
            AppLogger.coreData.error("Failed to delete message: \(error.localizedDescription)")
        }
    }

    private func undoDeleteMessage() {
        guard let content = deletedMessageContent else { return }

        let restored = ChatMessage(context: viewContext)
        restored.id = UUID()
        restored.content = content
        restored.timestamp = deletedMessageTimestamp ?? Date()
        restored.isFromUser = true
        restored.isEdited = deletedMessageIsEdited
        restored.withPerson = person

        do {
            try viewContext.save()
            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
        }

        deletedMessageContent = nil
        deletedMessageTimestamp = nil
        deletedMessageIsEdited = false
    }

    // MARK: - Transaction Undo

    private func undoTransactionWithToast(_ transaction: FinancialTransaction) {
        // Cache transaction data before deletion
        cachedTxnTitle = transaction.title ?? ""
        cachedTxnAmount = transaction.amount
        cachedTxnDate = transaction.date ?? Date()
        cachedTxnSplitMethod = transaction.splitMethod ?? "equal"
        cachedTxnPayer = transaction.payer
        cachedTxnCreatedBy = transaction.createdBy

        // Cache splits data
        let splits = (transaction.splits as? Set<TransactionSplit>) ?? []
        cachedTxnSplitPersons = splits.map { $0.owedBy }
        cachedTxnSplitAmounts = splits.map { $0.amount }
        cachedTxnSplitRawAmounts = splits.map { $0.rawAmount }

        // Delete transaction (splits cascade-deleted)
        viewContext.delete(transaction)
        do {
            try viewContext.save()
            HapticManager.delete()
            withAnimation(AppAnimation.standard) {
                showUndoTransactionToast = true
            }
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to undo transaction."
            showingError = true
        }
    }

    private func restoreUndoneTransaction() {
        let restored = FinancialTransaction(context: viewContext)
        restored.id = UUID()
        restored.title = cachedTxnTitle
        restored.amount = cachedTxnAmount
        restored.date = cachedTxnDate
        restored.splitMethod = cachedTxnSplitMethod
        restored.payer = cachedTxnPayer
        restored.createdBy = cachedTxnCreatedBy

        // Restore splits
        for i in 0..<cachedTxnSplitPersons.count {
            let split = TransactionSplit(context: viewContext)
            split.owedBy = cachedTxnSplitPersons[i]
            split.amount = cachedTxnSplitAmounts[i]
            if i < cachedTxnSplitRawAmounts.count {
                split.rawAmount = cachedTxnSplitRawAmounts[i]
            }
            split.transaction = restored
        }

        do {
            try viewContext.save()
            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
        }

        // Clear cached data
        cachedTxnSplitPersons = []
        cachedTxnSplitAmounts = []
        cachedTxnSplitRawAmounts = []
    }
}
