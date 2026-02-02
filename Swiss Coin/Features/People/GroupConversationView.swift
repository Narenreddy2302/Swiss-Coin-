//
//  GroupConversationView.swift
//  Swiss Coin
//
//  iMessage-style conversation view for groups.
//

import CoreData
import SwiftUI

struct GroupConversationView: View {
    @ObservedObject var group: UserGroup
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var showingAddTransaction = false
    @State private var showingSettlement = false
    @State private var showingReminder = false
    @State private var showingGroupDetail = false
    @State private var messageText = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    // Retained haptic generator for reliable feedback
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    private var balance: Double {
        group.calculateBalance()
    }

    private var groupedItems: [GroupConversationDateGroup] {
        group.getGroupedConversationItems()
    }

    // Balance display properties (for navigation bar)
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
        group.members?.count ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if groupedItems.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(groupedItems) { dateGroup in
                                DateHeaderView(dateString: dateGroup.dateDisplayString)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)

                                ForEach(dateGroup.items) { item in
                                    conversationItemView(for: item)
                                        .id(item.id)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
                .background(AppColors.background)
                .onAppear {
                    hapticGenerator.prepare()
                    scrollToBottom(proxy)
                }
                .onChange(of: groupedItems.count) { _, _ in
                    withAnimation {
                        scrollToBottom(proxy)
                    }
                }
            }

            // Action Bar
            GroupConversationActionBar(
                balance: balance,
                membersWhoOweYou: group.getMembersWhoOweYou(),
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
        .toolbarBackground(AppColors.backgroundSecondary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar) // Hide tab bar like iMessage
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
            QuickActionSheetPresenter(initialGroup: group)
        }
        .sheet(isPresented: $showingSettlement) {
            GroupSettlementView(group: group)
        }
        .sheet(isPresented: $showingReminder) {
            GroupReminderSheetView(group: group)
        }
        .sheet(isPresented: $showingGroupDetail) {
            NavigationStack {
                GroupDetailView(group: group)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingGroupDetail = false
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
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.accent)
            }

            // Group Icon + Name (tappable for group detail)
            Button {
                HapticManager.tap()
                showingGroupDetail = true
            } label: {
                groupHeaderContent
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var groupHeaderContent: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color(hex: group.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(.system(size: IconSize.sm, weight: .semibold))
                        .foregroundColor(Color(hex: group.colorHex ?? CurrentUser.defaultColorHex))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(group.name ?? "Unknown Group")
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text("\(memberCount) members")
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
                .font(AppTypography.amountSmall())
                .foregroundColor(balanceColor)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.3.fill")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))

            Text("No activity yet")
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textSecondary)

            Text("Start a conversation with \(group.name ?? "the group") or add a group expense")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Conversation Item View

    @ViewBuilder
    private func conversationItemView(for item: GroupConversationItem) -> some View {
        switch item {
        case .transaction(let transaction):
            GroupTransactionCardView(
                transaction: transaction,
                group: group
            )
            .padding(.vertical, 4)

        case .settlement(let settlement):
            GroupSettlementMessageView(settlement: settlement)
                .padding(.vertical, 4)

        case .reminder(let reminder):
            GroupReminderMessageView(reminder: reminder)
                .padding(.vertical, 4)

        case .message(let chatMessage):
            MessageBubbleView(message: chatMessage)
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

        // Verify the group object is still valid
        guard !group.isDeleted && group.managedObjectContext != nil else {
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
        newMessage.withGroup = group

        // Save context with proper error handling
        do {
            try viewContext.save()

            // Clear input and provide haptic feedback
            messageText = ""
            hapticGenerator.impactOccurred()
        } catch {
            // Rollback the failed save
            viewContext.rollback()

            // Show error to user
            errorMessage = "Failed to send message. Please try again."
            showingError = true
            print("Error saving message: \(error)")
        }
    }
}

// MARK: - Group Conversation Action Bar

struct GroupConversationActionBar: View {
    let balance: Double
    let membersWhoOweYou: [(member: Person, amount: Double)]
    let onAdd: () -> Void
    let onSettle: () -> Void
    let onRemind: () -> Void

    private var canSettle: Bool {
        abs(balance) > 0.01
    }

    private var canRemind: Bool {
        !membersWhoOweYou.isEmpty
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Add Transaction Button (Primary - Green Accent)
            GroupActionButton(
                title: "Add",
                icon: "plus",
                isPrimary: true,
                isEnabled: true,
                action: onAdd
            )

            // Remind Button
            GroupActionButton(
                title: "Remind",
                icon: "bell.fill",
                isPrimary: false,
                isEnabled: canRemind,
                action: {
                    if canRemind {
                        onRemind()
                    }
                }
            )

            // Settle Button
            GroupActionButton(
                title: "Settle",
                icon: "checkmark",
                isPrimary: false,
                isEnabled: canSettle,
                action: {
                    if canSettle {
                        onSettle()
                    }
                }
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.background)
        .onAppear {
            HapticManager.prepare()
        }
    }
}

// MARK: - Group Action Button

private struct GroupActionButton: View {
    let title: String
    let icon: String
    let isPrimary: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if isEnabled || isPrimary {
                HapticManager.tap()
                action()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                if isPrimary {
                    // Green circle with plus icon for Add button
                    ZStack {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: IconSize.lg, height: IconSize.lg)

                        Image(systemName: icon)
                            .font(.system(size: IconSize.xs, weight: .bold))
                            .foregroundColor(.black)
                    }
                } else {
                    Image(systemName: icon)
                        .font(.system(size: IconSize.sm, weight: .medium))
                        .foregroundColor(isEnabled ? AppColors.textSecondary : AppColors.disabled)
                }

                Text(title)
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(isPrimary ? AppColors.accent : (isEnabled ? AppColors.textSecondary : AppColors.disabled))
            }
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color(UIColor.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .strokeBorder(Color(UIColor.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(AppButtonStyle(haptic: .none))
        .disabled(!isEnabled && !isPrimary)
    }
}

// MARK: - Group Settlement Message View

struct GroupSettlementMessageView: View {
    let settlement: Settlement

    private var messageText: String {
        let formatted = CurrencyFormatter.format(settlement.amount)
        let fromPersonId = settlement.fromPerson?.id
        let toPersonId = settlement.toPerson?.id

        if CurrentUser.isCurrentUser(fromPersonId) {
            // Current user paid someone
            let toName = settlement.toPerson?.name?.components(separatedBy: " ").first ?? "someone"
            return "You paid \(toName) \(formatted)"
        } else if CurrentUser.isCurrentUser(toPersonId) {
            // Someone paid current user
            let fromName = settlement.fromPerson?.name?.components(separatedBy: " ").first ?? "Someone"
            return "\(fromName) paid you \(formatted)"
        } else {
            // Neither party is current user
            let fromName = settlement.fromPerson?.name?.components(separatedBy: " ").first ?? "Someone"
            let toName = settlement.toPerson?.name?.components(separatedBy: " ").first ?? "someone"
            return "\(fromName) paid \(toName) \(formatted)"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)

                Text(messageText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(UIColor.systemGray5))
            )

            if let note = settlement.note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }

            Text(settlement.date ?? Date(), style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Group Reminder Message View

struct GroupReminderMessageView: View {
    let reminder: Reminder

    private var messageText: String {
        let formatted = CurrencyFormatter.format(reminder.amount)
        let personName = reminder.toPerson?.name?.components(separatedBy: " ").first ?? "Someone"
        return "Reminder sent to \(personName) for \(formatted)"
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)

                Text(messageText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.15))
            )

            if let message = reminder.message, !message.isEmpty {
                Text("\"\(message)\"")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }

            Text(reminder.createdDate ?? Date(), style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
