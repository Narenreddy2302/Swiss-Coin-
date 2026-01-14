import CoreData
import SwiftUI

struct TransactionRowView: View {
    let transaction: FinancialTransaction

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
                Text(CurrencyFormatter.format(amountToShow))
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
        if let payerId = transaction.payer?.id {
            if CurrentUser.isCurrentUser(payerId) {
                return "You"
            }
            return transaction.payer?.name ?? "Unknown"
        }
        return "Unknown"
    }

    // MARK: - Amount Logic

    private var myShare: Double {
        // Find split for current user
        if let splits = transaction.splits?.allObjects as? [TransactionSplit] {
            if let mySplit = splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) }) {
                return mySplit.amount
            }
        }
        return 0.0
    }

    private var isPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
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

        let formattedTotal = CurrencyFormatter.format(total)

        if peopleCount == 0 {
            return formattedTotal
        } else if peopleCount == 1 {
            // Check who is the 1 person
            if let split = (transaction.splits?.allObjects as? [TransactionSplit])?.first,
               let owedBy = split.owedBy
            {
                let display = CurrentUser.isCurrentUser(owedBy.id) ? "You" : (owedBy.name ?? "Unknown")
                return "\(formattedTotal) / \(display)"
            }
            return "\(formattedTotal) / 1 Person"
        } else {
            return "\(formattedTotal) / \(peopleCount) People"
        }
    }
}
