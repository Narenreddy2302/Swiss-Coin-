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

    @State private var messageText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var transactionToDelete: FinancialTransaction?
    @State private var showingDeleteTransaction = false
    @State private var isMessageInputFocused = false

    // Transaction edit state
    @State private var transactionToEdit: FinancialTransaction?

    // Transaction comment state
    @State private var transactionToComment: FinancialTransaction?

    // Sheet presentation via enum
    @State private var activeSheet: ActiveSheet?

    // Undo state (messages)
    @State private var undoMessage = UndoMessageState()

    // Undo state (transactions)
    @State private var undoTransaction = UndoTransactionState()

    // Undo state (settlements)
    @State private var undoSettlement = UndoSettlementState()

    // Loading state
    @State private var isLoading = true

    // Scroll-to-bottom FAB state
    @State private var showScrollToBottom = false
    @State private var hasAppeared = false

    // MARK: - Sheet Enum

    enum ActiveSheet: Identifiable {
        case addTransaction
        case settlement
        case reminder
        case personDetail

        var id: String {
            switch self {
            case .addTransaction: return "addTransaction"
            case .settlement: return "settlement"
            case .reminder: return "reminder"
            case .personDetail: return "personDetail"
            }
        }
    }

    // MARK: - Undo State Structs

    struct UndoMessageState {
        var isShowing = false
        var content: String?
        var timestamp: Date?
        var isEdited = false
    }

    struct UndoTransactionState {
        var isShowing = false
        var title = ""
        var amount: Double = 0
        var date = Date()
        var splitMethod = "equal"
        var payer: Person?
        var createdBy: Person?
        var splitPersons: [Person?] = []
        var splitAmounts: [Double] = []
        var splitRawAmounts: [Double] = []
    }

    struct UndoSettlementState {
        var isShowing = false
        var amount: Double = 0
        var currency: String?
        var date = Date()
        var note: String?
        var isFullSettlement = false
        var fromPerson: Person?
        var toPerson: Person?
    }

    // MARK: - Timeline Constants

    private let timelineCircleSize: CGFloat = AvatarSize.xs
    private let timelineLeadingPad: CGFloat = Spacing.lg
    private let timelineToContent: CGFloat = Spacing.md

    // MARK: - Cached Data (computed asynchronously to avoid blocking main thread)

    @State private var balance: CurrencyBalance = CurrencyBalance()
    @State private var groupedItems: [ConversationDateGroup] = []

    private var allItems: [ConversationItem] {
        groupedItems.flatMap { $0.items }
    }

    private var totalItemCount: Int {
        groupedItems.reduce(0) { $0 + $1.items.count }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Messages Area
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if isLoading {
                                loadingPlaceholder
                            } else if groupedItems.isEmpty {
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
                                        .transition(.identity)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, Spacing.md)
                    }
                    .defaultScrollAnchor(.bottom)
                    .scrollDismissesKeyboard(.interactively)
                    .background(
                        ZStack {
                            AppColors.conversationBackground
                            DotGridPattern(
                                dotSpacing: 16,
                                dotRadius: 0.5,
                                color: AppColors.receiptDot
                            )
                        }
                    )
                    .onTapGesture {
                        hideKeyboard()
                    }
                    .onAppear {
                        HapticManager.prepare()
                        hasAppeared = true
                    }
                    .onChange(of: totalItemCount) { _, _ in
                        withAnimation(AppAnimation.standard) {
                            scrollToBottom(proxy)
                        }
                    }

                    // Scroll-to-bottom FAB
                    if showScrollToBottom {
                        scrollToBottomButton(proxy: proxy)
                    }
                }
            }

            // Action Bar
            ConversationActionBar(
                canSettle: !balance.isSettled,
                canRemind: balance.hasPositive,
                onAdd: { activeSheet = .addTransaction },
                onSettle: { activeSheet = .settlement },
                onRemind: { activeSheet = .reminder }
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
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addTransaction:
                AddTransactionPresenter(initialPerson: person)
                    .onAppear { HapticManager.sheetPresent() }
            case .settlement:
                SettlementView(person: person, currentBalance: balance.primaryAmount, currentCurrencyBalance: balance)
                    .onAppear { HapticManager.sheetPresent() }
            case .reminder:
                ReminderSheetView(person: person, amount: balance.primaryAmount)
                    .onAppear { HapticManager.sheetPresent() }
            case .personDetail:
                NavigationStack {
                    PersonDetailView(person: person)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    HapticManager.sheetDismiss()
                                    activeSheet = nil
                                }
                            }
                        }
                }
                .onAppear { HapticManager.sheetPresent() }
            }
        }
        .sheet(item: $showingTransactionDetail) { transaction in
            TransactionDetailSheet(
                transaction: transaction,
                person: person,
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
            isShowing: $undoMessage.isShowing,
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
            isShowing: $undoTransaction.isShowing,
            message: "Transaction undone",
            onUndo: restoreUndoneTransaction
        )
        .undoToast(
            isShowing: $undoSettlement.isShowing,
            message: "Settlement deleted",
            onUndo: restoreUndoneSettlement
        )
        .task {
            loadConversationData()
            markConversationViewed()
            isLoading = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { notification in
            guard isRelevantSave(notification) else { return }
            loadConversationData()
            markConversationViewed()
        }
        .onChange(of: person.isDeleted) { _, isDeleted in
            if isDeleted { dismiss() }
        }
    }

    // MARK: - Transaction Detail State

    @State private var showingTransactionDetail: FinancialTransaction?

    // MARK: - Loading Placeholder

    @ViewBuilder
    private var loadingPlaceholder: some View {
        VStack(spacing: Spacing.lg) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(alignment: .top, spacing: Spacing.md) {
                    Circle()
                        .fill(AppColors.backgroundTertiary)
                        .frame(width: timelineCircleSize, height: timelineCircleSize)
                        .padding(.leading, timelineLeadingPad)

                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(AppColors.backgroundTertiary)
                        .frame(height: Spacing.rowHeight)
                        .padding(.trailing, Spacing.lg)
                }
            }
        }
        .redacted(reason: .placeholder)
        .padding(.top, Spacing.lg)
    }

    // MARK: - Scroll-to-Bottom Button

    @ViewBuilder
    private func scrollToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button {
            HapticManager.lightTap()
            withAnimation(AppAnimation.standard) {
                scrollToBottom(proxy)
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
                .frame(width: ButtonHeight.md, height: ButtonHeight.md)
                .background(
                    Circle()
                        .fill(AppColors.elevatedSurface)
                        .shadow(color: AppColors.shadow, radius: Spacing.sm, x: 0, y: 2)
                )
        }
        .padding(.trailing, Spacing.lg)
        .padding(.bottom, Spacing.sm)
        .transition(.scale.combined(with: .opacity))
    }

    /// Update lastViewedDate to clear the badge for this person
    private func markConversationViewed() {
        guard person.lastViewedDate == nil ||
              Date().timeIntervalSince(person.lastViewedDate!) > 1.0 else { return }
        person.lastViewedDate = Date()
        try? viewContext.save()
    }

    /// Recompute balance and conversation items. Called outside of body evaluation
    /// so the main run loop can process gestures between UI updates.
    private func loadConversationData() {
        balance = person.calculateBalance()
        groupedItems = person.getGroupedConversationItems()
    }

    /// Check if the CoreData save notification is relevant to this person's data
    private func isRelevantSave(_ notification: Notification) -> Bool {
        let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

        let allChanged = insertedObjects.union(updatedObjects).union(deletedObjects)

        for obj in allChanged {
            // Direct person match
            if let p = obj as? Person, p.objectID == person.objectID { return true }
            // Transaction involving this person
            if let t = obj as? FinancialTransaction {
                if t.payer?.objectID == person.objectID { return true }
                if let splits = t.splits as? Set<TransactionSplit> {
                    if splits.contains(where: { $0.owedBy?.objectID == person.objectID }) { return true }
                }
            }
            // Message with this person
            if let m = obj as? ChatMessage, m.withPerson?.objectID == person.objectID { return true }
            // Settlement with this person
            if let s = obj as? Settlement {
                if s.fromPerson?.objectID == person.objectID || s.toPerson?.objectID == person.objectID { return true }
            }
            // Reminder with this person
            if let r = obj as? Reminder, r.toPerson?.objectID == person.objectID { return true }
            // TransactionSplit involving this person
            if let ts = obj as? TransactionSplit, ts.owedBy?.objectID == person.objectID { return true }
        }

        return false
    }

    // MARK: - Timeline Row

    @ViewBuilder
    private func timelineRow(item: ConversationItem, isLastItem: Bool) -> some View {
        if item.isSystemStrip {
            // Reminders & settlements render as centered pill notifications — no avatar
            conversationItemView(for: item)
                .padding(.bottom, isLastItem ? 0 : Spacing.lg)
        } else {
            let isMessage = item.isMessageType
            let avatar = itemAvatarInfo(for: item)

            HStack(alignment: .top, spacing: 0) {
                // Timeline column with avatar and connector line
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
        case .directMessage(let dm):
            if CurrentUser.isCurrentUser(dm.senderId) {
                return (CurrentUser.initials, CurrentUser.defaultColorHex)
            }
            return (person.initials, person.colorHex ?? CurrentUser.defaultColorHex)
        }
    }

    // MARK: - Timeline Connector

    @ViewBuilder
    private func timelineConnector(isMessage: Bool, avatarInitials: String, avatarColor: String) -> some View {
        VStack(spacing: 0) {
            // Top offset to vertically align avatar with first line of content
            Spacer()
                .frame(height: isMessage ? Spacing.sm : Spacing.lg)

            // Avatar marker
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

    // MARK: - Toolbar Components

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
                activeSheet = .personDetail
            } label: {
                personHeaderContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View \(person.name ?? "person") details")
        }
    }

    @ViewBuilder
    private var personHeaderContent: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                .overlay(
                    Text(person.initials)
                        .font(AppTypography.labelLarge())
                        .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(person.name ?? "Unknown")
                        .font(AppTypography.headingMedium())
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }

                personBalanceSubtitle
            }
        }
    }

    private var personBalanceSubtitle: some View {
        BalancePillView(balance: balance)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Circle()
                .fill(AppColors.accent.opacity(0.15))
                .frame(width: IconSize.xxl + Spacing.xl, height: IconSize.xxl + Spacing.xl)
                .overlay(
                    Image(systemName: "message.fill")
                        .font(.system(size: IconSize.xl))
                        .foregroundColor(AppColors.accent)
                )

            Text("No conversations yet")
                .font(AppTypography.headingMedium())
                .foregroundColor(AppColors.textPrimary)

            Text("Start a conversation with \(person.firstName) or add an expense")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)

            Button {
                HapticManager.selectionChanged()
                activeSheet = .addTransaction
            } label: {
                Text("Add Expense")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Spacing.xxxl)
            .padding(.top, Spacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    UIPasteboard.general.string = CurrencyFormatter.format(settlement.amount, currencyCode: settlement.effectiveCurrency)
                    HapticManager.copyAction()
                },
                onDelete: {
                    deleteSettlementWithUndo(settlement)
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

        case .directMessage(let dm):
            directMessageBubble(dm)
        }
    }

    // MARK: - Direct Message Bubble

    private func directMessageBubble(_ dm: DirectMessage) -> some View {
        let isFromUser = CurrentUser.isCurrentUser(dm.senderId)
        return HStack {
            if isFromUser { Spacer(minLength: Spacing.xxxl) }
            VStack(alignment: isFromUser ? .trailing : .leading, spacing: Spacing.xxs) {
                Text(dm.content ?? "")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(isFromUser ? AppColors.userBubbleText : AppColors.otherBubbleText)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(isFromUser ? AppColors.userBubble : AppColors.otherBubble)
                    .cornerRadius(CornerRadius.card)

                if let date = dm.createdAt {
                    Text(date, style: .time)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            if !isFromUser { Spacer(minLength: Spacing.xxxl) }
        }
    }

    // MARK: - Helper Methods

    private func settlementMessageText(_ settlement: Settlement) -> String {
        let formatted = CurrencyFormatter.format(settlement.amount, currencyCode: settlement.effectiveCurrency)
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
        undoMessage.content = message.content
        undoMessage.timestamp = message.timestamp
        undoMessage.isEdited = message.isEdited

        // Delete immediately
        viewContext.delete(message)
        do {
            try viewContext.save()
            HapticManager.destructiveAction()
            withAnimation(AppAnimation.standard) {
                undoMessage.isShowing = true
            }
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
            errorMessage = "Failed to delete message."
            showingError = true
            AppLogger.coreData.error("Failed to delete message: \(error.localizedDescription)")
        }
    }

    private func deleteSettlementWithUndo(_ settlement: Settlement) {
        undoSettlement.amount = settlement.amount
        undoSettlement.currency = settlement.currency
        undoSettlement.date = settlement.date ?? Date()
        undoSettlement.note = settlement.note
        undoSettlement.isFullSettlement = settlement.isFullSettlement
        undoSettlement.fromPerson = settlement.fromPerson
        undoSettlement.toPerson = settlement.toPerson

        viewContext.delete(settlement)
        do {
            try viewContext.save()
            HapticManager.destructiveAction()
            withAnimation(AppAnimation.standard) {
                undoSettlement.isShowing = true
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
        restored.amount = undoSettlement.amount
        restored.currency = undoSettlement.currency
        restored.date = undoSettlement.date
        restored.note = undoSettlement.note
        restored.isFullSettlement = undoSettlement.isFullSettlement
        restored.fromPerson = undoSettlement.fromPerson
        restored.toPerson = undoSettlement.toPerson

        do {
            try viewContext.save()
            HapticManager.undoAction()
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
        }
        undoSettlement = UndoSettlementState()
    }

    private func undoDeleteMessage() {
        guard let content = undoMessage.content else { return }

        let restored = ChatMessage(context: viewContext)
        restored.id = UUID()
        restored.content = content
        restored.timestamp = undoMessage.timestamp ?? Date()
        restored.isFromUser = true
        restored.isEdited = undoMessage.isEdited
        restored.withPerson = person

        do {
            try viewContext.save()
            HapticManager.undoAction()
        } catch {
            viewContext.rollback()
            HapticManager.errorAlert()
        }

        undoMessage = UndoMessageState()
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
        undoTransaction.title = transaction.title ?? ""
        undoTransaction.amount = transaction.amount
        undoTransaction.date = transaction.date ?? Date()
        undoTransaction.splitMethod = transaction.splitMethod ?? "equal"
        undoTransaction.payer = transaction.payer
        undoTransaction.createdBy = transaction.createdBy

        // Cache splits data
        let splits = (transaction.splits as? Set<TransactionSplit>) ?? []
        undoTransaction.splitPersons = splits.map { $0.owedBy }
        undoTransaction.splitAmounts = splits.map { $0.amount }
        undoTransaction.splitRawAmounts = splits.map { $0.rawAmount }

        // Delete transaction (splits cascade-deleted)
        viewContext.delete(transaction)
        do {
            try viewContext.save()
            HapticManager.destructiveAction()
            withAnimation(AppAnimation.standard) {
                undoTransaction.isShowing = true
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
        restored.title = undoTransaction.title
        restored.amount = undoTransaction.amount
        restored.date = undoTransaction.date
        restored.splitMethod = undoTransaction.splitMethod
        restored.payer = undoTransaction.payer
        restored.createdBy = undoTransaction.createdBy

        // Restore splits
        for i in 0..<undoTransaction.splitPersons.count {
            let split = TransactionSplit(context: viewContext)
            split.id = UUID()
            split.owedBy = undoTransaction.splitPersons[i]
            split.amount = undoTransaction.splitAmounts[i]
            if i < undoTransaction.splitRawAmounts.count {
                split.rawAmount = undoTransaction.splitRawAmounts[i]
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

        undoTransaction = UndoTransactionState()
    }
}
