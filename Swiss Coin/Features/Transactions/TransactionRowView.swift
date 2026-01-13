import CoreData
import SwiftUI

struct TransactionRowView: View {
    let transaction: FinancialTransaction

    // Assuming "You" is the name for the current user for now, or logic will need to handle it.
    // In a real app, we'd have a UserSession or ID.
    private let currentUserName = "You"

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Main Content
            VStack(alignment: .leading, spacing: 6) {
                Text(transaction.title ?? "Unknown")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(dateString)
                    Text("|")
                    Text("Created by \(creatorName)")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            }

            Spacer()

            // Amount and Details
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(amountToShow))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(amountColor)

                Text(splitDetails)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var dateString: String {
        guard let date = transaction.date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: date)
    }

    private var creatorName: String {
        // "Created by" logic.
        // Assuming Payer is the creator for this context, or we just display Payer.
        // The image says "Created by You" etc.
        // We will use the Payer's name.
        if let name = transaction.payer?.name {
            return name == currentUserName ? "You" : name
        }
        return "Unknown"
    }

    // MARK: - Amount Logic

    private var myShare: Double {
        // Find split for "You"
        if let splits = transaction.splits?.allObjects as? [TransactionSplit] {
            // Try to find a person named "You" or assume current user.
            // If we can't find "You", maybe we are not involved?
            // For now, let's search for name "You"
            if let mySplit = splits.first(where: { $0.owedBy?.name == currentUserName }) {
                return mySplit.amount
            }
        }
        return 0.0
    }

    private var isPayer: Bool {
        return transaction.payer?.name == currentUserName
    }

    private var amountToShow: Double {
        if isPayer {
            let lent = transaction.amount - myShare
            // If I paid for others, show what I am owed (lent).
            // If I paid only for myself, show the expense.
            return lent > 0 ? lent : transaction.amount
        } else {
            // I owe my share
            return myShare
        }
    }

    private var amountColor: Color {
        if isPayer {
            let lent = transaction.amount - myShare
            if lent > 0 {
                return Color.green
            } else {
                return Color.red  // Personal Expense
            }
        } else {
            return Color.red  // I owe
        }
    }

    private var splitDetails: String {
        let total = transaction.amount
        let peopleCount = transaction.splits?.count ?? 0

        let formattedTotal = formatCurrency(total)

        if peopleCount == 0 {
            return formattedTotal
        } else if peopleCount == 1 {
            // Check who is the 1 person
            if let split = (transaction.splits?.allObjects as? [TransactionSplit])?.first,
                let name = split.owedBy?.name
            {
                let display = name == currentUserName ? "You" : name
                return "\(formattedTotal) / \(display)"
            }
            return "\(formattedTotal) / 1 Person"
        } else {
            return "\(formattedTotal) / \(peopleCount) People"
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}
