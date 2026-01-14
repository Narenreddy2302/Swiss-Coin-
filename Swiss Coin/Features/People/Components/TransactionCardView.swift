//
//  TransactionCardView.swift
//  Swiss Coin
//

import SwiftUI

struct TransactionCardView: View {
    let transaction: FinancialTransaction
    let person: Person

    private var isUserPayer: Bool {
        transaction.payer?.id == Person.currentUserUUID
    }

    private var isPersonPayer: Bool {
        transaction.payer?.id == person.id
    }

    private var payerName: String {
        if isUserPayer {
            return "You"
        } else if isPersonPayer {
            return person.firstName
        } else {
            return transaction.payer?.firstName ?? "Unknown"
        }
    }

    private var displayAmount: Double {
        let splits = transaction.splits as? Set<TransactionSplit> ?? []

        if isUserPayer {
            // User paid - show what they owe you (their share)
            if let theirSplit = splits.first(where: { $0.owedBy?.id == person.id }) {
                return theirSplit.amount
            }
        } else if isPersonPayer {
            // They paid - show what you owe (your share)
            if let mySplit = splits.first(where: { $0.owedBy?.id == Person.currentUserUUID }) {
                return mySplit.amount
            }
        } else {
            // Third party paid (group expense) - show your share
            if let mySplit = splits.first(where: { $0.owedBy?.id == Person.currentUserUUID }) {
                return mySplit.amount
            }
        }
        return 0
    }

    private var amountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let formatted = formatter.string(from: NSNumber(value: displayAmount)) ?? "$0.00"

        if isUserPayer {
            return "+\(formatted)"
        }
        return formatted
    }

    private var amountColor: Color {
        if isUserPayer {
            return .green
        }
        return .red
    }

    private var splitCount: Int {
        let splits = transaction.splits as? Set<TransactionSplit> ?? []
        // Count unique participants (payer + those who owe)
        var participants = Set<UUID>()
        if let payerId = transaction.payer?.id {
            participants.insert(payerId)
        }
        for split in splits {
            if let owedById = split.owedBy?.id {
                participants.insert(owedById)
            }
        }
        return max(participants.count, 1)
    }

    private var totalAmountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: transaction.amount)) ?? "$0.00"
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: transaction.date ?? Date())
    }

    private var metaText: String {
        if isUserPayer || isPersonPayer {
            return "\(dateText) | Paid by \(payerName)"
        } else {
            return "\(dateText) | Created by \(payerName)"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left side - Title and Meta
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title ?? "Unknown")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(metaText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Right side - Amount and Split Info
            VStack(alignment: .trailing, spacing: 4) {
                Text(amountText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(amountColor)

                Text("\(totalAmountText) / \(splitCount) People")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemGray6).opacity(0.3))
        )
        .padding(.horizontal, 16)
    }
}
