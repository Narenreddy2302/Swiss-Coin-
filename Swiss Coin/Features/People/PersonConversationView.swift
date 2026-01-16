//
//  PersonConversationView.swift
//  Swiss Coin
//

import CoreData
import SwiftUI

struct PersonConversationView: View {
    @ObservedObject var person: Person
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var showingAddTransaction = false
    @State private var showingSettlement = false
    @State private var showingReminder = false
    @State private var showingPersonDetail = false
    @State private var messageText = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    // Retained haptic generator for reliable feedback
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    private var balance: Double {
        person.calculateBalance()
    }

    private var groupedItems: [ConversationDateGroup] {
        person.getGroupedConversationItems()
    }

    // Balance display properties (for navigation bar)
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

    var body: some View {
        VStack(spacing: 0) {
            // Messages Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
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
                .background(Color.black)
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
        .background(Color.black)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar) // Hide tab bar like iMessage
        .tint(Color(UIColor.systemGray))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Leading: Back button + Avatar + Name
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: Spacing.sm) {
                    // Custom back button (chevron only)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(UIColor.systemGray))
                    }

                    // Avatar + Name (tappable for profile)
                    Button {
                        HapticManager.navigate()
                        showingPersonDetail = true
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Circle()
                                .fill(Color(UIColor.systemGray3))
                                .frame(width: AvatarSize.xs, height: AvatarSize.xs)
                                .overlay(
                                    Text(person.initials)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(UIColor.systemGray))
                                )

                            Text(person.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Trailing: Balance info
            ToolbarItem(placement: .topBarTrailing) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(balanceLabel)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(UIColor.systemGray))

                    Text(balanceAmount)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(balanceColor)
                }
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
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "message.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No conversations yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Start a conversation with \(person.firstName) or add an expense")
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
    private func conversationItemView(for item: ConversationItem) -> some View {
        switch item {
        case .transaction(let transaction):
            TransactionCardView(
                transaction: transaction,
                person: person
            )
            .padding(.vertical, 4)

        case .settlement(let settlement):
            SettlementMessageView(settlement: settlement, person: person)
                .padding(.vertical, 4)

        case .reminder(let reminder):
            ReminderMessageView(reminder: reminder, person: person)
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

        // Verify the person object is still valid
        guard !person.isDeleted && person.managedObjectContext != nil else {
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
        newMessage.withPerson = person

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
