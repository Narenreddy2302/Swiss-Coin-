//
//  PersonConversationView.swift
//  Swiss Coin
//
//  Professional timeline-style conversation view for person-to-person interactions.
//  Features receipt-style transaction cards and elegant message bubbles.
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
    @State private var isMessageInputFocused = false

    // Undo toast state (messages)
    @State private var showUndoToast = false
    @State private var deletedMessageContent: String?
    @State private var deletedMessageTimestamp: Date?
    @State private var deletedMessageIsEdited: Bool = false

    // Transaction edit state
    @State private var transactionToEdit: FinancialTransaction?

    // Transaction comment state
    @State private var transactionToComment: FinancialTransaction?

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

    // MARK: - Timeline Constants

    private let timelineCircleSize: CGFloat = AvatarSize.xs
    private let timelineLeadingPad: CGFloat = Spacing.lg
    private let timelineToContent: CGFloat = Spacing.md

    // MARK: - Cached Data (computed asynchronously to avoid blocking main thread)

    @State private var balance: Double = 0
    @State private var groupedItems: [ConversationDateGroup] = []

    private var allItems: [ConversationItem] {
        groupedItems.flatMap { $0.items }
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
                    LazyVStack(spacing: 0) {
                        if groupedItems.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(Array(groupedItems.enumerated()), id: \.element.id) { groupIndex, group in
                                // Date Header
                                DateHeaderView(dateString: group.dateDisplayString)
                                    .padding(.top, groupIndex == 0 ? Spacing.md : Spacing.lg)
                                    .padding(.bottom, Spacing.sm)

                                ForEach(Array(group.items.enumerated()), id: \.element.id) { itemIndex, item in
                                    let isLastInGroup = itemIndex == group.items.count - 1
                                    let isLastGroup = groupIndex == groupedItems.count - 1
                                    let isLastItem = isLastInGroup && isLastGroup

                                    timelineRow(
                                        item: item,
                                        isLastItem: isLastItem
                                    )
                                    .id(item.id)
                                }
                            }
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(
                    ZStack {
                        AppColors.conversationBackground
                        DotGridPattern(
                            dotSpacing: 16,
                            dotRadius: 0.5,
                            color: AppColors.receiptDot.opacity(0.5)
                        )
                    }
                )
                .onTapGesture {
                    hideKeyboard()
                }
                .onAppear {
                    HapticManager.prepare()
                    // Scroll to bottom without animation on initial load
                    scrollToBottom(proxy)
                }
                .onChange(of: totalItemCount) { _, _ in
                    // Only animate scroll for new content, not initial load
                    withAnimation(.easeOut(duration: 0.2)) {
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
        .background(AppColors.conversationBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.conversationBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .tint(AppColors.textSecondary)
        .navigationBarBackButtonHidden(true)
        .enableSwipeBack()
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
                .onAppear { HapticManager.sheetPresent() }
        }
        .sheet(isPresented: $showingSettlement) {
            SettlementView(person: person, currentBalance: balance)
                .onAppear { HapticManager.sheetPresent() }
        }
        .sheet(isPresented: $showingReminder) {
            ReminderSheetView(person: person, amount: balance)
                .onAppear { HapticManager.sheetPresent() }
        }
        .sheet(isPresented: $showingPersonDetail) {
            NavigationStack {
                PersonDetailView(person: person)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                HapticManager.sheetDismiss()
                                showingPersonDetail = false
                            }
                        }
                    }
            }
            .onAppear { HapticManager.sheetPresent() }
        }
        .sheet(item: $showingTransactionDetail) { transaction in
            NavigationStack {
                TransactionDetailSheet(transaction: transaction, person: person)
            }
            .onAppear { HapticManager.sheetPresent() }
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
                .onAppear { HapticManager.sheetPresent() }
        }
        .sheet(item: $transactionToComment) { transaction in
            TransactionCommentSheet(transaction: transaction, person: person)
                .onAppear { HapticManager.sheetPresent() }
        }
        .undoToast(
            isShowing: $showUndoTransactionToast,
            message: "Transaction undone",
            onUndo: restoreUndoneTransaction
        )
        .task {
            loadConversationData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            loadConversationData()
        }
    }

    /// Recompute balance and conversation items. Called outside of body evaluation
    /// so the main run loop can process gestures between UI updates.
    private func loadConversationData() {
        balance = person.calculateBalance()
        groupedItems = person.getGroupedConversationItems()
    }

    // MARK: - Timeline Row

    @ViewBuilder
    private func timelineRow(item: ConversationItem, isLastItem: Bool) -> some View {
        if item.isSystemStrip {
            // Reminders & settlements render as full-width notification strips — no avatar
            conversationItemView(for: item)
                .padding(.bottom, isLastItem ? 0 : Spacing.lg)
        } else {
            let isMessage = item.isMessageType
            let avatar = itemAvatarInfo(for: item)

            HStack(alignment: .top, spacing: 0) {
                // Timeline column with avatar
                timelineConnector(
                    isMessage: isMessage,
                    avatarInitials: avatar.initials,
                    avatarColor: avatar.color
                )

                // Content column
                conversationItemView(for: item)
                    .padding(.trailing, Spacing.lg)
                    .padding(.bottom, isLastItem ? 0 : Spacing.lg)
            }
        }
    }

    // MARK: - Item Avatar Info

    private func itemAvatarInfo(for item: ConversationItem) -> (initials: String, color: String) {
        switch item {
        case .transaction(let t):
            let isUserPayer = t.effectivePayers.contains { CurrentUser.isCurrentUser($0.personId) }
            if isUserPayer {
                return (CurrentUser.initials, CurrentUser.defaultColorHex)
            }
            return (t.payer?.initials ?? "?", t.payer?.colorHex ?? CurrentUser.defaultColorHex)
        case .settlement(let s):
            if CurrentUser.isCurrentUser(s.fromPerson?.id) {
                return (CurrentUser.initials, CurrentUser.defaultColorHex)
            }
            return (s.fromPerson?.initials ?? "?", s.fromPerson?.colorHex ?? CurrentUser.defaultColorHex)
        case .reminder:
            return (CurrentUser.initials, CurrentUser.defaultColorHex)
        case .message(let m):
            if m.isFromUser {
                return (CurrentUser.initials, CurrentUser.defaultColorHex)
            }
            return (person.initials, person.colorHex ?? CurrentUser.defaultColorHex)
        }
    }

    // MARK: - Timeline Connector

    @ViewBuilder
    private func timelineConnector(isMessage: Bool, avatarInitials: String, avatarColor: String) -> some View {
        // Avatar only - no connecting line
        ConversationAvatarView(
            initials: avatarInitials,
            colorHex: avatarColor,
            size: timelineCircleSize
        )
        .padding(.leading, timelineLeadingPad)
        .padding(.trailing, timelineToContent)
        .padding(.top, isMessage ? Spacing.sm : Spacing.lg)
    }

    // MARK: - Toolbar Components

    @ViewBuilder
    private var toolbarLeadingContent: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                HapticManager.navigationTap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.accent)
            }
            .accessibilityLabel("Back")

            Button {
                HapticManager.navigationTap()
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
                        .font(AppTypography.labelLarge())
                        .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                )

            Text(person.name ?? "Unknown")
                .font(AppTypography.headingMedium())
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
                .font(AppTypography.financialSmall())
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
                .font(AppTypography.headingMedium())
                .foregroundColor(AppColors.textSecondary)

            Text("Start a conversation with \(person.firstName) or add an expense")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)

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
            EnhancedTransactionCardView(
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
                },
                onComment: {
                    transactionToComment = transaction
                }
            )

        case .settlement(let settlement):
            SettlementMessageView(
                settlement: settlement,
                person: person,
                onCopy: {
                    UIPasteboard.general.string = settlementMessageText(settlement)
                    HapticManager.copyAction()
                },
                onCopyAmount: {
                    UIPasteboard.general.string = CurrencyFormatter.format(settlement.amount)
                    HapticManager.copyAction()
                }
            )

        case .reminder(let reminder):
            ReminderMessageView(
                reminder: reminder,
                onCopy: {
                    UIPasteboard.general.string = reminderMessageText(reminder)
                    HapticManager.copyAction()
                },
                onCopyAmount: {
                    UIPasteboard.general.string = CurrencyFormatter.format(reminder.amount)
                    HapticManager.copyAction()
                }
            )

        case .message(let chatMessage):
            TimelineMessageBubbleView(
                message: chatMessage,
                person: person,
                onDelete: { msg in
                    deleteMessageWithUndo(msg)
                },
                onFocusInput: {
                    isMessageInputFocused = true
                }
            )
        }
    }

    // MARK: - Helper Methods

    private func settlementMessageText(_ settlement: Settlement) -> String {
        let formatted = CurrencyFormatter.format(settlement.amount)
        let fromPersonId = settlement.fromPerson?.id
        let toPersonId = settlement.toPerson?.id

        if CurrentUser.isCurrentUser(fromPersonId) {
            if toPersonId == person.id {
                return "You paid \(person.firstName) \(formatted)"
            } else {
                return "You paid \(settlement.toPerson?.firstName ?? "someone") \(formatted)"
            }
        } else if CurrentUser.isCurrentUser(toPersonId) {
            if fromPersonId == person.id {
                return "\(person.firstName) paid you \(formatted)"
            } else {
                return "\(settlement.fromPerson?.firstName ?? "Someone") paid you \(formatted)"
            }
        } else {
            let fromName = settlement.fromPerson?.firstName ?? "Someone"
            let toName = settlement.toPerson?.firstName ?? "someone"
            return "\(fromName) paid \(toName) \(formatted)"
        }
    }

    private func reminderMessageText(_ reminder: Reminder) -> String {
        let formatted = CurrencyFormatter.format(reminder.amount)
        return "Reminder sent for \(formatted)"
    }

    // MARK: - Scroll Helpers

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastGroup = groupedItems.last,
           let lastItem = lastGroup.items.last {
            proxy.scrollTo(lastItem.id, anchor: .bottom)
        }
    }

    // MARK: - Message Actions

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
            HapticManager.messageSent()
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
            errorMessage = "Failed to send message. Please try again."
            showingError = true
            AppLogger.coreData.error("Failed to save message: \(error.localizedDescription)")
        }
    }

    private func deleteMessageWithUndo(_ message: ChatMessage) {
        // Cache data for potential undo
        deletedMessageContent = message.content
        deletedMessageTimestamp = message.timestamp
        deletedMessageIsEdited = message.isEdited

        // Delete immediately
        viewContext.delete(message)
        do {
            try viewContext.save()
            HapticManager.destructiveAction()
            withAnimation(AppAnimation.standard) {
                showUndoToast = true
            }
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
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
            HapticManager.undoAction()
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
        }

        deletedMessageContent = nil
        deletedMessageTimestamp = nil
        deletedMessageIsEdited = false
    }

    // MARK: - Transaction Actions

    private func deleteTransaction(_ transaction: FinancialTransaction) {
        // Delete associated splits first
        if let splits = transaction.splits as? Set<TransactionSplit> {
            splits.forEach { viewContext.delete($0) }
        }
        // Delete associated payers
        if let payers = transaction.payers as? Set<TransactionPayer> {
            payers.forEach { viewContext.delete($0) }
        }
        viewContext.delete(transaction)
        do {
            try viewContext.save()
            HapticManager.destructiveAction()
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
            errorMessage = "Failed to delete transaction."
            showingError = true
            AppLogger.coreData.error("Failed to delete transaction: \(error.localizedDescription)")
        }
    }

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
            HapticManager.destructiveAction()
            withAnimation(AppAnimation.standard) {
                showUndoTransactionToast = true
            }
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
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
            HapticManager.undoAction()
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
        }

        // Clear cached data
        cachedTxnSplitPersons = []
        cachedTxnSplitAmounts = []
        cachedTxnSplitRawAmounts = []
    }
}
