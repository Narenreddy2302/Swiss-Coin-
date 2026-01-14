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

    private var balance: Double {
        person.calculateBalance()
    }

    private var groupedItems: [ConversationDateGroup] {
        person.getGroupedConversationItems()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Balance Header
            BalanceHeaderView(
                person: person,
                balance: balance,
                onAvatarTap: {
                    showingPersonDetail = true
                }
            )

            // Messages Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if groupedItems.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(groupedItems) { group in
                                DateHeaderView(dateString: group.dateDisplayString)

                                ForEach(group.items) { item in
                                    conversationItemView(for: item)
                                        .id(item.id)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
                .background(Color(UIColor.systemBackground))
                .onAppear {
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.secondarySystemBackground))
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
                                showingPersonDetail = false
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "message.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No transactions yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Tap '+' to add your first transaction with \(person.firstName)")
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
            TransactionBubbleView(
                transaction: transaction,
                person: person,
                showTimestamp: shouldShowTimestamp(for: item)
            )
            .padding(.vertical, 4)

        case .settlement(let settlement):
            SettlementMessageView(settlement: settlement, person: person)

        case .reminder(let reminder):
            ReminderMessageView(reminder: reminder, person: person)
        }
    }

    // MARK: - Helpers

    private func shouldShowTimestamp(for item: ConversationItem) -> Bool {
        // Always show timestamp for now; could be optimized to collapse sequential messages
        return true
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastGroup = groupedItems.last,
           let lastItem = lastGroup.items.last {
            proxy.scrollTo(lastItem.id, anchor: .bottom)
        }
    }
}
