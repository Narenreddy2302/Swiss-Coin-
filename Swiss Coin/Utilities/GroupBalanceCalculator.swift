//
//  GroupBalanceCalculator.swift
//  Swiss Coin
//
//  Balance calculation and conversation item retrieval for groups.
//

import Foundation

extension UserGroup {

    /// Calculate net balance for the current user in this group based on group transactions only.
    /// Positive = members owe you, Negative = you owe members.
    /// Uses net-position algorithm to support multi-payer transactions.
    /// Returns per-currency breakdown.
    func calculateBalance() -> CurrencyBalance {
        var balance = CurrencyBalance()

        guard let currentUserId = CurrentUser.currentUserId else { return balance }

        let groupTransactions = transactions as? Set<FinancialTransaction> ?? []
        let membersSet = members as? Set<Person> ?? []

        for transaction in groupTransactions {
            let currency = transaction.effectiveCurrency
            // Sum pairwise balance with each other member
            for member in membersSet {
                guard let memberId = member.id, !CurrentUser.isCurrentUser(memberId) else { continue }
                balance.add(transaction.pairwiseBalance(personA: currentUserId, personB: memberId), currency: currency)
            }
        }

        return balance
    }

    /// Calculate balance between current user and a specific group member based on group transactions only.
    /// Positive = they owe you, Negative = you owe them.
    /// Uses net-position algorithm to support multi-payer transactions.
    /// Returns per-currency breakdown.
    func calculateBalanceWith(member: Person) -> CurrencyBalance {
        guard let currentUserId = CurrentUser.currentUserId,
              let memberId = member.id,
              !CurrentUser.isCurrentUser(memberId) else { return CurrencyBalance() }

        var balance = CurrencyBalance()

        let groupTransactions = transactions as? Set<FinancialTransaction> ?? []

        for transaction in groupTransactions {
            let currency = transaction.effectiveCurrency
            balance.add(transaction.pairwiseBalance(personA: currentUserId, personB: memberId), currency: currency)
        }

        return balance
    }

    /// Get all member balances for this group (excluding current user)
    func getMemberBalances() -> [(member: Person, balance: CurrencyBalance)] {
        let membersSet = members as? Set<Person> ?? []

        return membersSet
            .filter { !CurrentUser.isCurrentUser($0.id) }
            .map { (member: $0, balance: calculateBalanceWith(member: $0)) }
            .sorted { $0.member.name ?? "" < $1.member.name ?? "" }
    }

    /// Get members who owe the current user (any currency with positive balance)
    func getMembersWhoOweYou() -> [(member: Person, balance: CurrencyBalance)] {
        return getMemberBalances()
            .filter { $0.balance.hasPositive }
    }

    /// Get members the current user owes (any currency with negative balance)
    func getMembersYouOwe() -> [(member: Person, balance: CurrencyBalance)] {
        return getMemberBalances()
            .filter { $0.balance.hasNegative }
    }

    /// Get all conversation items for the group (transactions + messages) sorted by date
    func getConversationItems() -> [GroupConversationItem] {
        var items: [GroupConversationItem] = []

        // Add group transactions
        let groupTransactions = transactions as? Set<FinancialTransaction> ?? []
        items.append(contentsOf: groupTransactions.map { GroupConversationItem.transaction($0) })

        // Add group chat messages
        let messages = chatMessages as? Set<ChatMessage> ?? []
        items.append(contentsOf: messages.map { GroupConversationItem.message($0) })

        // Add settlements between current user and group members
        let membersSet = members as? Set<Person> ?? []
        for member in membersSet {
            guard !CurrentUser.isCurrentUser(member.id) else { continue }

            // Settlements where member paid current user
            let memberSentToUser = (member.sentSettlements as? Set<Settlement> ?? [])
                .filter { CurrentUser.isCurrentUser($0.toPerson?.id) }
            items.append(contentsOf: memberSentToUser.map { GroupConversationItem.settlement($0) })

            // Settlements where current user paid member
            let userSentToMember = (member.receivedSettlements as? Set<Settlement> ?? [])
                .filter { CurrentUser.isCurrentUser($0.fromPerson?.id) }
            items.append(contentsOf: userSentToMember.map { GroupConversationItem.settlement($0) })

            // Reminders sent to this member
            let reminders = member.receivedReminders as? Set<Reminder> ?? []
            items.append(contentsOf: reminders.map { GroupConversationItem.reminder($0) })
        }

        // Sort by date ascending (oldest first, like iMessage)
        return items.sorted { $0.date < $1.date }
    }

    /// Group conversation items by date for display
    func getGroupedConversationItems() -> [GroupConversationDateGroup] {
        let items = getConversationItems()
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.date)
        }

        return grouped.map { date, groupItems in
            GroupConversationDateGroup(date: date, items: groupItems.sorted { $0.date < $1.date })
        }.sorted { $0.date < $1.date }
    }

    /// Helper to get display name
    var displayName: String {
        name ?? "Unknown Group"
    }

    /// Helper to get initials for the group
    var initials: String {
        guard let name = name, !name.isEmpty else { return "GR" }
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}

// MARK: - Group Conversation Item Types

enum GroupConversationItem: Identifiable {
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

    /// True for settlements and reminders — rendered as full-width notification strips
    var isSystemStrip: Bool {
        switch self {
        case .settlement, .reminder: return true
        default: return false
        }
    }
}

struct GroupConversationDateGroup: Identifiable {
    let date: Date
    let items: [GroupConversationItem]

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
