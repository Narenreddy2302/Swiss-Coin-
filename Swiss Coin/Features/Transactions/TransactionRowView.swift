import CoreData
import SwiftUI

struct TransactionRowView: View {
    let transaction: FinancialTransaction
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var isPressed = false

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            // Main Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(transaction.title ?? "Unknown")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: Spacing.xxs) {
                    Text(dateString)
                    Text("|")
                    Text("Created by \(creatorName)")
                }
                .font(AppTypography.footnote())
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Amount and Details
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(CurrencyFormatter.format(amountToShow))
                    .font(AppTypography.amount())
                    .foregroundColor(amountColor)

                Text(splitDetails)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.lg)
        .background(AppColors.backgroundSecondary)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(AppAnimation.quick, value: isPressed)
        .contentShape(Rectangle())
        .contextMenu {
            if onEdit != nil {
                Button {
                    HapticManager.tap()
                    onEdit?()
                } label: {
                    Label("Edit Transaction", systemImage: "pencil")
                }
            }

            Button {
                HapticManager.tap()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                HapticManager.tap()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }

            if onDelete != nil {
                Divider()

                Button(role: .destructive) {
                    HapticManager.delete()
                    onDelete?()
                } label: {
                    Label("Delete Transaction", systemImage: "trash")
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            withAnimation(AppAnimation.quick) {
                isPressed = pressing
            }
            if pressing {
                HapticManager.longPress()
            }
        }, perform: {})
    }

    // MARK: - Helpers

    private var dateString: String {
        guard let date = transaction.date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: date)
    }

    private var creatorName: String {
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
            return lent > 0 ? lent : transaction.amount
        } else {
            return myShare
        }
    }

    private var amountColor: Color {
        if isPayer {
            let lent = transaction.amount - myShare
            if lent > 0 {
                return AppColors.positive
            } else {
                return AppColors.negative
            }
        } else {
            return AppColors.negative
        }
    }

    private var splitDetails: String {
        let total = transaction.amount
        let peopleCount = transaction.splits?.count ?? 0

        let formattedTotal = CurrencyFormatter.format(total)

        if peopleCount == 0 {
            return formattedTotal
        } else if peopleCount == 1 {
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
