//
//  Subscription+Extensions.swift
//  Swiss Coin
//
//  Extension providing computed properties and business logic for Subscription entity.
//

import CoreData
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
    /// Relationship: subscriberCount = memberCount + 1 (always includes current user)
    /// Returns at least 1 to prevent division by zero in share calculations.
    var subscriberCount: Int {
        guard isShared else { return 1 }
        let allMembers = subscribers as? Set<Person> ?? []
        // memberCount excludes current user, so add 1 for current user
        let otherMemberCount = allMembers.filter { !CurrentUser.isCurrentUser($0.id) }.count
        // Total = other members + current user, minimum of 1 to prevent division by zero
        return max(otherMemberCount + 1, 1)
    }

    /// Number of other members (excluding current user) for display purposes.
    /// Relationship: subscriberCount = memberCount + 1
    var memberCount: Int {
        guard isShared else { return 0 }
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

        // Capture subscriber count early and guard against division by zero
        let subscriberCount = self.subscriberCount
        guard subscriberCount > 0 else { return 0 }

        var balance: Double = 0
        let paymentsSet = payments as? Set<SubscriptionPayment> ?? []

        for payment in paymentsSet {
            // Skip payment if payer is nil - cannot determine balance contribution
            guard let payer = payment.payer else {
                #if DEBUG
                print("[Subscription+Extensions] Warning: Skipping payment with nil payer in calculateUserBalance()")
                #endif
                continue
            }

            let payerId = payer.id
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
            // Skip payment if payer is nil - cannot determine balance contribution
            guard let payer = payment.payer else {
                #if DEBUG
                print("[Subscription+Extensions] Warning: Skipping payment with nil payer in calculateBalanceWith()")
                #endif
                continue
            }

            let payerId = payer.id
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
    /// Optimized: computes all balances in a single pass through payments and settlements
    func getMemberBalances() -> [(member: Person, balance: Double, paid: Double)] {
        guard isShared, isActive else { return [] }

        let membersSet = subscribers as? Set<Person> ?? []
        let paymentsSet = payments as? Set<SubscriptionPayment> ?? []
        let settlementsSet = settlements as? Set<SubscriptionSettlement> ?? []
        let subscriberCount = self.subscriberCount

        guard subscriberCount > 0 else { return [] }

        // Filter to non-current-user members
        let otherMembers = membersSet.filter { !CurrentUser.isCurrentUser($0.id) }

        // Pre-compute balances and paid amounts in a single pass
        var balanceByMemberId: [UUID: Double] = [:]
        var paidByMemberId: [UUID: Double] = [:]

        // Initialize dictionaries for all members
        for member in otherMembers {
            if let memberId = member.id {
                balanceByMemberId[memberId] = 0
                paidByMemberId[memberId] = 0
            }
        }

        // Single pass through payments to compute balances and paid amounts
        for payment in paymentsSet {
            // Skip payment if payer is nil - cannot determine balance contribution
            guard let payer = payment.payer else {
                #if DEBUG
                print("[Subscription+Extensions] Warning: Skipping payment with nil payer in getMemberBalances()")
                #endif
                continue
            }

            let payerId = payer.id
            let amountPerMember = payment.amount / Double(subscriberCount)

            if CurrentUser.isCurrentUser(payerId) {
                // Current user paid - all other members owe their share
                for member in otherMembers {
                    if let memberId = member.id {
                        balanceByMemberId[memberId, default: 0] += amountPerMember
                    }
                }
            } else if let payerId = payerId, balanceByMemberId[payerId] != nil {
                // This member paid - track their payment and current user owes their share
                paidByMemberId[payerId, default: 0] += payment.amount
                balanceByMemberId[payerId, default: 0] -= amountPerMember
            }
        }

        // Single pass through settlements
        for settlement in settlementsSet {
            let fromPersonId = settlement.fromPerson?.id
            let toPersonId = settlement.toPerson?.id

            // Check settlements between current user and each member
            for member in otherMembers {
                guard let memberId = member.id else { continue }

                // Member paid current user
                if fromPersonId == memberId && CurrentUser.isCurrentUser(toPersonId) {
                    balanceByMemberId[memberId, default: 0] -= settlement.amount
                }
                // Current user paid member
                else if CurrentUser.isCurrentUser(fromPersonId) && toPersonId == memberId {
                    balanceByMemberId[memberId, default: 0] += settlement.amount
                }
            }
        }

        // Build result array from pre-computed dictionaries
        return otherMembers
            .compactMap { member -> (member: Person, balance: Double, paid: Double)? in
                guard let memberId = member.id else { return nil }
                let balance = balanceByMemberId[memberId] ?? 0
                let paid = paidByMemberId[memberId] ?? 0
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
        // Validate that this subscription is still valid in its context
        guard managedObjectContext != nil, !isDeleted, !isFault else {
            #if DEBUG
            print("[Subscription+Extensions] Warning: getConversationItems() called on invalidated subscription")
            #endif
            return []
        }

        var items: [SubscriptionConversationItem] = []

        // Add payments - filter out any invalidated objects
        if let paymentsSet = payments as? Set<SubscriptionPayment> {
            let validPayments = paymentsSet.filter { payment in
                payment.managedObjectContext != nil && !payment.isDeleted && !payment.isFault
            }
            items.append(contentsOf: validPayments.map { SubscriptionConversationItem.payment($0) })
        }

        // Add settlements - filter out any invalidated objects
        if let settlementsSet = settlements as? Set<SubscriptionSettlement> {
            let validSettlements = settlementsSet.filter { settlement in
                settlement.managedObjectContext != nil && !settlement.isDeleted && !settlement.isFault
            }
            items.append(contentsOf: validSettlements.map { SubscriptionConversationItem.settlement($0) })
        }

        // Add reminders - filter out any invalidated objects
        if let remindersSet = reminders as? Set<SubscriptionReminder> {
            let validReminders = remindersSet.filter { reminder in
                reminder.managedObjectContext != nil && !reminder.isDeleted && !reminder.isFault
            }
            items.append(contentsOf: validReminders.map { SubscriptionConversationItem.reminder($0) })
        }

        // Add chat messages - filter out any invalidated objects
        if let messagesSet = chatMessages as? Set<ChatMessage> {
            let validMessages = messagesSet.filter { message in
                message.managedObjectContext != nil && !message.isDeleted && !message.isFault
            }
            items.append(contentsOf: validMessages.map { SubscriptionConversationItem.message($0) })
        }

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

    // MARK: - Export Payment History

    /// Exports payment history as CSV formatted string.
    /// Includes date, amount, payer, split amount (for shared subscriptions), and notes.
    /// - Returns: CSV formatted string with header and payment rows
    func exportPaymentHistory() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        var csvLines: [String] = []

        // CSV Header
        csvLines.append("Date,Amount,Paid By,Split Amount,Notes")

        // Sort payments by date (newest first)
        let sortedPayments = recentPayments

        for payment in sortedPayments {
            // Date
            let dateString = payment.date.map { dateFormatter.string(from: $0) } ?? ""

            // Amount - format as plain number for CSV (no currency symbol)
            let amountString = String(format: "%.2f", payment.amount)

            // Paid By
            let payerName: String
            if CurrentUser.isCurrentUser(payment.payer?.id) {
                payerName = "You"
            } else {
                payerName = payment.payer?.displayName ?? "Unknown"
            }

            // Split Amount (for shared subscriptions)
            let splitAmountString: String
            if isShared && subscriberCount > 1 {
                let splitAmount = payment.amount / Double(subscriberCount)
                splitAmountString = String(format: "%.2f", splitAmount)
            } else {
                splitAmountString = ""
            }

            // Notes - escape any commas or quotes in notes
            let notes = payment.note ?? ""
            let escapedNotes = notes.contains(",") || notes.contains("\"")
                ? "\"\(notes.replacingOccurrences(of: "\"", with: "\"\""))\""
                : notes

            // Build CSV row
            let row = "\(dateString),\(amountString),\(payerName),\(splitAmountString),\(escapedNotes)"
            csvLines.append(row)
        }

        return csvLines.joined(separator: "\n")
    }

    /// Creates a temporary CSV file for payment history export.
    /// - Returns: URL to the temporary CSV file, or nil if creation fails
    func createPaymentHistoryCSVFile() -> URL? {
        let csvContent = exportPaymentHistory()

        // Create a safe filename from subscription name
        let safeName = (name ?? "Subscription")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")

        let fileName = "\(safeName)_Payment_History.csv"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to create CSV file: \(error.localizedDescription)")
            return nil
        }
    }
}
