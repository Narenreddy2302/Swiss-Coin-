//
//  SharedSubscriptionConversationView.swift
//  Swiss Coin
//
//  iMessage-style conversation view for shared subscriptions.
//  Matches GroupConversationView pattern exactly.
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

    private var balance: Double {
        subscription.calculateUserBalance()
    }

    private var groupedItems: [SubscriptionConversationDateGroup] {
        subscription.getGroupedConversationItems()
    }

    // Balance display properties
    private var balanceLabel: String {
        if balance > 0.01 { return "You're owed" }
        else if balance < -0.01 { return "You owe" }
        else { return "Balance" }
    }

    private var balanceAmount: String {
        if abs(balance) < 0.01 { return "Settled" }
        return CurrencyFormatter.formatAbsolute(balance)
    }

    private var balanceColor: Color {
        if balance > 0.01 { return AppColors.positive }
        else if balance < -0.01 { return AppColors.negative }
        else { return AppColors.neutral }
    }

    private var memberCount: Int {
        subscription.memberCount
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Subscription Info Header Card
                        SubscriptionInfoCard(subscription: subscription)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.lg)

                        // Member Balances Card
                        MemberBalancesCard(subscription: subscription)
                            .padding(.horizontal, Spacing.lg)

                        if groupedItems.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(groupedItems) { group in
                                DateHeaderView(dateString: group.dateDisplayString)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)

                                ForEach(group.items) { item in
                                    conversationItemView(for: item)
                                        .id(item.id)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
                .background(AppColors.background)
                .onTapGesture {
                    hideKeyboard()
                }
                .onAppear {
                    HapticManager.prepare()
                    scrollToBottom(proxy)
                }
                .onChange(of: groupedItems.count) { _, _ in
                    withAnimation {
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
        .sheet(isPresented: $showingRecordPayment) {
            RecordSubscriptionPaymentView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingSettlement) {
            SubscriptionSettlementView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingReminder) {
            SubscriptionReminderSheetView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingSubscriptionDetail) {
            NavigationStack {
                SubscriptionDetailView(subscription: subscription)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSubscriptionDetail = false
                            }
                        }
                    }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Toolbar Content

    @ViewBuilder
    private var toolbarLeadingContent: some View {
        HStack(spacing: Spacing.sm) {
            // Custom back button
            Button {
                HapticManager.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }

            // Subscription Icon + Name (tappable for details)
            Button {
                HapticManager.tap()
                showingSubscriptionDetail = true
            } label: {
                subscriptionHeaderContent
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var subscriptionHeaderContent: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: subscription.colorHex ?? "#007AFF"))
                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                .overlay(
                    Image(systemName: subscription.iconName ?? "person.2.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(subscription.name ?? "Subscription")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text("\(memberCount + 1) members")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var toolbarTrailingContent: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(balanceLabel)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AppColors.textSecondary)

            Text(balanceAmount)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(balanceColor)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No activity yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Record a payment or send a message to start tracking \(subscription.displayName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

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
                .padding(.vertical, 4)

        case .settlement(let settlement):
            SubscriptionSettlementMessageView(settlement: settlement)
                .padding(.vertical, 4)

        case .reminder(let reminder):
            SubscriptionReminderMessageView(reminder: reminder)
                .padding(.vertical, 4)
                .onAppear {
                    markReminderAsRead(reminder)
                }

        case .message(let chatMessage):
            MessageBubbleView(message: chatMessage)
                .padding(.vertical, 2)
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

        // Verify the subscription object is still valid
        guard !subscription.isDeleted && subscription.managedObjectContext != nil else {
            errorMessage = "Unable to send message. Please try again."
            showingError = true
            return
        }

        // Create new chat message
        let newMessage = ChatMessage(context: viewContext)
        newMessage.id = UUID()
        newMessage.content = trimmedText
        newMessage.timestamp = Date()
        newMessage.isFromUser = true
        newMessage.withSubscription = subscription

        // Save context with proper error handling
        do {
            try viewContext.save()

            // Clear input and provide haptic feedback
            messageText = ""
            HapticManager.lightTap()
        } catch {
            // Rollback the failed save
            viewContext.rollback()

            // Show error to user
            errorMessage = "Failed to send message. Please try again."
            showingError = true
            AppLogger.coreData.error("Failed to save message: \(error.localizedDescription)")
        }
    }
}
