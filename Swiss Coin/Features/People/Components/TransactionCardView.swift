//
//  TransactionCardView.swift
//  Swiss Coin
//

import SwiftUI

struct TransactionCardView: View {
    let transaction: FinancialTransaction
    let person: Person
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var isPressed = false

    private var isUserPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
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
            return transaction.payer?.firstName ?? "Someone"
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
            if let mySplit = splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) }) {
                return mySplit.amount
            }
        } else {
            // Third party paid (group expense) - show your share
            if let mySplit = splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) }) {
                return mySplit.amount
            }
        }
        return 0
    }

    private var amountText: String {
        let formatted = CurrencyFormatter.format(displayAmount)

        if isUserPayer && displayAmount > 0 {
            return "+\(formatted)"
        }
        return formatted
    }

    private var amountColor: Color {
        if displayAmount < 0.01 {
            // Zero or negligible - use neutral color
            return AppColors.textSecondary
        }
        if isUserPayer {
            // You paid and are owed money - positive (green)
            return AppColors.positive
        }
        // You owe money - negative (red)
        return AppColors.negative
    }

    private var splitCount: Int {
        let splits = transaction.splits as? Set<TransactionSplit> ?? []

        // Count unique participants (payer + those who owe)
        var participants = Set<UUID>()
        if let payerId = transaction.payer?.id {
            participants.insert(payerId)
        }
        for split in splits {
            if let personId = split.owedBy?.id {
                participants.insert(personId)
            }
        }

        // Ensure we return at least 1 if there are splits but no identifiable participants
        if participants.isEmpty && !splits.isEmpty {
            return splits.count
        }

        return max(participants.count, 1)
    }

    private var splitCountText: String {
        let count = splitCount
        return count == 1 ? "1 Person" : "\(count) People"
    }

    private var totalAmountText: String {
        CurrencyFormatter.format(transaction.amount)
    }

    private var dateText: String {
        return DateFormatter.mediumDate.string(from: transaction.date ?? Date())
    }

    private var metaText: String {
        if isUserPayer || isPersonPayer {
            return "\(dateText) | Paid by \(payerName)"
        } else {
            return "\(dateText) | Created by \(payerName)"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            // Left side - Title and Meta
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(transaction.title ?? "Untitled Transaction")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                Text(metaText)
                    .font(AppTypography.footnote())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Right side - Amount and Split Info
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(amountText)
                    .font(AppTypography.amount())
                    .foregroundColor(amountColor)

                Text("\(totalAmountText) / \(splitCountText)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(AppAnimation.quick, value: isPressed)
        .padding(.horizontal, Spacing.lg)
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.md))
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
                // Share action
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                HapticManager.tap()
                // View details action
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
                HapticManager.tap()
            }
        }, perform: {})
    }
}
