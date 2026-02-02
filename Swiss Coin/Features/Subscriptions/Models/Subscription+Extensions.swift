//
//  Subscription+Extensions.swift
//  Swiss Coin
//
//  Extension providing computed properties and business logic for Subscription entity.
//

import Foundation
import SwiftUI

// MARK: - Billing Status

enum BillingStatus {
    case upcoming    // More than 7 days away
    case due         // Within 7 days
    case overdue     // Past billing date
    case paused      // Subscription paused

    var color: Color {
        switch self {
        case .upcoming: return AppColors.neutral
        case .due: return AppColors.warning
        case .overdue: return AppColors.negative
        case .paused: return AppColors.disabled
        }
    }

    var icon: String {
        switch self {
        case .upcoming: return "calendar"
        case .due: return "exclamationmark.circle"
        case .overdue: return "exclamationmark.triangle.fill"
        case .paused: return "pause.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .due: return "Due Soon"
        case .overdue: return "Overdue"
        case .paused: return "Paused"
        }
    }
}

// MARK: - Subscription Extension

extension Subscription {

    // MARK: - Display Properties

    var displayName: String {
        name ?? "Unknown Subscription"
    }

    var initials: String {
        guard let name = name, !name.isEmpty else { return "SB" }
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }

    var cycleAbbreviation: String {
        switch cycle {
        case "Weekly": return "wk"
        case "Monthly": return "mo"
        case "Yearly": return "yr"
        case "Custom": return "\(customCycleDays)d"
        default: return "mo"
        }
    }

    // MARK: - Billing Status

    var daysUntilNextBilling: Int {
        guard let nextDate = nextBillingDate else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: nextDate)
        return components.day ?? 0
    }

    var billingStatus: BillingStatus {
        if !isActive {
            return .paused
        }

        let days = daysUntilNextBilling

        if days < 0 {
            return .overdue
        } else if days <= 7 {
            return .due
        } else {
            return .upcoming
        }
    }

    // MARK: - Cost Calculations

    var monthlyEquivalent: Double {
        switch cycle {
        case "Weekly":
            return amount * 4.33 // Average weeks per month
        case "Monthly":
            return amount
        case "Yearly":
            return amount / 12.0
        case "Custom":
            let daysPerMonth = 30.44
            let days = max(1, customCycleDays) // Prevent division by zero
            return amount * (daysPerMonth / Double(days))
        default:
            return amount
        }
    }

    var yearlyEquivalent: Double {
        return monthlyEquivalent * 12.0
    }

    // MARK: - Shared Subscription Properties

    /// Total number of people sharing this subscription (including current user).
    /// The `subscribers` relationship should include ALL participants (current user + others).
    var subscriberCount: Int {
        let count = subscribers?.count ?? 0
        return isShared ? max(count, 1) : 1
    }

    /// Number of other members (excluding current user) for display purposes
    var memberCount: Int {
        let allMembers = subscribers as? Set<Person> ?? []
        return allMembers.filter { !CurrentUser.isCurrentUser($0.id) }.count
    }

    var myShare: Double {
        guard isShared && subscriberCount > 0 else { return amount }
        return amount / Double(subscriberCount)
    }

    // MARK: - Balance Calculations for Shared Subscriptions

    /// Calculate current user's balance for this shared subscription
    /// Positive = members owe you, Negative = you owe members
    func calculateUserBalance() -> Double {
        guard isShared, isActive else { return 0 }

        var balance: Double = 0
        let paymentsSet = payments as? Set<SubscriptionPayment> ?? []
        let subscriberCount = self.subscriberCount

        guard subscriberCount > 0 else { return 0 }

        for payment in paymentsSet {
            let payerId = payment.payer?.id
            let amountPerMember = payment.amount / Double(subscriberCount)

            if CurrentUser.isCurrentUser(payerId) {
                // You paid - others owe you their share
                balance += payment.amount - amountPerMember // Exclude your own share
            } else {
                // Someone else paid - you owe your share
                balance -= amountPerMember
            }
        }

        // Apply settlements
        let settlementsSet = settlements as? Set<SubscriptionSettlement> ?? []
        for settlement in settlementsSet {
            let fromPersonId = settlement.fromPerson?.id
            let toPersonId = settlement.toPerson?.id

            if CurrentUser.isCurrentUser(toPersonId) {
                // Someone paid you
                balance -= settlement.amount
            } else if CurrentUser.isCurrentUser(fromPersonId) {
                // You paid someone
                balance += settlement.amount
            }
        }

        return balance
    }

    /// Calculate share for a specific member
    func calculateMemberShare(for person: Person) -> Double {
        guard isShared, isActive, subscriberCount > 0 else { return 0 }
        return amount / Double(subscriberCount)
    }

    /// Calculate balance with a specific member
    /// Positive = they owe you, Negative = you owe them
    func calculateBalanceWith(member: Person) -> Double {
        guard isShared, isActive else { return 0 }
        guard !CurrentUser.isCurrentUser(member.id) else { return 0 }

        var balance: Double = 0
        let paymentsSet = payments as? Set<SubscriptionPayment> ?? []
        let subscriberCount = self.subscriberCount

        guard subscriberCount > 0 else { return 0 }

        for payment in paymentsSet {
            let payerId = payment.payer?.id
            let amountPerMember = payment.amount / Double(subscriberCount)

            if CurrentUser.isCurrentUser(payerId) {
                // You paid - this member owes you their share
                balance += amountPerMember
            } else if payerId == member.id {
                // They paid - you owe your share
                balance -= amountPerMember
            }
        }

        // Apply settlements between current user and this member
        let settlementsSet = settlements as? Set<SubscriptionSettlement> ?? []
        for settlement in settlementsSet {
            let fromPersonId = settlement.fromPerson?.id
            let toPersonId = settlement.toPerson?.id

            // Member paid you
            if fromPersonId == member.id && CurrentUser.isCurrentUser(toPersonId) {
                balance -= settlement.amount
            }
            // You paid member
            else if CurrentUser.isCurrentUser(fromPersonId) && toPersonId == member.id {
                balance += settlement.amount
            }
        }

        return balance
    }

    /// Get all member balances for this subscription
    func getMemberBalances() -> [(member: Person, balance: Double, paid: Double)] {
        guard isShared, isActive else { return [] }

        let membersSet = subscribers as? Set<Person> ?? []
        let paymentsSet = payments as? Set<SubscriptionPayment> ?? []

        return membersSet
            .filter { !CurrentUser.isCurrentUser($0.id) }
            .map { member in
                let balance = calculateBalanceWith(member: member)
                let paid = paymentsSet
                    .filter { $0.payer?.id == member.id }
                    .reduce(0) { $0 + $1.amount }
                return (member: member, balance: balance, paid: paid)
            }
            .sorted { ($0.member.name ?? "") < ($1.member.name ?? "") }
    }

    /// Get members who owe the current user
    func getMembersWhoOweYou() -> [(member: Person, amount: Double)] {
        return getMemberBalances()
            .filter { $0.balance > 0.01 }
            .map { (member: $0.member, amount: $0.balance) }
    }

    /// Get members the current user owes
    func getMembersYouOwe() -> [(member: Person, amount: Double)] {
        return getMemberBalances()
            .filter { $0.balance < -0.01 }
            .map { (member: $0.member, amount: abs($0.balance)) }
    }

    // MARK: - Payment History

    var recentPayments: [SubscriptionPayment] {
        let paymentsSet = payments as? Set<SubscriptionPayment> ?? []
        return paymentsSet
            .sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
    }

    // MARK: - Conversation Items

    func getConversationItems() -> [SubscriptionConversationItem] {
        var items: [SubscriptionConversationItem] = []

        // Add payments
        let paymentsSet = payments as? Set<SubscriptionPayment> ?? []
        items.append(contentsOf: paymentsSet.map { SubscriptionConversationItem.payment($0) })

        // Add settlements
        let settlementsSet = settlements as? Set<SubscriptionSettlement> ?? []
        items.append(contentsOf: settlementsSet.map { SubscriptionConversationItem.settlement($0) })

        // Add reminders
        let remindersSet = reminders as? Set<SubscriptionReminder> ?? []
        items.append(contentsOf: remindersSet.map { SubscriptionConversationItem.reminder($0) })

        // Add chat messages
        let messagesSet = chatMessages as? Set<ChatMessage> ?? []
        items.append(contentsOf: messagesSet.map { SubscriptionConversationItem.message($0) })

        // Sort by date ascending (oldest first, like iMessage)
        return items.sorted { $0.date < $1.date }
    }

    func getGroupedConversationItems() -> [SubscriptionConversationDateGroup] {
        let items = getConversationItems()
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.date)
        }

        return grouped.map { date, groupItems in
            SubscriptionConversationDateGroup(date: date, items: groupItems.sorted { $0.date < $1.date })
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Billing Date Calculations

    func calculateNextBillingDate(from date: Date = Date()) -> Date {
        let calendar = Calendar.current

        switch cycle {
        case "Weekly":
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case "Monthly":
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case "Yearly":
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case "Custom":
            return calendar.date(byAdding: .day, value: Int(customCycleDays), to: date) ?? date
        default:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }
}
