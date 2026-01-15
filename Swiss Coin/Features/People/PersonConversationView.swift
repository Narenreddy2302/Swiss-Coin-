//
//  PersonConversationView.swift
//  Swiss Coin
//

import CoreData
import SwiftUI

struct PersonConversationView: View {
    @ObservedObject var person: Person
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingAddTransaction = false
    @State private var showingSettlement = false
    @State private var showingReminder = false
    @State private var showingPersonDetail = false
    @State private var messageText = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    private var balance: Double {
        person.calculateBalance()
    }

    private var groupedItems: [ConversationDateGroup] {
        person.getGroupedConversationItems()
    }

    private var balanceLabel: String {
        if balance > 0.01 {
            return "owes you"
        } else if balance < -0.01 {
            return "you owe"
        } else {
            return "settled"
        }
    }

    private var balanceColor: Color {
        if balance > 0.01 {
            return AppColors.positive
        } else if balance < -0.01 {
            return AppColors.negative
        } else {
            return AppColors.neutral
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Divider below navigation bar
            Divider()
                .background(Color(UIColor.systemGray4))

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
                                }
                            }
                        }
                    }
                    .padding(.vertical, Spacing.lg)
                }
                .background(AppColors.background)
                .onAppear {
                    HapticManager.prepare()
                    scrollToBottom(proxy)
                }
                .onChange(of: groupedItems.count) { _, _ in
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            // Center: Avatar + Name (tappable)
            ToolbarItem(placement: .principal) {
                Button {
                    HapticManager.navigate()
                    showingPersonDetail = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        // Avatar
                        Circle()
                            .fill(Color(UIColor.systemGray3))
                            .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                            .overlay(
                                Text(person.initials)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                            )

                        // Name
                        Text(person.displayName)
                            .font(AppTypography.bodyBold())
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                .buttonStyle(.plain)
            }

            // Trailing: Balance info
            ToolbarItem(placement: .topBarTrailing) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(balanceLabel)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)

                    Text(CurrencyFormatter.formatAbsolute(balance))
                        .font(AppTypography.amount())
                        .foregroundColor(balanceColor)
                }
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(initialParticipant: person)
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
                                HapticManager.tap()
                                showingPersonDetail = false
                            }
                        }
                    }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                HapticManager.tap()
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "message.fill")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))

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
                person: person
            )
            .padding(.vertical, Spacing.xxs)

        case .settlement(let settlement):
            SettlementMessageView(settlement: settlement, person: person)
                .padding(.vertical, Spacing.xxs)

        case .reminder(let reminder):
            ReminderMessageView(reminder: reminder, person: person)
                .padding(.vertical, Spacing.xxs)

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

        guard !person.isDeleted && person.managedObjectContext != nil else {
            HapticManager.error()
            errorMessage = "Unable to send message. Please try again."
            showingError = true
            return
        }

        let newMessage = ChatMessage(context: viewContext)
        newMessage.id = UUID()
        newMessage.content = trimmedText
        newMessage.timestamp = Date()
        newMessage.isFromUser = true
        newMessage.withPerson = person

        do {
            try viewContext.save()
            messageText = ""
            HapticManager.sendMessage()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to send message. Please try again."
            showingError = true
        }
    }
}
