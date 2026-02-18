//
//  GroupConversationView.swift
//  Swiss Coin
//
//  iMessage-style conversation view for group interactions.
//

import CoreData
import os
import SwiftUI

struct GroupConversationView: View {
    @ObservedObject var group: UserGroup
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    // MARK: - State

    @State private var showingAddTransaction = false
    @State private var showingSettlement = false
    @State private var showingReminder = false
    @State private var showingGroupDetail = false
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

    // Undo toast state (settlements)
    @State private var showUndoSettlementToast = false
    @State private var cachedSettlementAmount: Double = 0
    @State private var cachedSettlementCurrency: String?
    @State private var cachedSettlementDate: Date = Date()
    @State private var cachedSettlementNote: String?
    @State private var cachedSettlementIsFullSettlement: Bool = false
    @State private var cachedSettlementFromPerson: Person?
    @State private var cachedSettlementToPerson: Person?

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
    @State private var cachedTxnGroup: UserGroup?
    @State private var cachedTxnSplitPersons: [Person?] = []
    @State private var cachedTxnSplitAmounts: [Double] = []
    @State private var cachedTxnSplitRawAmounts: [Double] = []

    // MARK: - Timeline Constants

    private let timelineCircleSize: CGFloat = AvatarSize.xs
    private let timelineLeadingPad: CGFloat = Spacing.lg
    private let timelineToContent: CGFloat = Spacing.md

    // MARK: - Cached Data (computed asynchronously to avoid blocking main thread)

    @State private var balance: CurrencyBalance = CurrencyBalance()
    @State private var groupedItems: [GroupConversationDateGroup] = []
    @State private var cachedMemberBalances: [(member: Person, balance: CurrencyBalance)] = []
    @State private var cachedMembersWhoOweYou: [(member: Person, balance: CurrencyBalance)] = []

    private var totalItemCount: Int {
        groupedItems.reduce(0) { $0 + $1.items.count }
    }

    private var memberCount: Int {
        group.members?.count ?? 0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            messagesScrollArea
            actionBar
            messageInput
        }
        .background(AppColors.conversationBackground)
        .applyNavigationBar()
        .applyToolbar(leading: { toolbarLeadingContent }, trailing: { EmptyView() })
        .sheet(isPresented: $showingAddTransaction) {
            addTransactionSheet
        }
        .sheet(isPresented: $showingSettlement) {
            settlementSheet
        }
        .sheet(isPresented: $showingReminder) {
            reminderSheet
        }
        .sheet(isPresented: $showingGroupDetail) {
            groupDetailSheet
        }
        .sheet(item: $showingTransactionDetail) { transaction in
            transactionDetailSheet(transaction: transaction)
        }
        .sheet(item: $transactionToEdit) { transaction in
            transactionEditSheet(transaction: transaction)
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
        .undoToast(
            isShowing: $showUndoTransactionToast,
            message: "Transaction undone",
            onUndo: restoreUndoneTransaction
        )
        .undoToast(
            isShowing: $showUndoSettlementToast,
            message: "Settlement deleted",
            onUndo: restoreUndoneSettlement
        )
        .task {
            loadGroupConversationData()
            markGroupViewed()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            loadGroupConversationData()
            markGroupViewed()
        }
    }

    // MARK: - Sub-Views

    private var messagesScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                conversationContent
                    .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(conversationBackgroundView)
            .onTapGesture {
                hideKeyboard()
            }
            .onAppear {
                HapticManager.prepare()
                scrollToBottom(proxy)
            }
            .onChange(of: totalItemCount) { _, _ in
                withAnimation(AppAnimation.standard) {
                    scrollToBottom(proxy)
                }
            }
        }
    }

    private var conversationContent: some View {
        LazyVStack(spacing: 0) {
            if groupedItems.isEmpty {
                emptyStateView
            } else {
                ForEach(Array(groupedItems.enumerated()), id: \.element.id) { groupIndex, dateGroup in
                    dateGroupSection(dateGroup: dateGroup, groupIndex: groupIndex)
                }
            }
        }
    }

    @ViewBuilder
    private func dateGroupSection(dateGroup: GroupConversationDateGroup, groupIndex: Int) -> some View {
        DateHeaderView(dateString: dateGroup.dateDisplayString)
            .padding(.top, groupIndex == 0 ? Spacing.md : Spacing.lg)
            .padding(.bottom, Spacing.sm)

        ForEach(Array(dateGroup.items.enumerated()), id: \.element.id) { itemIndex, item in
            let isLastInGroup = itemIndex == dateGroup.items.count - 1
            let isLastGroup = groupIndex == groupedItems.count - 1
            let isLastItem = isLastInGroup && isLastGroup

            timelineRow(item: item, isLastItem: isLastItem)
                .id(item.id)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private var conversationBackgroundView: some View {
        ZStack {
            AppColors.conversationBackground
            DotGridPattern(
                dotSpacing: 16,
                dotRadius: 0.5,
                color: AppColors.receiptDot.opacity(0.5)
            )
        }
    }

    private var actionBar: some View {
        GroupConversationActionBar(
            memberBalances: cachedMemberBalances,
            membersWhoOweYou: cachedMembersWhoOweYou,
            onAdd: { showingAddTransaction = true },
            onSettle: { showingSettlement = true },
            onRemind: { showingReminder = true }
        )
    }

    private var messageInput: some View {
        MessageInputView(
            messageText: $messageText,
            onSend: sendMessage
        )
    }

    /// Update lastViewedDate to clear the badge for this group
    private func markGroupViewed() {
        guard group.lastViewedDate == nil ||
              Date().timeIntervalSince(group.lastViewedDate!) > 1.0 else { return }
        group.lastViewedDate = Date()
        try? viewContext.save()
    }

    /// Recompute balance, conversation items, and member balances. Called outside of body
    /// evaluation so the main run loop can process gestures between UI updates.
    private func loadGroupConversationData() {
        balance = group.calculateBalance()
        groupedItems = group.getGroupedConversationItems()
        cachedMemberBalances = group.getMemberBalances()
        cachedMembersWhoOweYou = group.getMembersWhoOweYou()
    }

    // MARK: - Toolbar Content

    @ViewBuilder
    private var toolbarLeadingContent: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                HapticManager.navigationTap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: IconSize.md, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
            .accessibilityLabel("Back to People")

            Button {
                HapticManager.navigationTap()
                showingGroupDetail = true
            } label: {
                groupHeaderContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View \(group.name ?? "group") details")
        }
    }

    @ViewBuilder
    private var groupHeaderContent: some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color(hex: group.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(.system(size: IconSize.sm, weight: .semibold))
                        .foregroundColor(Color(hex: group.colorHex ?? CurrentUser.defaultColorHex))
                )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(group.name ?? "Unknown Group")
                        .font(AppTypography.headingMedium())
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }

                groupBalanceSubtitle
            }
        }
    }

    private var groupBalanceSubtitle: some View {
        BalancePillView(balance: balance, prefixText: "\(memberCount) members")
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "person.3.fill")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                .accessibilityHidden(true)

            Text("No activity yet")
                .font(AppTypography.headingMedium())
                .foregroundColor(AppColors.textSecondary)

            Text("Start a conversation with \(group.name ?? "the group") or add a group expense")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.rowHeight)
    }

    // MARK: - Timeline Row

    @ViewBuilder
    private func timelineRow(item: GroupConversationItem, isLastItem: Bool) -> some View {
        if item.isSystemStrip {
            // Reminders & settlements render as centered pill notifications — no avatar
            conversationItemView(for: item)
                .padding(.bottom, isLastItem ? 0 : Spacing.lg)
        } else {
            let isMessage = isMessageItem(item)
            let avatar = itemAvatarInfo(for: item)

            HStack(alignment: .top, spacing: 0) {
                timelineConnector(
                    isMessage: isMessage,
                    avatarInitials: avatar.initials,
                    avatarColor: avatar.color
                )

                conversationItemView(for: item)
                    .padding(.trailing, Spacing.lg)
                    .padding(.bottom, isLastItem ? 0 : Spacing.lg)
            }
        }
    }

    private func isMessageItem(_ item: GroupConversationItem) -> Bool {
        if case .message = item { return true }
        return false
    }

    // MARK: - Item Avatar Info

    private func itemAvatarInfo(for item: GroupConversationItem) -> (initials: String, color: String) {
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
            return ("?", CurrentUser.defaultColorHex)
        }
    }

    // MARK: - Timeline Connector

    @ViewBuilder
    private func timelineConnector(isMessage: Bool, avatarInitials: String, avatarColor: String) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: isMessage ? Spacing.sm : Spacing.lg)

            ConversationAvatarView(
                initials: avatarInitials,
                colorHex: avatarColor,
                size: timelineCircleSize
            )

            Spacer(minLength: 0)
        }
        .frame(width: timelineCircleSize)
        .padding(.leading, timelineLeadingPad)
        .padding(.trailing, timelineToContent)
    }

    // MARK: - Conversation Item View

    @ViewBuilder
    private func conversationItemView(for item: GroupConversationItem) -> some View {
        switch item {
        case .transaction(let transaction):
            FeedTransactionContent(
                transaction: transaction,
                group: group,
                cardStyle: true,
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

        case .settlement(let settlement):
            GroupSettlementMessageView(
                settlement: settlement,
                onDelete: {
                    deleteSettlementWithUndo(settlement)
                }
            )

        case .reminder(let reminder):
            GroupReminderMessageView(reminder: reminder)

        case .message(let chatMessage):
            feedContentHeader(
                name: chatMessage.isFromUser ? "You" : "Member",
                timestamp: chatMessage.timestamp
            ) {
                FeedMessageContent(
                    message: chatMessage,
                    onDelete: { msg in
                        deleteMessageWithUndo(msg)
                    }
                )
            }
        }
    }

    // MARK: - Feed Content Helpers

    @ViewBuilder
    private func feedContentHeader<Content: View>(
        name: String,
        timestamp: Date?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(name)
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                if let timestamp {
                    Text("\u{00B7}")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textTertiary)

                    Text(timestamp.relativeShort)
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()
            }

            content()
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

        guard !group.isDeleted && group.managedObjectContext != nil else {
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
        newMessage.withGroup = group

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

    // MARK: - Settlement Delete with Undo

    private func deleteSettlementWithUndo(_ settlement: Settlement) {
        cachedSettlementAmount = settlement.amount
        cachedSettlementCurrency = settlement.currency
        cachedSettlementDate = settlement.date ?? Date()
        cachedSettlementNote = settlement.note
        cachedSettlementIsFullSettlement = settlement.isFullSettlement
        cachedSettlementFromPerson = settlement.fromPerson
        cachedSettlementToPerson = settlement.toPerson

        viewContext.delete(settlement)
        do {
            try viewContext.save()
            HapticManager.destructiveAction()
            withAnimation(AppAnimation.standard) {
                showUndoSettlementToast = true
            }
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
            errorMessage = "Failed to delete settlement."
            showingError = true
        }
    }

    private func restoreUndoneSettlement() {
        let restored = Settlement(context: viewContext)
        restored.id = UUID()
        restored.amount = cachedSettlementAmount
        restored.currency = cachedSettlementCurrency
        restored.date = cachedSettlementDate
        restored.note = cachedSettlementNote
        restored.isFullSettlement = cachedSettlementIsFullSettlement
        restored.fromPerson = cachedSettlementFromPerson
        restored.toPerson = cachedSettlementToPerson

        do {
            try viewContext.save()
            HapticManager.undoAction()
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
        }

        cachedSettlementFromPerson = nil
        cachedSettlementToPerson = nil
        cachedSettlementNote = nil
        cachedSettlementCurrency = nil
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
        restored.withGroup = group

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

    // MARK: - Transaction Undo

    private func undoTransactionWithToast(_ transaction: FinancialTransaction) {
        // Cache transaction data before deletion
        cachedTxnTitle = transaction.title ?? ""
        cachedTxnAmount = transaction.amount
        cachedTxnDate = transaction.date ?? Date()
        cachedTxnSplitMethod = transaction.splitMethod ?? "equal"
        cachedTxnPayer = transaction.payer
        cachedTxnCreatedBy = transaction.createdBy
        cachedTxnGroup = transaction.group

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
        restored.group = cachedTxnGroup

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

// MARK: - View Extensions for Modifier Composition

extension View {
    @ViewBuilder
    fileprivate func applyNavigationBar() -> some View {
        self
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.conversationBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .tint(AppColors.textSecondary)
            .navigationBarBackButtonHidden(true)
            .enableSwipeBack()
    }

    @ViewBuilder
    fileprivate func applyToolbar<Leading: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        self.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                leading()
            }
            ToolbarItem(placement: .topBarTrailing) {
                trailing()
            }
        }
    }
}

// MARK: - GroupConversationView Sheet & Alert Helpers

extension GroupConversationView {
    private var addTransactionSheet: some View {
        AddTransactionPresenter(initialGroup: group)
            .onAppear { HapticManager.sheetPresent() }
    }

    private var settlementSheet: some View {
        GroupSettlementView(group: group)
            .onAppear { HapticManager.sheetPresent() }
    }

    private var reminderSheet: some View {
        GroupReminderSheetView(group: group)
            .onAppear { HapticManager.sheetPresent() }
    }

    private var groupDetailSheet: some View {
        NavigationStack {
            GroupDetailView(group: group)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            HapticManager.sheetDismiss()
                            showingGroupDetail = false
                        }
                    }
                }
        }
        .onAppear { HapticManager.sheetPresent() }
    }

    private func transactionDetailSheet(transaction: FinancialTransaction) -> some View {
        TransactionDetailSheet(
            transaction: transaction,
            person: nil,
            onEdit: {
                transactionToEdit = transaction
            },
            onDelete: {
                transactionToDelete = transaction
                showingDeleteTransaction = true
            }
        )
        .environment(\.managedObjectContext, viewContext)
    }

    private func transactionEditSheet(transaction: FinancialTransaction) -> some View {
        TransactionEditView(transaction: transaction)
            .onAppear { HapticManager.sheetPresent() }
    }

}
