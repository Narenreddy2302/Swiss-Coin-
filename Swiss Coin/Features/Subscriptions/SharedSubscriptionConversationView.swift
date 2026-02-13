//
//  SharedSubscriptionConversationView.swift
//  Swiss Coin
//
//  Professional timeline-style conversation view for shared subscriptions.
//  Matches PersonConversationView and GroupConversationView layout patterns.
//

import CoreData
import os
import SwiftUI

struct SharedSubscriptionConversationView: View {
    @ObservedObject var subscription: Subscription
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var showingRecordPayment = false
    @State private var showingSettlement = false
    @State private var showingReminder = false
    @State private var showingSubscriptionDetail = false
    @State private var messageText = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    // Undo toast state (messages)
    @State private var showUndoToast = false
    @State private var deletedMessageContent: String?
    @State private var deletedMessageTimestamp: Date?
    @State private var deletedMessageIsEdited: Bool = false

    // MARK: - Timeline Constants

    private let timelineCircleSize: CGFloat = AvatarSize.xs
    private let timelineLeadingPad: CGFloat = Spacing.lg
    private let timelineToContent: CGFloat = Spacing.md

    // MARK: - Computed Properties

    private var balance: Double {
        subscription.calculateUserBalance()
    }

    private var groupedItems: [SubscriptionConversationDateGroup] {
        subscription.getGroupedConversationItems()
    }

    private var totalItemCount: Int {
        groupedItems.reduce(0) { $0 + $1.items.count }
    }

    private var balanceLabel: String {
        if balance > 0.01 { return "you're owed" }
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

    private var memberCount: Int {
        subscription.memberCount
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Messages Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Subscription Info Header Card
                        SubscriptionInfoCard(subscription: subscription)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.lg)
                            .padding(.bottom, Spacing.sm)

                        // Member Balances Card
                        MemberBalancesCard(subscription: subscription)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.bottom, Spacing.sm)

                        if groupedItems.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(Array(groupedItems.enumerated()), id: \.element.id) { groupIndex, group in
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
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                    scrollToBottom(proxy)
                }
                .onChange(of: totalItemCount) { _, _ in
                    withAnimation(AppAnimation.standard) {
                        scrollToBottom(proxy)
                    }
                }
            }

            // Action Bar
            SubscriptionActionBar(
                balance: balance,
                membersWhoOwe: subscription.getMembersWhoOweYou(),
                onRecordPayment: { showingRecordPayment = true },
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
        .sheet(isPresented: $showingRecordPayment) {
            RecordSubscriptionPaymentView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
                .onAppear { HapticManager.sheetPresent() }
        }
        .sheet(isPresented: $showingSettlement) {
            SubscriptionSettlementView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
                .onAppear { HapticManager.sheetPresent() }
        }
        .sheet(isPresented: $showingReminder) {
            SubscriptionReminderSheetView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
                .onAppear { HapticManager.sheetPresent() }
        }
        .sheet(isPresented: $showingSubscriptionDetail) {
            NavigationStack {
                SubscriptionDetailView(subscription: subscription)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                HapticManager.sheetDismiss()
                                showingSubscriptionDetail = false
                            }
                        }
                    }
            }
            .onAppear { HapticManager.sheetPresent() }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .undoToast(
            isShowing: $showUndoToast,
            message: "Message deleted",
            onUndo: undoDeleteMessage
        )
    }

    // MARK: - Timeline Row

    @ViewBuilder
    private func timelineRow(item: SubscriptionConversationItem, isLastItem: Bool) -> some View {
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

    private func isMessageItem(_ item: SubscriptionConversationItem) -> Bool {
        if case .message = item { return true }
        return false
    }

    // MARK: - Item Avatar Info

    private func itemAvatarInfo(for item: SubscriptionConversationItem) -> (initials: String, color: String) {
        switch item {
        case .payment(let payment):
            if CurrentUser.isCurrentUser(payment.payer?.id) {
                return (CurrentUser.initials, CurrentUser.defaultColorHex)
            }
            return (payment.payer?.initials ?? "?", payment.payer?.colorHex ?? CurrentUser.defaultColorHex)
        case .settlement(let settlement):
            if CurrentUser.isCurrentUser(settlement.fromPerson?.id) {
                return (CurrentUser.initials, CurrentUser.defaultColorHex)
            }
            return (settlement.fromPerson?.initials ?? "?", settlement.fromPerson?.colorHex ?? CurrentUser.defaultColorHex)
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

    // MARK: - Toolbar Content

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
                showingSubscriptionDetail = true
            } label: {
                subscriptionHeaderContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View \(subscription.name ?? "subscription") details")
        }
    }

    @ViewBuilder
    private var subscriptionHeaderContent: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color(hex: subscription.colorHex ?? "#007AFF"))
                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                .overlay(
                    Image(systemName: subscription.iconName ?? "person.2.circle.fill")
                        .font(.system(size: IconSize.sm, weight: .semibold))
                        .foregroundColor(AppColors.onAccent)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(subscription.name ?? "Subscription")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text("\(memberCount + 1) members")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
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

            Image(systemName: "person.2.fill")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                .accessibilityHidden(true)

            Text("No activity yet")
                .font(AppTypography.headingMedium())
                .foregroundColor(AppColors.textSecondary)

            Text("Record a payment or send a message to start tracking \(subscription.displayName)")
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
    private func conversationItemView(for item: SubscriptionConversationItem) -> some View {
        switch item {
        case .payment(let payment):
            SubscriptionPaymentCardView(payment: payment, subscription: subscription)

        case .settlement(let settlement):
            SubscriptionSettlementMessageView(settlement: settlement)

        case .reminder(let reminder):
            SubscriptionReminderMessageView(reminder: reminder)
                .onAppear {
                    markReminderAsRead(reminder)
                }

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

    private func markReminderAsRead(_ reminder: SubscriptionReminder) {
        guard !reminder.isRead else { return }
        reminder.isRead = true
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            AppLogger.subscriptions.error("Failed to mark reminder as read: \(error.localizedDescription)")
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastGroup = groupedItems.last,
           let lastItem = lastGroup.items.last {
            proxy.scrollTo(lastItem.id, anchor: .bottom)
        }
    }

    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        guard subscription.managedObjectContext != nil,
              !subscription.isDeleted,
              !subscription.isFault else {
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
        newMessage.withSubscription = subscription

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

    // MARK: - Message Delete with Undo

    private func deleteMessageWithUndo(_ message: ChatMessage) {
        deletedMessageContent = message.content
        deletedMessageTimestamp = message.timestamp
        deletedMessageIsEdited = message.isEdited

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
        restored.withSubscription = subscription

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
}
