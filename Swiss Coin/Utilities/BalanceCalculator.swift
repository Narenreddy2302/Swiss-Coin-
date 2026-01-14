//
//  BalanceCalculator.swift
//  Swiss Coin
//

import Foundation

extension Person {

    /// The UUID for the current user ("You")
    static let currentUserUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Calculate net balance with this person (mutual transactions only)
    /// Positive = they owe you, Negative = you owe them
    func calculateBalance() -> Double {
        var balance: Double = 0

        // Get all mutual transactions (where both you and this person are involved)
        let allTransactions = getMutualTransactions()

        for transaction in allTransactions {
            let splits = transaction.splits as? Set<TransactionSplit> ?? []
            let payerId = transaction.payer?.id

            if payerId == Person.currentUserUUID {
                // YOU paid - they owe you their share
                if let theirSplit = splits.first(where: { $0.owedBy?.id == self.id }) {
                    balance += theirSplit.amount
                }
            } else if payerId == self.id {
                // THEY paid - you owe your share
                if let mySplit = splits.first(where: { $0.owedBy?.id == Person.currentUserUUID }) {
                    balance -= mySplit.amount
                }
            }
        }

        // Settlements where this person paid (fromPerson = self)
        // Their payment reduces their debt to you (balance decreases)
        let sent = sentSettlements as? Set<Settlement> ?? []
        for settlement in sent {
            balance -= settlement.amount
        }

        // Settlements where this person received payment (toPerson = self)
        // Your payment to them reduces your debt (balance increases toward zero)
        let received = receivedSettlements as? Set<Settlement> ?? []
        for settlement in received {
            balance += settlement.amount
        }

        return balance
    }

    /// Get transactions involving both you and this person
    func getMutualTransactions() -> [FinancialTransaction] {
        // Transactions where this person paid
        let paidByThem = toTransactions as? Set<FinancialTransaction> ?? []

        // Transactions where this person has a split (owes money)
        let theirSplits = owedSplits as? Set<TransactionSplit> ?? []
        let owedByThem = Set(theirSplits.compactMap { $0.transaction })

        let allTheirTransactions = paidByThem.union(owedByThem)

        // Filter to only mutual: where you are also involved
        return allTheirTransactions.filter { transaction in
            let splits = transaction.splits as? Set<TransactionSplit> ?? []
            let youArePayer = transaction.payer?.id == Person.currentUserUUID
            let youHaveSplit = splits.contains { $0.owedBy?.id == Person.currentUserUUID }
            return youArePayer || youHaveSplit
        }.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }

    /// Get all conversation items (transactions, settlements, reminders) sorted by date
    func getConversationItems() -> [ConversationItem] {
        var items: [ConversationItem] = []

        // Add mutual transactions
        let transactions = getMutualTransactions()
        items.append(contentsOf: transactions.map { ConversationItem.transaction($0) })

        // Add settlements (both sent and received with this person)
        let sent = sentSettlements as? Set<Settlement> ?? []
        let received = receivedSettlements as? Set<Settlement> ?? []
        items.append(contentsOf: sent.map { ConversationItem.settlement($0) })
        items.append(contentsOf: received.map { ConversationItem.settlement($0) })

        // Add reminders sent to this person
        let reminders = receivedReminders as? Set<Reminder> ?? []
        items.append(contentsOf: reminders.map { ConversationItem.reminder($0) })

        // Sort by date ascending (oldest first, like iMessage)
        return items.sorted { $0.date < $1.date }
    }

    /// Group conversation items by date for display
    func getGroupedConversationItems() -> [ConversationDateGroup] {
        let items = getConversationItems()
        let calendar = Calendar.current

        var groups: [Date: [ConversationItem]] = [:]

        for item in items {
            let startOfDay = calendar.startOfDay(for: item.date)
            if groups[startOfDay] == nil {
                groups[startOfDay] = []
            }
            groups[startOfDay]?.append(item)
        }

        return groups.map { date, items in
            ConversationDateGroup(date: date, items: items.sorted { $0.date < $1.date })
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - Conversation Item Types

enum ConversationItem: Identifiable {
    case transaction(FinancialTransaction)
    case settlement(Settlement)
    case reminder(Reminder)

    var id: UUID {
        switch self {
        case .transaction(let t): return t.id ?? UUID()
        case .settlement(let s): return s.id ?? UUID()
        case .reminder(let r): return r.id ?? UUID()
        }
    }

    var date: Date {
        switch self {
        case .transaction(let t): return t.date ?? Date()
        case .settlement(let s): return s.date ?? Date()
        case .reminder(let r): return r.createdDate ?? Date()
        }
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
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}
