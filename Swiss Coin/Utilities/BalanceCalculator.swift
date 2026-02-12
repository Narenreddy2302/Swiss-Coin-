//
//  BalanceCalculator.swift
//  Swiss Coin
//

import Foundation

extension Person {

    /// Calculate net balance with this person (mutual transactions only)
    /// Positive = they owe you, Negative = you owe them
    /// Uses net-position algorithm to support multi-payer transactions.
    func calculateBalance() -> Double {
        var balance: Double = 0

        guard let currentUserId = CurrentUser.currentUserId,
              let theirId = self.id else { return 0 }

        // Get all mutual transactions (where both you and this person are involved)
        let allTransactions = getMutualTransactions()

        for transaction in allTransactions {
            balance += transaction.pairwiseBalance(personA: currentUserId, personB: theirId)
        }

        // Get settlements ONLY between current user and this person
        let sentToCurrentUser = (sentSettlements as? Set<Settlement> ?? [])
            .filter { CurrentUser.isCurrentUser($0.toPerson?.id) }

        let receivedFromCurrentUser = (receivedSettlements as? Set<Settlement> ?? [])
            .filter { CurrentUser.isCurrentUser($0.fromPerson?.id) }

        // Settlements where this person paid the current user (fromPerson = self, toPerson = currentUser)
        // Their payment reduces their debt to you (balance decreases)
        for settlement in sentToCurrentUser {
            balance -= settlement.amount
        }

        // Settlements where the current user paid this person (fromPerson = currentUser, toPerson = self)
        // Your payment reduces your debt to them (balance increases toward zero)
        for settlement in receivedFromCurrentUser {
            balance += settlement.amount
        }

        return balance
    }

    /// Get transactions involving both you and this person
    func getMutualTransactions() -> [FinancialTransaction] {
        // Cache the splits cast to avoid repeated conversions
        let theirSplits = owedSplits as? Set<TransactionSplit> ?? []
        let paidByThem = toTransactions as? Set<FinancialTransaction> ?? []
        let theirPayerSplits = payerSplits as? Set<TransactionPayer> ?? []

        // Transactions where this person has a split (owes money)
        let owedByThem = Set(theirSplits.compactMap { $0.transaction })

        // Transactions where this person is a multi-payer contributor
        let paidByThemMulti = Set(theirPayerSplits.compactMap { $0.transaction })

        let allTheirTransactions = paidByThem.union(owedByThem).union(paidByThemMulti)

        // Filter to only mutual: where you are also involved
        return allTheirTransactions.filter { transaction in
            let splits = transaction.splits as? Set<TransactionSplit> ?? []
            let youArePayer = CurrentUser.isCurrentUser(transaction.payer?.id)
            let youHaveSplit = splits.contains { CurrentUser.isCurrentUser($0.owedBy?.id) }
            let youAreMultiPayer = (transaction.payers as? Set<TransactionPayer> ?? [])
                .contains { CurrentUser.isCurrentUser($0.paidBy?.id) }
            return youArePayer || youHaveSplit || youAreMultiPayer
        }.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
    }

    /// Get all conversation items (transactions, settlements, reminders, messages) sorted by date
    func getConversationItems() -> [ConversationItem] {
        var items: [ConversationItem] = []

        // Add mutual transactions
        let transactions = getMutualTransactions()
        items.append(contentsOf: transactions.map { ConversationItem.transaction($0) })

        // Add settlements ONLY between current user and this person
        let sentToCurrentUser = (sentSettlements as? Set<Settlement> ?? [])
            .filter { CurrentUser.isCurrentUser($0.toPerson?.id) }
        let receivedFromCurrentUser = (receivedSettlements as? Set<Settlement> ?? [])
            .filter { CurrentUser.isCurrentUser($0.fromPerson?.id) }

        items.append(contentsOf: sentToCurrentUser.map { ConversationItem.settlement($0) })
        items.append(contentsOf: receivedFromCurrentUser.map { ConversationItem.settlement($0) })

        // Add reminders sent to this person
        let reminders = receivedReminders as? Set<Reminder> ?? []
        items.append(contentsOf: reminders.map { ConversationItem.reminder($0) })

        // Add chat messages with this person (exclude transaction comments)
        let messages = (chatMessages as? Set<ChatMessage> ?? [])
            .filter { $0.onTransaction == nil }
        items.append(contentsOf: messages.map { ConversationItem.message($0) })

        // Sort by date ascending (oldest first, like iMessage)
        return items.sorted { $0.date < $1.date }
    }

    /// Group conversation items by date for display
    func getGroupedConversationItems() -> [ConversationDateGroup] {
        let items = getConversationItems()
        let calendar = Calendar.current

        // Use Dictionary grouping for efficiency
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.date)
        }

        return grouped.map { date, groupItems in
            ConversationDateGroup(date: date, items: groupItems.sorted { $0.date < $1.date })
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - Conversation Item Types

enum ConversationItem: Identifiable {
    case transaction(FinancialTransaction)
    case settlement(Settlement)
    case reminder(Reminder)
    case message(ChatMessage)

    var id: UUID {
        switch self {
        case .transaction(let t): return t.id ?? UUID()
        case .settlement(let s): return s.id ?? UUID()
        case .reminder(let r): return r.id ?? UUID()
        case .message(let m): return m.id ?? UUID()
        }
    }

    var date: Date {
        switch self {
        case .transaction(let t): return t.date ?? Date.distantPast
        case .settlement(let s): return s.date ?? Date.distantPast
        case .reminder(let r): return r.createdDate ?? Date.distantPast
        case .message(let m): return m.timestamp ?? Date.distantPast
        }
    }

    var isMessageType: Bool {
        if case .message = self { return true }
        return false
    }
}

struct ConversationDateGroup: Identifiable {
    let date: Date
    let items: [ConversationItem]

    var id: Date { date }

    var dateDisplayString: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return DateFormatter.dayOfWeek.string(from: date)
        } else {
            return DateFormatter.mediumDate.string(from: date)
        }
    }
}
