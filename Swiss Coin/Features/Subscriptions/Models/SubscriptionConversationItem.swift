//
//  SubscriptionConversationItem.swift
//  Swiss Coin
//
//  Types for subscription conversation items, matching the pattern from BalanceCalculator.
//

import Foundation

// MARK: - Subscription Conversation Item

enum SubscriptionConversationItem: Identifiable {
    case payment(SubscriptionPayment)
    case settlement(SubscriptionSettlement)
    case reminder(SubscriptionReminder)
    case message(ChatMessage)

    var id: UUID {
        switch self {
        case .payment(let p): return p.id ?? UUID()
        case .settlement(let s): return s.id ?? UUID()
        case .reminder(let r): return r.id ?? UUID()
        case .message(let m): return m.id ?? UUID()
        }
    }

    var date: Date {
        switch self {
        case .payment(let p): return p.date ?? Date.distantPast
        case .settlement(let s): return s.date ?? Date.distantPast
        case .reminder(let r): return r.createdDate ?? Date.distantPast
        case .message(let m): return m.timestamp ?? Date.distantPast
        }
    }
}

// MARK: - Subscription Conversation Date Group

struct SubscriptionConversationDateGroup: Identifiable {
    let date: Date
    let items: [SubscriptionConversationItem]

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
